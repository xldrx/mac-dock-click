# DockClick

A lightweight macOS menu bar utility that makes Dock icon clicks more powerful.

| Shortcut | Action |
|---|---|
| **⌘ + Click** on a Dock icon | Open a new window in that app |
| **⌘ ⇧ + Click** on a Dock icon | Reveal the app in Finder |

> macOS default behaviour for Cmd+Click (reveal in Finder) is replaced by the new-window action. Cmd+Shift+Click restores it.

---

## How it works

- Installs a `CGEventTap` to intercept mouse clicks globally
- Uses the macOS Accessibility API to identify which Dock icon was clicked
- If the app is **running**: activates it and sends `Cmd+N` to open a new window
- If the app is **not running**: launches it normally (opens with a default window)
- Runs silently in the menu bar with no Dock icon of its own

## Requirements

- macOS 12 Monterey or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Run

```bash
bash build.sh
open build/DockClick.app
```

On first launch, macOS will prompt for **Accessibility permission**.
Grant it in **System Settings → Privacy & Security → Accessibility**, then relaunch.

## Install

```bash
bash build.sh
cp -r build/DockClick.app /Applications/
open /Applications/DockClick.app
```

## Project structure

```
├── Sources/
│   ├── main.swift                  – Entry point
│   ├── AppDelegate.swift           – Menu bar setup & lifecycle
│   ├── DockMonitor.swift           – CGEventTap, Dock detection, window opening
│   └── AboutWindowController.swift – About window
├── Resources/
│   └── Info.plist
├── generate_icon.swift             – Draws the app icon with Core Graphics
└── build.sh                        – Compiles, packages, and signs the .app
```

## Author

**Sayed Hadi Hashemi**
