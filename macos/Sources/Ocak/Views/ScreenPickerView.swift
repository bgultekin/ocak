import SwiftUI

/// Screen selection component for Settings.
/// Shows checkboxes for each available display.
struct ScreenPickerView: View {
    let screenConfig: ScreenConfigStore
    let availableScreens: [NSScreen]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(availableScreens, id: \.stableKey) { screen in
                let isChecked = screenConfig.isScreenActive(screen)
                let isLastSelected = isChecked && screenConfig.selectedScreenNames.count == 1
                Toggle(isOn: Binding(
                    get: { isChecked },
                    set: { _ in screenConfig.toggleScreen(screen) }
                )) {
                    screenLabel(screen)
                }
                .disabled(isLastSelected)
            }
        }
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
}
