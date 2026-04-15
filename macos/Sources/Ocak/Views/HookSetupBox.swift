import SwiftUI
import AppKit

/// Inline box shown in the session list when AI agent plugins are not installed.
struct HookSetupBox: View {
    @State private var isInstallingClaude = false
    @State private var isInstallingOpenCode = false
    @State private var claudeError: String?
    @State private var openCodeError: String?
    @State private var isDismissed = Self.dismissedForSession
    @State private var isIgnored = UserDefaults.standard.bool(forKey: HookInstaller.hooksIgnoredKey)

    private static var dismissedForSession = false

    private var needsClaude: Bool { !HookInstaller.isInstalled() }
    private var needsOpenCode: Bool { !HookInstaller.isOpenCodeHooksInstalled() }

    var body: some View {
        if isIgnored || isDismissed {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OcakTheme.statusBlue)

                    Text("Plugin not installed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OcakTheme.labelPrimary)
                }

                Text("Status detection requires agent plugins. Ocak will install them via the respective CLI tools.")
                    .font(.system(size: 11))
                    .foregroundColor(OcakTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if needsClaude {
                    pluginInstallRow(
                        name: "Claude Code",
                        isInstalling: $isInstallingClaude,
                        error: $claudeError,
                        install: installClaude
                    )
                }

                if needsOpenCode {
                    pluginInstallRow(
                        name: "OpenCode",
                        isInstalling: $isInstallingOpenCode,
                        error: $openCodeError,
                        install: installOpenCode
                    )
                }

                HStack(spacing: 8) {
                    Button("Not Now") {
                        Self.dismissedForSession = true
                        isDismissed = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(OcakTheme.labelSecondary)

                    Spacer()

                    Button("Ignore") {
                        UserDefaults.standard.set(true, forKey: HookInstaller.hooksIgnoredKey)
                        isIgnored = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(OcakTheme.labelSecondary.opacity(0.6))
                }
            }
            .padding(12)
            .background(OcakTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func pluginInstallRow(
        name: String,
        isInstalling: Binding<Bool>,
        error: Binding<String?>,
        install: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(OcakTheme.labelPrimary)
                Spacer()
                Button(action: install) {
                    if isInstalling.wrappedValue {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                        Text("Installing…")
                    } else {
                        Text("Install")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(OcakTheme.statusBlue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(isInstalling.wrappedValue)
            }

            if let errorMessage = error.wrappedValue {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @MainActor
    private func installClaude() {
        isInstallingClaude = true
        claudeError = nil

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try HookInstaller.install()
                }.value
                await MainActor.run {
                    isInstallingClaude = false
                }
            } catch HookInstaller.InstallError.pluginNotFound {
                await MainActor.run {
                    isInstallingClaude = false
                    claudeError = "Plugin bundle not found. Try reinstalling Ocak."
                }
            } catch HookInstaller.InstallError.commandFailed(let msg) {
                await MainActor.run {
                    isInstallingClaude = false
                    claudeError = "Install failed: \(msg)\n\nMake sure the claude CLI is on your PATH, then retry."
                }
            } catch {
                await MainActor.run {
                    isInstallingClaude = false
                    claudeError = "Installation failed: \(error)\n\nCheck Console.app for details, then retry."
                }
            }
        }
    }

    @MainActor
    private func installOpenCode() {
        isInstallingOpenCode = true
        openCodeError = nil

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try HookInstaller.installOpenCodeHooks()
                }.value
                await MainActor.run {
                    isInstallingOpenCode = false
                }
            } catch {
                await MainActor.run {
                    isInstallingOpenCode = false
                    openCodeError = "Installation failed: \(error)"
                }
            }
        }
    }
}
