# DockClick

A lightweight macOS menu bar utility that makes Dock icon clicks more powerful.

| Shortcut | Action |
|---|---|
| **⌘ + Click** on a Dock icon | Open a new window (`Cmd+N`) |
| **⌘ ⇧ + Click** on a Dock icon | Open a new window (`Cmd+Shift+N`) |
| **⌥ ⌘ + Click** on a Dock icon | Reveal the app in Finder |

---

## Install via Homebrew

```bash
brew tap xldrx/tap
brew install --cask dockclick
```

On first launch, macOS will prompt for **Accessibility permission**.
Grant it in **System Settings → Privacy & Security → Accessibility**, then relaunch.

## Manual install

Download the latest `DockClick.zip` from [Releases](https://github.com/xldrx/mac-dock-click/releases), unzip, and move `DockClick.app` to `/Applications`.

## How it works

- Installs a `CGEventTap` to intercept mouse clicks globally
- Uses the macOS Accessibility API to identify which Dock icon was clicked
- Sends keystrokes directly to the target process via `CGEvent.postToPid` — no Space switching required
- Runs silently in the menu bar with no Dock icon of its own
- Registers itself as a Login Item on first launch (toggle via menu bar)

## Requirements

- macOS 12 Monterey or later

## Build from source

```bash
xcode-select --install   # if not already installed
bash build.sh
open build/DockClick.app
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
└── build.sh                        – Compiles, signs, and notarizes the .app
```

