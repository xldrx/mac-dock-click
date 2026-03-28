import Cocoa
import ApplicationServices

// MARK: - CGEventTap C-style callback (must be a free function, not a closure)

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<DockMonitor>.fromOpaque(refcon).takeUnretainedValue()
        .handle(type: type, event: event)
}

// MARK: - DockMonitor

class DockMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Returns true if the event tap was installed successfully.
    func start() -> Bool {
        // Trigger the system accessibility permission dialog if needed.
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        )
        guard trusted else { return false }
        installTap()
        return eventTap != nil
    }

    // MARK: - Private

    private func installTap() {
        guard eventTap == nil else { return }   // already installed

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let ptr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,           // can suppress events by returning nil
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: ptr
        ) else {
            print("[DockClick] CGEvent.tapCreate failed – check Accessibility permission.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[DockClick] Event tap installed.")
    }

    /// Called from the C callback. Returns nil to consume an event, otherwise passes it through.
    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS can disable the tap; re-enable it automatically.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .leftMouseDown,
              event.flags.contains(.maskCommand),
              let bundleID = dockApp(at: event.location)
        else {
            return Unmanaged.passUnretained(event)
        }

        if event.flags.contains(.maskShift) {
            print("[DockClick] Cmd+Shift+Click on \(bundleID) – reveal in Finder")
            revealInFinder(bundleID: bundleID)
        } else {
            print("[DockClick] Cmd+Click on \(bundleID) – open new window")
            openNewWindow(bundleID: bundleID)
        }
        return nil  // consume event
    }

    // MARK: - Dock detection

    /// Returns the bundle identifier of the app whose Dock icon is at the given screen point,
    /// or nil if the point is not over a Dock application icon.
    private func dockApp(at point: CGPoint) -> String? {
        var element: AXUIElement?
        let sys = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(sys, Float(point.x), Float(point.y), &element) == .success,
              let el = element else { return nil }

        // Verify the hit element belongs to the Dock process.
        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dock" else {
            return nil
        }

        return bundleID(forDockElement: el)
    }

    /// Walks the accessibility tree upward from `element` looking for an AXURL attribute
    /// that points to an .app bundle, then returns its CFBundleIdentifier.
    private func bundleID(forDockElement element: AXUIElement, depth: Int = 0) -> String? {
        guard depth < 8 else { return nil }

        var ref: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &ref) == .success, let ref {
            let url: URL?
            if      let u = ref as? URL    { url = u }
            else if let u = ref as? NSURL  { url = u as URL }
            else                           { url = nil }

            if let url, let id = appBundleID(at: url) { return id }
        }

        // Traverse up to the parent element.
        var parentRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
              let parentRef,
              CFGetTypeID(parentRef) == AXUIElementGetTypeID()
        else { return nil }

        // swiftlint:disable:next force_cast
        return bundleID(forDockElement: (parentRef as! AXUIElement), depth: depth + 1)
    }

    private func appBundleID(at url: URL) -> String? {
        if let id = Bundle(url: url)?.bundleIdentifier { return id }
        // Fallback: read CFBundleIdentifier directly from Info.plist.
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: plistURL)?["CFBundleIdentifier"] as? String
    }

    // MARK: - Actions

    private func revealInFinder(bundleID: String) {
        DispatchQueue.main.async {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // MARK: - Open new window

    private func openNewWindow(bundleID: String) {
        DispatchQueue.main.async {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                // App is already running: bring it to front, then send Cmd+N.
                app.activate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.sendCmdN()
                }
            } else {
                // App is not running: just launch it (it will open with a default window).
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                    return
                }
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }
    }

    /// Synthesises a Cmd+N keystroke to the frontmost application.
    private func sendCmdN() {
        let src = CGEventSource(stateID: .hidSystemState)
        let n: CGKeyCode = 45   // kVK_ANSI_N

        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: n, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: n, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
