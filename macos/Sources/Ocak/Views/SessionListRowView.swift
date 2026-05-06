import AppKit
import SwiftUI

/// A session row with status badge, glowing dot, and active tint background.
struct SessionListRowView: View {
    let session: ThreadSession
    let isSelected: Bool
    var isDragging: Bool = false
    var onSelect: () -> Void
    var onRename: (String) -> Void
    var onDelete: () -> Void
    var onMark: () -> Void

    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var outsideClickMonitor: Any?
    @State private var displayedName: String = ""
    @State private var typingTask: Task<Void, Never>?
    @State private var userJustRenamed = false

    var body: some View {
        HStack(spacing: 10) {
            statusDot

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
                Text(displayedName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OcakTheme.labelPrimary)
                    .lineLimit(1)
                    .onTapGesture(count: 2) { startRename() }
            }

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            ZStack {
                if session.isMarked {
                    GeometryReader { geo in
                        let lineHeight = geo.size.height * 0.5
                        let yOffset = (geo.size.height - lineHeight) / 2
                        OcakTheme.activeBorder
                            .frame(width: 3, height: lineHeight)
                            .cornerRadius(2)
                            .position(x: 2, y: yOffset + lineHeight / 2)
                    }
                }
                isSelected ? OcakTheme.activeTint : Color.clear
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? OcakTheme.activeBorder : Color.clear, lineWidth: 1)
        )
        .opacity(isDragging ? 0.35 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button(session.isMarked ? "Unmark" : "Mark") { onMark() }
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
        .onAppear { displayedName = session.name }
        .onChange(of: session.name) { _, newName in
            guard !isRenaming else {
                displayedName = newName
                return
            }
            if userJustRenamed {
                userJustRenamed = false
                displayedName = newName
            } else {
                animateTyping(newName)
            }
        }
        .onDisappear {
            removeOutsideClickMonitor()
            typingTask?.cancel()
        }
    }

    private var statusDot: some View {
        let color = OcakTheme.statusColor(for: session.status)
        let glowColor: Color = (session.status == .working || session.status == .needs_input)
            ? color.opacity(0.5)
            : .clear
        let symbolName = session.statusIcon
        return Image(systemName: symbolName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(isSelected ? OcakTheme.activeIconColor : OcakTheme.sessionIconColor)
            .contentTransition(.symbolEffect(.replace))
            .shadow(color: glowColor, radius: 4)
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

    private func animateTyping(_ name: String) {
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            displayedName = ""
            for char in name {
                try? await Task.sleep(nanoseconds: 45_000_000)
                guard !Task.isCancelled else { break }
                displayedName.append(char)
            }
            if !Task.isCancelled { displayedName = name }
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
        userJustRenamed = true
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
