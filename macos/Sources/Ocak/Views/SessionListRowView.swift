import AppKit
import SwiftUI

/// A session row with status badge, glowing dot, and active tint background.
struct SessionListRowView: View {
    /// Approximate visual row height (vertical padding 10×2 + ~18pt name text).
    /// Used by drag/drop logic to compute the insertion-line midpoint without a layout read.
    static let approximateRowHeight: CGFloat = 38

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(session.isMarked ? OcakTheme.cardBg : OcakTheme.text)
                    .lineLimit(1)
                    .padding(session.isMarked ? EdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5) : EdgeInsets())
                    .background(session.isMarked ? OcakTheme.text.opacity(0.9) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onTapGesture(count: 2) { startRename() }
            }

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            isSelected ? OcakTheme.activeTint : Color.clear
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? OcakTheme.selectionBorder : Color.clear, lineWidth: 1)
                .shadow(color: isSelected ? OcakTheme.selectionGlow : .clear, radius: 9)
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
            } else if reduceMotion {
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
        EmberDot(status: session.status, size: 8, isMarked: session.isMarked)
    }

    private var statusBadge: some View {
        let (text, color) = badgeInfo
        return Text(text)
            .font(.custom("JetBrainsMono-Regular", size: 10))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var badgeInfo: (String, Color) {
        switch session.status {
        case .new:          return ("idle",      OcakTheme.textFaint)
        case .working:      return ("thinking…", OcakTheme.ember)
        case .needs_input:  return ("waiting",   OcakTheme.awaiting)
        case .done:         return ("ready",     OcakTheme.done)
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
