import SwiftUI

/// The terminal pane shown in the drawer when a session is selected.
struct TerminalPaneView: View {
    let session: ThreadSession?
    let groupName: String?
    let initialCommand: String?
    var onStatusChange: ((UUID, SessionStatus) -> Void)?
    var onDirectoryChange: ((UUID, String) -> Void)?
    var onClose: (() -> Void)?

    var body: some View {
        if let session {
            VStack(spacing: 0) {
                terminalHeader(for: session)
                Rectangle()
                    .fill(OcakTheme.terminalDivider)
                    .frame(height: 1)
                TerminalSwiftUIView(
                    sessionID: session.id,
                    workingDirectory: session.workingDirectory,
                    aiTool: session.aiTool,
                    initialCommand: initialCommand,
                    onStatusChange: { status in
                        onStatusChange?(session.id, status)
                    },
                    onDirectoryChange: { dir in
                        onDirectoryChange?(session.id, dir)
                    }
                )
                .background(OcakTheme.terminalBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        } else {
            emptyState
        }
    }

    private func terminalHeader(for session: ThreadSession) -> some View {
        let dotColor = OcakTheme.statusColor(for: session.status)
        return HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .shadow(color: dotColor.opacity(0.5), radius: 4)

            Text(session.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(OcakTheme.labelPrimary)
                .lineLimit(1)

            if let groupName {
                HStack(spacing: 0) {
                    Text("/ ")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(OcakTheme.sectionLabel)
                        .tracking(1.2)
                    Text(groupName.uppercased())
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(OcakTheme.sectionLabel)
                        .tracking(1.2)
                }
                .lineLimit(1)
                .padding(.leading, 10)
            }

            Spacer()

            if let onClose {
                CloseButton(action: onClose)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(OcakTheme.terminalHeaderBg)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundColor(OcakTheme.tertiaryLabel)
            Text("No active terminal")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(OcakTheme.secondaryLabel)
            Text("Press + to start a new terminal")
                .font(.system(size: 11))
                .foregroundColor(OcakTheme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OcakTheme.terminalBackground)
    }
}

private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(OcakTheme.sectionLabel)
                .frame(width: 24, height: 24)
                .background(isHovered ? OcakTheme.buttonHoverBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
