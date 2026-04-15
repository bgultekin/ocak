# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What is Ocak?

Ocak is a macOS menu bar app (accessory app) that provides a slide-out drawer panel for managing multiple AI coding sessions (Claude Code, OpenCode, custom). It embeds real terminal views (via SwiftTerm) and tracks session status through Claude Code hooks.

## Build & Run

```bash
cd macos
swift build                    # Build the project
swift test                     # Run all tests
swift test --filter OcakTests.HookInstallerTests  # Run a single test file
swift run                      # Build and run the app
```

From the repository root you can instead pass `--package-path macos` to each command (for example `swift build --package-path macos`).

Requires macOS 14+ and Swift 5.9+. Dependencies (SwiftTerm, KeyboardShortcuts) resolve via SPM automatically.

## Repository layout

- **`macos/`** — Swift package root: `Package.swift`, sources, tests, and bundled app resources.
- **`windows/`** — Reserved for a future native Windows client (placeholder).
- **`assets/`** — Shared design inputs: `fonts/`, `images/` (source raster/vector artwork before platform packaging), `locales/` (strings for future i18n).
- **`scripts/`** — Build and maintenance shell scripts.
- **`docs/`** — Architecture notes and setup guides.

## Architecture

### App Lifecycle
- **No visible main window.** `OcakApp` uses `NSApplicationDelegateAdaptor` with `.accessory` activation policy. All UI is managed by `AppDelegate` through custom `NSPanel` subclasses.
- **AppDelegate** orchestrates everything: ribbon panel, drawer panel, edge detection (hover-to-reveal), status bar menu, keyboard shortcut (Cmd+Option+O), hook server, and process watcher.

### Panel System (macos/Sources/Ocak/Panels/)
- **FloatingPanel** — always-visible, non-activating overlay used for the edge ribbon.
- **DrawerPanel** — slide-in/out panel anchored to the right screen edge. Uses CALayer mask animations (not frame-based) to avoid bleeding onto adjacent displays. Dismisses on click-outside.

### Session Model (macos/Sources/Ocak/Models/)
- **SessionGroup** — named folder of sessions with a shared working directory.
- **ThreadSession** — individual terminal session with status tracking. `isClaudeRunning` is runtime-only (excluded from CodingKeys).
- **SessionStore** — `@Observable` central store. Persists sessions/groups to UserDefaults. Handles legacy migration from pre-group format. Processes hook events to update session status.
- **PanelSizeStore** — per-screen panel width persistence (collapsed vs expanded).

### Terminal (macos/Sources/Ocak/Terminal/)
- **TerminalManager** — singleton that owns all `OcakTerminalView` instances keyed by session UUID. Terminals persist across session switches. Injects shell hooks for CWD tracking (OSC 7) and kitty keyboard reset on precmd.
- **TerminalBridge** — bridges SwiftTerm's `NSView` into SwiftUI via `NSViewRepresentable`.

### Hook System (macos/Sources/Ocak/Hooks/)
- **HookServer** — TCP server on port 27832 that receives HTTP POST from Claude Code hooks. Parses JSON body into `HookEvent` and dispatches to `SessionStore`.
- **HookEvent** — decoded hook payload. The `ocakSessionId` field is injected by the hook command from the `$OCAK_SESSION_ID` env var set by TerminalManager.
- **HookInstaller** — installs/uninstalls Ocak's hooks into `~/.claude/settings.json` via read-backup-merge-write. Idempotent — checks for existing OCAK_SESSION_ID markers.
- **Plugin marketplace** — hooks are bundled as a Claude Code plugin in `Resources/claude-ocak-marketplace/`. `PluginStatusChecker` (in Helpers/) detects install status by reading `~/.claude/plugins/installed_plugins.json`, with fallback to legacy settings.json check.

### Services (macos/Sources/Ocak/Services/)
- **ProcessWatcher** — polls process table every 2s via sysctl to detect if claude is running as a child of each session's shell PID. Updates `isClaudeRunning` on sessions.
- **ProcessDetector** — low-level sysctl wrapper for batch process detection.
- **GitInfoReader** — reads git branch and worktree status from a working directory for display in the UI.

### Status Flow
Session status updates come from two sources:
1. **Hook events** (Claude Code → HookServer → SessionStore): maps hook event names to `SessionStatus` (.working, .needs_input, .done).
2. **ProcessWatcher** (polling): sets `isClaudeRunning` flag for shell/claude label display.

### Visual Effects (macos/Sources/Ocak/Metal/)
- **MetalSmokeRibbonView / SmokeRibbonRenderer** — Metal-powered animated smoke effect for the edge ribbon. Falls back to SwiftUI `SmokeRibbonView` when Metal is unavailable.

### Configuration Stores
- **ScreenConfigStore** — per-screen settings (e.g., which screen the drawer appears on).
- **RibbonConfigStore** — ribbon appearance/behavior settings.

### Key Conventions
- SwiftUI views are in `Views/`, AppKit panels in `Panels/`.
- The `@Observable` macro is used for stores (not ObservableObject/Combine).
- Colors are centralized in `Theme/Colors.swift`.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest.
- Tests **cannot import the executable target** directly. Types needed for testing are duplicated locally in test files.

## Approach
- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Test your code before declaring done.
- Before committing, always run `swift build` (or `swift package plugin swiftlint`) and resolve any SwiftLint warnings/errors introduced by your changes. Do not commit code with new lint violations.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.
