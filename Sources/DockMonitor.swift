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
    private(set) var isRunning = false

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
        isRunning = true
        print("[DockClick] Event tap installed.")
    }

    /// Called from the C callback. Returns nil to consume an event, otherwise passes it through.
    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS can disable the tap; re-enable it automatically.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .leftMouseDown else { return Unmanaged.passUnretained(event) }

        let flags  = event.flags
        let isCmd  = flags.contains(.maskCommand)
        let isAlt  = flags.contains(.maskAlternate)
        let isShift = flags.contains(.maskShift)

        guard (isCmd || isAlt),
              let bundleID = dockApp(at: event.location)
        else {
            return Unmanaged.passUnretained(event)
        }

        if isAlt && isCmd && !isShift {
            print("[DockClick] Alt+Cmd+Click on \(bundleID) – reveal in Finder")
            revealInFinder(bundleID: bundleID)
        } else if isCmd && isShift {
            print("[DockClick] Cmd+Shift+Click on \(bundleID) – open new window (Cmd+Shift+N)")
            openNewWindow(bundleID: bundleID, withShift: true)
        } else if isCmd {
            print("[DockClick] Cmd+Click on \(bundleID) – open new window (Cmd+N)")
            openNewWindow(bundleID: bundleID)
        } else {
            return Unmanaged.passUnretained(event)
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

    private func openNewWindow(bundleID: String, withShift: Bool = false) {
        DispatchQueue.main.async {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }

            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                self.sendKeystroke(n: 45, cmd: true, shift: withShift, toPid: app.processIdentifier)

                let cfg = NSWorkspace.OpenConfiguration()
                cfg.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in }
            } else {
                NSWorkspace.shared.openApplication(at: url,
                                                   configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }

    private func sendKeystroke(n keyCode: CGKeyCode, cmd: Bool, shift: Bool, toPid pid: pid_t) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        var flags = CGEventFlags()
        if cmd   { flags.insert(.maskCommand) }
        if shift { flags.insert(.maskShift) }
        keyDown.flags = flags
        keyUp.flags   = flags
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
    }
}
