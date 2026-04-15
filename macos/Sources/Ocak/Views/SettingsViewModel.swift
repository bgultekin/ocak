import Foundation
import AppKit
import ServiceManagement

@Observable
final class SettingsViewModel {
    var isClaudeInstalled: Bool
    var isOpenCodeInstalled: Bool
    var inlineError: String?
    var inlineWarning: String?
    var launchAtLoginError: String?

    let screenConfig = ScreenConfigStore.shared

    var availableScreens: [NSScreen] { NSScreen.screens }

    var launchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    init() {
        isClaudeInstalled = PluginStatusChecker.isInstalled()
        isOpenCodeInstalled = HookInstaller.isOpenCodeHooksInstalled()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
        }
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func installClaude() {
        inlineError = nil
        inlineWarning = isProcessRunning("claude") ? "Claude is running — hooks take effect on next launch" : nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try HookInstaller.install() }.value
                isClaudeInstalled = PluginStatusChecker.isInstalled()
            } catch {
                inlineError = errorMessage(for: error)
            }
        }
    }

    func uninstallClaude() {
        inlineError = nil
        inlineWarning = isProcessRunning("claude") ? "Claude is running — hooks take effect on next launch" : nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try HookInstaller.uninstall() }.value
                isClaudeInstalled = PluginStatusChecker.isInstalled()
            } catch {
                inlineError = errorMessage(for: error)
            }
        }
    }

    func installOpenCode() {
        inlineError = nil
        inlineWarning = isProcessRunning("opencode") ? "OpenCode is running — hooks take effect on next launch" : nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try HookInstaller.installOpenCodeHooks() }.value
                isOpenCodeInstalled = HookInstaller.isOpenCodeHooksInstalled()
            } catch {
                inlineError = "OpenCode plugin install failed: \(error.localizedDescription)"
            }
        }
    }

    func uninstallOpenCode() {
        inlineError = nil
        inlineWarning = isProcessRunning("opencode") ? "OpenCode is running — hooks take effect on next launch" : nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try HookInstaller.uninstallOpenCodeHooks() }.value
                isOpenCodeInstalled = HookInstaller.isOpenCodeHooksInstalled()
            } catch {
                inlineError = "OpenCode plugin uninstall failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Private helpers

private extension SettingsViewModel {
    func isProcessRunning(_ name: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["-x", name]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    func errorMessage(for error: Error) -> String {
        switch error as? HookInstaller.InstallError {
        case .pluginNotFound:
            return "Plugin bundle not found — try reinstalling Ocak"
        case .commandFailed(let msg):
            return "Plugin command failed: \(msg)"
        default:
            return "Unexpected error: \(error.localizedDescription)"
        }
    }

}
