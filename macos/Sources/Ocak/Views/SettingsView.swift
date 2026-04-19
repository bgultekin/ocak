import KeyboardShortcuts
import SwiftUI

/// Displays plugin management and session configuration.
/// Uses a native macOS sidebar + content panel layout with left tabs.
struct SettingsView: View {
    @Bindable var model: SettingsViewModel

    @State private var selectedTab: SettingsTab = .general
    @State private var ribbonStyle: RibbonStyle = RibbonConfigStore.shared.ribbonStyle
    @State private var appearanceMode: AppearanceMode = AppearanceConfigStore.shared.mode
    @State private var terminalThemeMode: TerminalThemeMode = TerminalThemeConfigStore.shared.mode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 600, idealWidth: 600, minHeight: 300)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.name, systemImage: tab.symbol)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .frame(width: 150)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .appearance:
            appearanceTab
        case .plugin:
            pluginTab
        case .about:
            aboutTab
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Show panel shortcut")
                Spacer()
                KeyboardShortcuts.Recorder(for: .togglePanel)
            }

            Divider()

            HStack {
                Text("Launch at login")
                Spacer()
                Picker("", selection: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                )) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 100)
            }

            if let error = model.launchAtLoginError {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Divider()

            HStack {
                Text("Automatic updates")
                Spacer()
                Picker("", selection: Binding(
                    get: { UpdateService.shared.isAutoUpdateEnabled },
                    set: { UpdateService.shared.isAutoUpdateEnabled = $0 }
                )) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 100)
            }

            HStack {
                Button("Check for updates…") { UpdateService.shared.checkNow() }
                Spacer()
                let description = UpdateService.shared.lastCheckDescription
                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Displays")
                    .font(.headline)
                ForEach(model.availableScreens, id: \.localizedName) { screen in
                    let isChecked = model.screenConfig.isScreenActive(screen)
                    let isLastSelected = isChecked && model.screenConfig.selectedScreenNames.count == 1
                    HStack(spacing: 8) {
                        Image(systemName: "display")
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Toggle(isOn: Binding(
                            get: { isChecked },
                            set: { _ in model.screenConfig.toggleScreen(screen) }
                        )) {
                            screenLabel(screen)
                        }
                        .disabled(isLastSelected)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.screenConfig.panelEdge(for: screen) },
                            set: { model.screenConfig.setPanelEdge($0, for: screen) }
                        )) {
                            Text("Left").tag(PanelEdge.left)
                            Text("Right").tag(PanelEdge.right)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                        .disabled(!isChecked)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func screenLabel(_ screen: NSScreen) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(screen.localizedName)
                .font(.body)
            Text(String(format: "%.0f × %.0f", screen.frame.width, screen.frame.height))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Appearance Tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Theme")
                    Spacer()
                    Picker("", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                }

                Text(themeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Terminal Theme")
                    Spacer()
                    Picker("", selection: $terminalThemeMode) {
                        ForEach(TerminalThemeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }

                Text(terminalThemeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack {
                Text("Ribbon Style")
                Spacer()
                Picker("", selection: $ribbonStyle) {
                    ForEach(RibbonStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            Text(ribbonStyleDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
        .onChange(of: ribbonStyle) { _, newStyle in
            RibbonConfigStore.shared.setStyle(newStyle)
        }
        .onChange(of: appearanceMode) { _, newMode in
            AppearanceConfigStore.shared.setMode(newMode)
        }
        .onChange(of: terminalThemeMode) { _, newMode in
            TerminalThemeConfigStore.shared.setMode(newMode)
        }
    }

    private var themeDescription: String {
        switch appearanceMode {
        case .dark:
            return "Always use the dark theme."
        case .light:
            return "Always use the light theme."
        case .auto:
            return "Use the theme that matches your system settings."
        }
    }

    private var terminalThemeDescription: String {
        switch terminalThemeMode {
        case .dark:
            return "Always use a dark background for terminal windows."
        case .light:
            return "Always use a light background for terminal windows."
        case .system:
            return "Terminal background follows your system appearance."
        }
    }

    private var ribbonStyleDescription: String {
        switch ribbonStyle {
        case .solid:
            return "A solid colored bar that matches your system accent color."
        case .smoke:
            return "A smoke effect with subtle animation."
        case .invisible:
            return "A transparent bar with minimal visual presence."
        case .none:
            let shortcut = KeyboardShortcuts.getShortcut(for: .togglePanel)?.description ?? "your configured shortcut"
            return "The ribbon is hidden. Use \(shortcut) to reveal the drawer."
        }
    }

    // MARK: - Plugin Tab

    private var pluginTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            pluginSection(
                title: "Claude Code",
                isInstalled: model.isClaudeInstalled,
                installAction: { model.installClaude() },
                uninstallAction: { model.uninstallClaude() }
            )

            Divider()

            pluginSection(
                title: "OpenCode",
                isInstalled: model.isOpenCodeInstalled,
                installAction: { model.installOpenCode() },
                uninstallAction: { model.uninstallOpenCode() }
            )

            if let warning = model.inlineWarning {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = model.inlineError {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func pluginSection(
        title: String,
        isInstalled: Bool,
        installAction: @escaping () -> Void,
        uninstallAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isInstalled ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(isInstalled ? "\(title) — Installed" : "\(title) — Not Installed")
                    .foregroundColor(isInstalled ? .primary : .secondary)
                Spacer()
                if isInstalled {
                    Button("Uninstall", role: .destructive) {
                        uninstallAction()
                    }
                } else {
                    Button("Install Plugin") {
                        installAction()
                    }
                }
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Icon + identity
                VStack(spacing: 8) {
                    Image(nsImage: {
                        let name = colorScheme == .dark ? "ocak-app-icon-dark" : "ocak-app-icon-light"
                        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
                           let img = NSImage(contentsOf: url) { return img }
                        return NSApp.applicationIconImage
                    }())
                    .resizable()
                    .frame(width: 80, height: 80)

                    Text("Ocak")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("A slide-out terminal drawer with AI coding session tracking")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text(versionString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Link("View on GitHub", destination: URL(string: "https://github.com/bgultekin/ocak")!)
                        .font(.caption)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()
                    .padding(.horizontal, 20)

                // System info
                VStack(alignment: .leading, spacing: 8) {
                    Text("System")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    infoRow("macOS", value: macOSVersion)
                    infoRow("Architecture", value: cpuArchitecture)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Acknowledgements
                VStack(alignment: .leading, spacing: 8) {
                    Text("Acknowledgements")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    infoRow("SwiftTerm", value: "Miguel de Icaza")
                    infoRow("KeyboardShortcuts", value: "Sindre Sorhus")
                    infoRow("Sparkle", value: "Sparkle Project")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.callout)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        return "Version \(version)"
    }

    private var macOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var cpuArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel"
        #else
        return "Unknown"
        #endif
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case plugin
    case about

    var id: String { rawValue }

    var name: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .plugin: return "Plugin"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .plugin: return "puzzlepiece.extension"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Shortcut Recorder View

/// A custom keyboard shortcut recorder that mimics the native macOS recording style.
struct ShortcutRecorderView: View {
    @State private var shortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .togglePanel)
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 4) {
            if isRecording {
                Text("Press shortcut…")
                    .foregroundColor(.secondary)
            } else if let shortcut {
                ShortcutKeyView(shortcut: shortcut)
            } else {
                Text("Not Set")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isRecording ? 2 : 1)
        )
        .onTapGesture {
            isRecording.toggle()
        }
        .overlay(
            KeyboardShortcuts.Recorder(for: .togglePanel)
                .opacity(0)
                .allowsHitTesting(isRecording)
        )
        .onChange(of: KeyboardShortcuts.getShortcut(for: .togglePanel)) { _, newValue in
            shortcut = newValue
            isRecording = false
        }
        .frame(minWidth: 120)
    }
}

/// Displays a single keyboard shortcut with proper modifier glyphs.
struct ShortcutKeyView: View {
    let shortcut: KeyboardShortcuts.Shortcut

    var body: some View {
        HStack(spacing: 2) {
            if shortcut.modifiers.contains(.command) {
                Text("⌘")
            }
            if shortcut.modifiers.contains(.option) {
                Text("⌥")
            }
            if shortcut.modifiers.contains(.shift) {
                Text("⇧")
            }
            if shortcut.modifiers.contains(.control) {
                Text("⌃")
            }
            if let key = shortcut.key {
                Text(key.displayName)
            }
        }
        .font(.body.monospaced())
        .foregroundColor(.primary)
    }
}

extension KeyboardShortcuts.Key {
    var displayName: String {
        let specialKeys: [KeyboardShortcuts.Key: String] = [
            .return: "↩",
            .delete: "⌫",
            .deleteForward: "⌦",
            .end: "↘",
            .escape: "⎋",
            .help: "?",
            .home: "↖",
            .space: "Space",
            .tab: "⇥",
            .pageUp: "⇞",
            .pageDown: "⇟",
            .upArrow: "↑",
            .rightArrow: "→",
            .downArrow: "↓",
            .leftArrow: "←",
            .f1: "F1", .f2: "F2", .f3: "F3", .f4: "F4",
            .f5: "F5", .f6: "F6", .f7: "F7", .f8: "F8",
            .f9: "F9", .f10: "F10", .f11: "F11", .f12: "F12",
            .f13: "F13", .f14: "F14", .f15: "F15", .f16: "F16",
            .f17: "F17", .f18: "F18", .f19: "F19", .f20: "F20",
        ]
        if let name = specialKeys[self] {
            return name
        }
        return String(self.rawValue).uppercased()
    }
}
