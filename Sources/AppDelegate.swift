import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let monitor = DockMonitor()
    private var aboutWindowController: AboutWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        if monitor.start() {
            print("[DockClick] Running – Cmd+Click a Dock icon to open a new window.")
        } else {
            updateMenuForMissingPermissions()
        }
    }

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
            let info1 = NSMenuItem(title: "⌘+Click   → open new window", action: nil, keyEquivalent: "")
            info1.isEnabled = false
            let info2 = NSMenuItem(title: "⌘⇧+Click → reveal in Finder", action: nil, keyEquivalent: "")
            info2.isEnabled = false
            menu.addItem(info1)
            menu.addItem(info2)
        } else {
            let warn = NSMenuItem(title: "⚠️  Accessibility permission required", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            menu.addItem(NSMenuItem(title: "Open Privacy Settings…", action: #selector(openPrivacySettings), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Retry after granting permission", action: #selector(retry), keyEquivalent: "r"))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About DockClick", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit DockClick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func updateMenuForMissingPermissions() {
        buildMenu(permissionGranted: false)
        statusItem?.button?.toolTip = "Accessibility permission needed"
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
