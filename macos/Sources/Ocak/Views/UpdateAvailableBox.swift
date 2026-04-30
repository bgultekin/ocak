import AppKit
import SwiftUI

/// Inline box shown in the session list when a new version of Ocak is available.
struct UpdateAvailableBox: View {
    @Bindable var service: UpdateService

    var body: some View {
        if let update = service.availableUpdate {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(OcakTheme.statusBlue)

                    Text("Update available")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OcakTheme.labelPrimary)
                }

                Text("Ocak \(update.version) is available — you have \(update.currentVersion).")
                    .font(.system(size: 11))
                    .foregroundColor(OcakTheme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let notes = update.releaseNotes, !notes.isEmpty {
                    let attributed = (try? AttributedString(markdown: notes, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(notes)
                    Text(attributed)
                        .font(.system(size: 11))
                        .foregroundColor(OcakTheme.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(20)
                }

                HStack(spacing: 8) {
                    Button("Not Now") { service.snoozeUntilNextLaunch() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(OcakTheme.labelSecondary)

                    Button("Skip This Version") { service.skipCurrentVersion() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(OcakTheme.labelSecondary.opacity(0.6))

                    Spacer()

                    Button(action: { service.installUpdateNow() }) {
                        Text("Update")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(OcakTheme.statusBlue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)
            .background(OcakTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            EmptyView()
        }
    }
}
