import AppKit
import SwiftUI

/// A session row with status badge, glowing dot, and active tint background.
struct SessionListRowView: View {
    let session: ThreadSession
    let isSelected: Bool
    var onSelect: () -> Void
    var onRename: (String) -> Void
    var onDelete: () -> Void

    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var outsideClickMonitor: Any?

    var body: some View {
        HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 4) {
                if isRenaming {
                    TextField("Terminal name", text: $draftName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(OcakTheme.labelPrimary)
                        .focused($renameFieldFocused)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                        .onChange(of: renameFieldFocused) { _, focused in
                            if !focused { commitRename() }
                        }
                } else {
                    Text(session.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(OcakTheme.labelPrimary)
                        .lineLimit(1)
                        .onTapGesture(count: 2) { startRename() }
                }

                gitInfoLabel
            }

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? OcakTheme.activeTint : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Rename") { startRename() }
            Divider()
            Button("Close", role: .destructive) { onDelete() }
        }
        .onChange(of: isRenaming) { _, editing in
            if editing {
                installOutsideClickMonitor()
            } else {
                removeOutsideClickMonitor()
            }
        }
        .onDisappear { removeOutsideClickMonitor() }
    }

    private var gitInfoLabel: some View {
        let info = GitInfo.read(from: session.workingDirectory)
        return HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9))
            if info.branch != nil {
                Text(info.displayText)
            } else {
                Text("no git")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(OcakTheme.labelSecondary)
        .lineLimit(1)
    }

    private var statusDot: some View {
        let color = OcakTheme.statusColor(for: session.status)
        let glowColor: Color = (session.status == .working || session.status == .needs_input)
            ? color.opacity(0.5)
            : .clear
        let symbolName = session.statusIcon
        return Image(systemName: symbolName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(OcakTheme.sessionIconColor)
            .contentTransition(.symbolEffect(.replace))
            .shadow(color: glowColor, radius: 4)
            .padding(.top, 2)
            .frame(width: 14, alignment: .center)
    }

    private var statusBadge: some View {
        let (text, color) = badgeInfo
        return Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var badgeInfo: (String, Color) {
        switch session.status {
        case .new: return ("Idle", Color(hex: 0x8E8E93))
        case .working: return ("Running", OcakTheme.statusBlue)
        case .needs_input: return ("Needs Input", OcakTheme.statusAmber)
        case .done: return ("Done", OcakTheme.statusGreen)
        }
    }

    private func startRename() {
        draftName = session.name
        isRenaming = true
        renameFieldFocused = true
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        isRenaming = false
        renameFieldFocused = false
        onRename(trimmed.isEmpty ? session.name : trimmed)
    }

    private func cancelRename() {
        isRenaming = false
        renameFieldFocused = false
        onSelect()
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window,
                  let hit = window.contentView?.hitTest(event.locationInWindow)
            else { return event }

            var view: NSView? = hit
            while let current = view {
                if current is NSTextView || current is NSTextField {
                    return event
                }
                view = current.superview
            }

            DispatchQueue.main.async { commitRename() }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
