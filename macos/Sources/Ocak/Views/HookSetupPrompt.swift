import AppKit

/// Shows an NSAlert-style prompt asking the user to install Ocak's agent plugins.
/// Per D-05: shown the first time the command center opens after install.
enum HookSetupPrompt {

    /// Show the hook installation alert attached to the given window.
    /// Returns after the user acts (install success, install failure, or dismiss).
    @MainActor
    static func showIfNeeded(on window: NSWindow?) {
        let claudeNeeded = !HookInstaller.isInstalled()
        let openCodeNeeded = !HookInstaller.isOpenCodeHooksInstalled()
        guard claudeNeeded || openCodeNeeded else { return }
        guard !UserDefaults.standard.bool(forKey: HookInstaller.hooksIgnoredKey) else { return }
        guard let window else { return }

        let alert = NSAlert()
        alert.messageText = "Ocak needs to install its plugins"
        alert.informativeText = "Status detection requires agent plugins. Ocak will install them via the respective CLI tools."
        alert.alertStyle = .informational

        // Set icon to bolt.fill in accent blue
        if let boltImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Hook installation") {
            let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
            alert.icon = boltImage.withSymbolConfiguration(config)
        }

        alert.addButton(withTitle: "Install Plugins")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Ignore")

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                performInstall(on: window)
            } else if response == .alertThirdButtonReturn {
                UserDefaults.standard.set(true, forKey: HookInstaller.hooksIgnoredKey)
            }
            // "Not Now" dismisses without action; prompt reappears next time
        }
    }

    @MainActor
    private static func performInstall(on window: NSWindow) {
        Task {
            var errors: [String] = []
            if !HookInstaller.isInstalled() {
                do {
                    try await Task.detached(priority: .userInitiated) { try HookInstaller.install() }.value
                } catch HookInstaller.InstallError.pluginNotFound {
                    errors.append("Claude plugin bundle not found. Try reinstalling Ocak.")
                } catch HookInstaller.InstallError.commandFailed(let msg) {
                    errors.append("Claude plugin install failed: \(msg)")
                } catch {
                    errors.append("Claude plugin installation failed: \(error)")
                }
            }
            if !HookInstaller.isOpenCodeHooksInstalled() {
                do {
                    try await Task.detached(priority: .userInitiated) { try HookInstaller.installOpenCodeHooks() }.value
                } catch {
                    errors.append("OpenCode plugin installation failed: \(error)")
                }
            }
            if !errors.isEmpty {
                await MainActor.run {
                    showError(message: errors.joined(separator: "\n\n"), on: window)
                }
            }
        }
    }

    @MainActor
    private static func showError(message: String, on window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = "Ocak plugin installation failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Ignore")

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                performInstall(on: window)
            } else if response == .alertThirdButtonReturn {
                UserDefaults.standard.set(true, forKey: HookInstaller.hooksIgnoredKey)
            }
        }
    }
}
