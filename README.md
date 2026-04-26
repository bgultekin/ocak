<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/images/ocak-icon-dark@2x.png">
  <img src="assets/images/ocak-icon-light@2x.png" alt="Ocak" width="140">
</picture>

# Ocak

<sub><i>/oˈdʒak/ — Turkish for "Hearth", "Stove", or "Fireplace"</i></sub>

**A slide-out terminal drawer for managing AI coding terminals on macOS.**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-early-yellow)


</div>

---

Ocak lives in your menu bar and hides a terminal drawer just off the right edge of your screen. Pull it out with a keystroke or a nudge of the mouse, run Claude Code, OpenCode, or whatever shell you want, and let Ocak track what each terminal is doing in the background.



<img width="960" height="621" alt="gif" src="https://github.com/user-attachments/assets/6a740295-0693-4bfd-a111-c68092bc0343" />

---

## Quick Start

Grab the latest build from the [releases page](https://github.com/bgultekin/ocak/releases/latest):

1. Download `Ocak.dmg` from the latest release.
2. Open it and drag `Ocak.app` into `/Applications`.
3. Launch it. Ocak runs as a menu bar accessory — look for the icon in the top-right of your screen.

Releases are not signed. You may need to visit `Settings` > `Privacy & Security` and click `Open Anyway`. 

Prefer to build it yourself? See [Build from source](#build-from-source) below.

### Requirements

- macOS 14 (Sonoma) or newer
- Swift 5.9+ toolchain (Xcode 15 or the command-line tools)

---

## Demo Video

https://github.com/user-attachments/assets/da23a5cf-93c2-4eb4-8a13-8495b46a1f4e

## Features

### 🖥️ Terminal experience

| | |
|---|---|
| **Real terminals** | Full emulation — colors, mouse, `vim`, `htop`, fancy keybindings. Not a chat box. |
| **Live AI status** | Sidebar shows when each terminal is working, waiting for input, or done — at a glance. |
| **Git at a glance** | Current branch and directory cleanliness shown inline on every terminal row. |

### 🎛️ Interface

| | |
|---|---|
| **Slide-out drawer** | Tucks off the right screen edge. Glides in on demand, disappears on click-outside. No dock icon, no main window. |
| **Edge reveal** | Hover the screen edge to open. Style options: **solid** bar, animated **smoke**, **invisible** zone, or **none** (shortcut only). |
| **Custom shortcut** | Default `Cmd+Control+O`. Bind it to whatever fits your muscle memory. |

### 🗂️ Organization

| | |
|---|---|
| **Terminal groups** | Named folders tied to a project directory. Each holds multiple terminals; state persists as you switch. |
| **Per-group setup** | Custom name, working directory, and auto-run command per group — kick off `claude` or a dev server automatically. |
| **Open in VS Code** | Optional per-group button to open the group's folder in VS Code with one click. Enable it in group settings. |
| **Multi-screen** | Choose which display the drawer opens on. Width preference is remembered per screen. |

### ⚙️ Configuration

| | |
|---|---|
| **Theming** | Separate controls for app and terminal colors. Light and dark palettes, app icon follows system mode. |
| **One-click setup** | Enable AI status tracking from the settings pane with a single click. No config files to edit. |
| **Auto start** | Toggle launch-at-login in settings. Ocak is ready in the menu bar before you need it. |
| **Auto update** | Ocak checks for new releases on launch and updates itself in the background. Always on the latest version without manual downloads. |

## Build from source

```bash
git clone https://github.com/bgultekin/ocak.git
cd ocak/macos
swift build -c release
swift run -c release
```

Dependencies resolve automatically through Swift Package Manager.

## Run tests

```bash
swift test
swift test --filter OcakTests.HookInstallerTests
```

Tests are written against [Swift Testing](https://developer.apple.com/xcode/swift-testing/), not XCTest.

## Architecture at a glance

```
AppDelegate ── orchestrates panels, shortcut, hook server
    │
    ├── FloatingPanel     edge ribbon, always visible
    ├── DrawerPanel       slide-in, anchored to screen edge
    │       └── DrawerView
    │               ├── SessionListView
    │               └── TerminalPaneView (SwiftTerm)
    │
    ├── HookServer        TCP 27832, receives Claude Code events
    ├── ProcessWatcher    2s sysctl poll for running claude
    └── SessionStore      @Observable, persists to UserDefaults
```

For a full breakdown of modules, stores, and conventions, see [`AGENTS.md`](AGENTS.md).

## Roadmap

- Windows client (will be living under `windows/`)
- Linux support under consideration
- Support for other coding agents beyond Claude Code and OpenCode

## Acknowledgements

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza — the terminal emulator that makes the drawer useful.
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus — global shortcut handling.

## License

Ocak is released under the [MIT License](LICENSE).
