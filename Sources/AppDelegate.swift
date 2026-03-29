import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let monitor = DockMonitor()
    private var aboutWindowController: AboutWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerLaunchAtLoginIfNeeded()

        if monitor.start() {
            print("[DockClick] Running – Cmd+Click a Dock icon to open a new window.")
        } else {
            updateMenuForMissingPermissions()
        }
    }

    /// Registers the app as a login item on the very first launch.
    private func registerLaunchAtLoginIfNeeded() {
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        guard service.status == .notRegistered else { return }
        do {
            try service.register()
            print("[DockClick] Registered as login item.")
        } catch {
            print("[DockClick] Could not register login item: \(error)")
        }
    }

    // MARK: - Menu

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockClick") {
            button.image = image
        } else {
            button.title = "⌘"
        }

        buildMenu(permissionGranted: true)
    }

    private func buildMenu(permissionGranted: Bool) {
        let menu = NSMenu()

        if permissionGranted {
            let info1 = NSMenuItem(title: "⌘+Click    → new window (⌘N)", action: nil, keyEquivalent: "")
            info1.isEnabled = false
            let info2 = NSMenuItem(title: "⌘⇧+Click → new window (⌘⇧N)", action: nil, keyEquivalent: "")
            info2.isEnabled = false
            let info3 = NSMenuItem(title: "⌥+Click    → reveal in Finder", action: nil, keyEquivalent: "")
            info3.isEnabled = false
            menu.addItem(info1)
            menu.addItem(info2)
            menu.addItem(info3)
        } else {
            let warn = NSMenuItem(title: "⚠️  Accessibility permission required", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            menu.addItem(NSMenuItem(title: "Open Privacy Settings…", action: #selector(openPrivacySettings), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Retry after granting permission", action: #selector(retry), keyEquivalent: "r"))
        }

        menu.addItem(.separator())

        // Launch at Login (requires macOS 13+)
        if #available(macOS 13.0, *) {
            let loginItem = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin),
                                       keyEquivalent: "")
            loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(loginItem)
            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(title: "About DockClick", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit DockClick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func updateMenuForMissingPermissions() {
        buildMenu(permissionGranted: false)
        statusItem?.button?.toolTip = "Accessibility permission needed"
    }

    // MARK: - Actions

    @available(macOS 13.0, *)
    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("[DockClick] Launch at Login toggle failed: \(error)")
        }
        buildMenu(permissionGranted: monitor.isRunning)
    }

    @objc private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func retry() {
        if monitor.start() {
            buildMenu(permissionGranted: true)
            statusItem?.button?.toolTip = nil
        }
    }
}
