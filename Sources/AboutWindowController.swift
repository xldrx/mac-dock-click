import Cocoa

class AboutWindowController: NSWindowController {

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "About DockClick"
        win.isReleasedWhenClosed = false
        win.center()
        self.init(window: win)
        win.contentView = makeContentView()
    }

    private func makeContentView() -> NSView {
        let root = NSView()

        // ── App icon ────────────────────────────────────────────────────
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true

        // ── Labels ──────────────────────────────────────────────────────
        let nameLabel = label("DockClick", size: 20, weight: .bold)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = label("Version \(version)", size: 13, weight: .regular, secondary: true)

        let devLabel = label("Sayed Hadi Hashemi", size: 13, weight: .medium)

        let year = Calendar.current.component(.year, from: Date())
        let copyrightLabel = label("© \(year) Sayed Hadi Hashemi", size: 11, weight: .regular, tertiary: true)

        // ── Divider ─────────────────────────────────────────────────────
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        // ── Stack ───────────────────────────────────────────────────────
        let topStack = NSStackView(views: [iconView, nameLabel, versionLabel])
        topStack.orientation = .vertical
        topStack.spacing = 6
        topStack.alignment = .centerX

        let bottomStack = NSStackView(views: [devLabel, copyrightLabel])
        bottomStack.orientation = .vertical
        bottomStack.spacing = 4
        bottomStack.alignment = .centerX

        let outer = NSStackView(views: [topStack, divider, bottomStack])
        outer.orientation = .vertical
        outer.spacing = 16
        outer.alignment = .centerX
        outer.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(outer)
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalTo: outer.widthAnchor),
            outer.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            outer.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            outer.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.80)
        ])

        return root
    }

    // MARK: – Helpers

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight,
                       secondary: Bool = false, tertiary: Bool = false) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.systemFont(ofSize: size, weight: weight)
        f.alignment = .center
        if tertiary      { f.textColor = .tertiaryLabelColor }
        else if secondary { f.textColor = .secondaryLabelColor }
        return f
    }
}
