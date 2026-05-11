import SwiftUI
import AppKit

extension Image {
    static func ocakIcon(active: Bool) -> Image {
        let name = active ? "ocak-menubar-icon-active" : "ocak-menubar-icon-default"
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "terminal")
    }

}

private struct FlameIcon: View {
    @State private var flickering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image.ocakIcon(active: true)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundStyle(
                LinearGradient(
                    colors: [OcakTheme.flameGradientStart, OcakTheme.flameGradientMid, OcakTheme.flameGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: OcakTheme.flameShadow, radius: 6)
            .scaleEffect(y: flickering ? 0.96 : 1.0)
            .opacity(flickering ? 0.92 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    flickering = true
                }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced {
                    flickering = false
                } else {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        flickering = true
                    }
                }
            }
    }
}

struct DropIndicator: Equatable {
    let groupID: UUID
    let index: Int
}

struct DropInsertionLine: View {
    var body: some View {
        Capsule()
            .fill(OcakTheme.activeBorder)
            .frame(height: 2)
            .padding(.horizontal, 4)
            .transition(.opacity)
    }
}

/// The 320px-wide session sidebar with Ocak app header and grouped session cards.
struct SessionListView: View {
    @Bindable var store: SessionStore
    let width: CGFloat
    var onSelect: ((UUID) -> Void)?
    var onNewSession: (UUID) -> Void
    var onNewGroup: () -> Void

    @State private var draggedSession: ThreadSession?
    @State private var dropIndicator: DropIndicator?
    @State private var isHeaderNewGroupHovered = false
    @State private var draggedGroup: SessionGroup?
    @State private var groupDropIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            appHeader

            if UpdateService.shared.availableUpdate != nil {
                UpdateAvailableBox(service: UpdateService.shared)
                    .padding(EdgeInsets(top: 8, leading: 14, bottom: 0, trailing: 14))
            }

            if !HookInstaller.isInstalled() || !HookInstaller.isOpenCodeHooksInstalled() {
                HookSetupBox()
                    .padding(EdgeInsets(top: 8, leading: 14, bottom: 0, trailing: 14))
            }

            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        let groups = store.groupedSessions
                        // Slot 0: insertion point before first group
                        if groupDropIndex == 0 {
                            DropInsertionLine().padding(.vertical, 4)
                        }
                        ForEach(Array(groups.enumerated()), id: \.element.group.id) { index, item in
                            GroupListItem(
                                group: item.group,
                                sessions: item.sessions,
                                groupIndex: index,
                                groupCount: groups.count,
                                activeSessionID: store.activeSessionID,
                                onSelect: { (onSelect ?? store.selectSession)($0) },
                                onRename: { id, name in
                                    store.renameSession(id, name: name)
                                    store.selectSession(id)
                                },
                                onDelete: { store.removeSession($0) },
                                onNewSessionInGroup: { onNewSession(item.group.id) },
                                onSaveGroupSettings: { name, directory, initialCommand, openInVSCode in
                                    store.renameGroup(item.group.id, name: name)
                                    store.updateGroupDirectory(item.group.id, directory: directory)
                                    store.updateGroupInitialCommand(item.group.id, command: initialCommand)
                                    store.updateGroupOpenInVSCode(item.group.id, openInVSCode: openInVSCode)
                                },
                                isDropTarget: dropIndicator?.groupID == item.group.id && draggedSession?.groupID != item.group.id,
                                onSessionDroppedOnGroup: { session, sourceGroupID in
                                    let targetCount = item.sessions.count
                                    store.moveSession(session.id, toGroup: item.group.id, at: targetCount)
                                    dropIndicator = nil
                                    draggedSession = nil
                                },
                                draggedSession: $draggedSession,
                                dropIndicator: $dropIndicator,
                                draggedGroup: $draggedGroup,
                                groupDropIndex: $groupDropIndex,
                                store: store
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            // Slot index+1: insertion point after this group.
                            // The line replaces the gap so it sits centred in the same 10pt space.
                            if groupDropIndex == index + 1 {
                                DropInsertionLine().padding(.vertical, 4)
                            } else if index < groups.count - 1 {
                                Color.clear.frame(height: 14)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: store.groups.map { $0.id })
                    .animation(.easeInOut(duration: 0.25), value: store.groups.map { $0.order })
                    .animation(.easeInOut(duration: 0.25), value: store.sessions.map { $0.id })
                    .padding(EdgeInsets(top: 14, leading: 14, bottom: 50, trailing: 14))
                    .onChange(of: store.activeSessionID) { _, newID in
                        if let newID {
                            withAnimation {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: width)
    }

    private var appHeader: some View {
        HStack(spacing: 10) {
            FlameIcon()

            Text("Ocak")
                .font(.custom("InstrumentSerif-Italic", size: 24))
                .foregroundColor(OcakTheme.text)
                .kerning(-0.4)

            Spacer()

            Button(action: onNewGroup) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13))
                    .foregroundColor(OcakTheme.textDim)
                    .frame(width: 28, height: 28)
                    .background(isHeaderNewGroupHovered ? OcakTheme.buttonHoverBackground : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(OcakTheme.cardEdge, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .contentShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHeaderNewGroupHovered = hovering
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .hearthCard(shadowRadius: 10)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 0, trailing: 14))
    }
}

/// Wraps a single group card with its drop target logic to help the compiler type-check.
struct GroupListItem: View {
    let group: SessionGroup
    let sessions: [ThreadSession]
    let groupIndex: Int
    let groupCount: Int
    let activeSessionID: UUID?
    var onSelect: (UUID) -> Void
    var onRename: (UUID, String) -> Void
    var onDelete: (UUID) -> Void
    var onNewSessionInGroup: () -> Void
    var onSaveGroupSettings: (String, String?, String?, Bool) -> Void
    let isDropTarget: Bool
    var onSessionDroppedOnGroup: (ThreadSession, UUID) -> Void
    @Binding var draggedSession: ThreadSession?
    @Binding var dropIndicator: DropIndicator?
    @Binding var draggedGroup: SessionGroup?
    @Binding var groupDropIndex: Int?
    let store: SessionStore

    var body: some View {
        SessionGroupListView(
            group: group,
            sessions: sessions,
            activeSessionID: activeSessionID,
            onSelect: onSelect,
            onRename: onRename,
            onDelete: onDelete,
            onNewSessionInGroup: onNewSessionInGroup,
            onSaveGroupSettings: onSaveGroupSettings,
            groupIndex: groupIndex,
            isDropTarget: isDropTarget,
            onSessionDroppedOnGroup: onSessionDroppedOnGroup,
            draggedSession: $draggedSession,
            dropIndicator: $dropIndicator,
            draggedGroup: $draggedGroup,
            groupDropIndex: $groupDropIndex,
            store: store
        )
        .onDrop(
            of: [.text],
            delegate: GroupDropTargetDelegate(
                groupID: group.id,
                groupIndex: groupIndex,
                groupCount: groupCount,
                sessionCount: sessions.count,
                draggedSession: $draggedSession,
                dropIndicator: $dropIndicator,
                draggedGroup: $draggedGroup,
                groupDropIndex: $groupDropIndex,
                store: store,
                onSessionDrop: { session in
                    onSessionDroppedOnGroup(session, session.groupID)
                },
                onExpandGroup: {
                    store.setGroupCollapsed(group.id, collapsed: false)
                }
            )
        )
    }
}

struct GroupDropTargetDelegate: DropDelegate {
    let groupID: UUID
    let groupIndex: Int
    let groupCount: Int
    let sessionCount: Int
    @Binding var draggedSession: ThreadSession?
    @Binding var dropIndicator: DropIndicator?
    @Binding var draggedGroup: SessionGroup?
    @Binding var groupDropIndex: Int?
    let store: SessionStore
    let onSessionDrop: (ThreadSession) -> Void
    var onExpandGroup: (() -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        draggedSession != nil || (draggedGroup != nil && groupCount > 1)
    }

    // MARK: - Group reordering

    private func groupInsertion(locationY: CGFloat) -> Int {
        // Top 30pt of the card → insert before this group; rest → insert after.
        locationY < 30 ? groupIndex : groupIndex + 1
    }

    private func isNoOpGroupDrop(insertion: Int) -> Bool {
        guard let dragged = draggedGroup else { return true }
        let src = store.groups.sorted { $0.order < $1.order }
            .firstIndex(where: { $0.id == dragged.id }) ?? 0
        return insertion == src || insertion == src + 1
    }

    private func sourceGroupIndex() -> Int? {
        guard let dragged = draggedGroup else { return nil }
        return store.groups.sorted { $0.order < $1.order }
            .firstIndex(where: { $0.id == dragged.id })
    }

    // MARK: - Session drop helpers

    private func isNoOpTrailingDrop(_ session: ThreadSession) -> Bool {
        session.groupID == groupID && session.order == sessionCount - 1
    }

    // MARK: - DropDelegate

    func dropEntered(info: DropInfo) {
        if draggedGroup != nil {
            let insertion = groupInsertion(locationY: info.location.y)
            guard !isNoOpGroupDrop(insertion: insertion) else { return }
            withAnimation(.easeInOut(duration: 0.12)) { groupDropIndex = insertion }
        } else {
            onExpandGroup?()
            if let session = draggedSession, isNoOpTrailingDrop(session) { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                dropIndicator = DropIndicator(groupID: groupID, index: sessionCount)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if draggedGroup != nil {
            let insertion = groupInsertion(locationY: info.location.y)
            if isNoOpGroupDrop(insertion: insertion) {
                withAnimation(.easeInOut(duration: 0.12)) { groupDropIndex = nil }
                return DropProposal(operation: .forbidden)
            }
            withAnimation(.easeInOut(duration: 0.12)) { groupDropIndex = insertion }
            return DropProposal(operation: .move)
        } else {
            if let session = draggedSession, isNoOpTrailingDrop(session) {
                return DropProposal(operation: .forbidden)
            }
            return DropProposal(operation: .move)
        }
    }

    func dropExited(info: DropInfo) {
        if draggedGroup != nil {
            let insertion = groupInsertion(locationY: info.location.y)
            if groupDropIndex == insertion {
                withAnimation(.easeInOut(duration: 0.12)) { groupDropIndex = nil }
            }
        } else if dropIndicator?.groupID == groupID {
            withAnimation(.easeInOut(duration: 0.12)) { dropIndicator = nil }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        if draggedGroup != nil {
            defer { groupDropIndex = nil; draggedGroup = nil }
            guard let src = sourceGroupIndex() else { return false }
            let insertion = groupDropIndex ?? groupInsertion(locationY: info.location.y)
            guard !isNoOpGroupDrop(insertion: insertion) else { return false }
            let dest = src < insertion ? insertion - 1 : insertion
            withAnimation(.easeInOut(duration: 0.25)) { store.moveGroup(from: src, to: dest) }
            return true
        } else {
            guard let session = draggedSession else { dropIndicator = nil; return false }
            if isNoOpTrailingDrop(session) { dropIndicator = nil; draggedSession = nil; return false }
            onSessionDrop(session)
            dropIndicator = nil
            return true
        }
    }
}

private final class GroupMenuHandler: NSObject {
    private var onSettings: (() -> Void)?
    private var onDelete: (() -> Void)?

    func popUp(onSettings: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.onSettings = onSettings
        self.onDelete = onDelete

        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(handleSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: "Delete", action: #selector(handleDelete), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        guard let event = NSApp.currentEvent,
              let view = event.window?.contentView ?? NSApp.keyWindow?.contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func handleSettings() { onSettings?() }
    @objc private func handleDelete() { onDelete?() }
}

/// Directory group shown as a card with project name header.
struct SessionGroupListView: View {
    let group: SessionGroup
    let sessions: [ThreadSession]
    let activeSessionID: UUID?
    var onSelect: (UUID) -> Void
    var onRename: (UUID, String) -> Void
    var onDelete: (UUID) -> Void
    var onNewSessionInGroup: () -> Void
    var onSaveGroupSettings: (String, String?, String?, Bool) -> Void
    let groupIndex: Int
    let isDropTarget: Bool
    var onSessionDroppedOnGroup: (ThreadSession, UUID) -> Void
    @Binding var draggedSession: ThreadSession?
    @Binding var dropIndicator: DropIndicator?
    @Binding var draggedGroup: SessionGroup?
    @Binding var groupDropIndex: Int?
    let store: SessionStore

    @State private var isEditingSettings = false
    @State private var editName = ""
    @State private var editDirectory = ""
    @State private var editInitialCommand = ""
    @State private var editOpenInVSCode = false
    @State private var showingDeleteConfirmation = false
    @State private var isVSCodeHovered = false
    @State private var isNewSessionHovered = false

    @State private var isGroupHovered = false
    @State private var isRenamingGroup = false
    @State private var draftGroupName = ""
    @State private var outsideClickMonitor: Any?
    @State private var groupMenuHandler = GroupMenuHandler()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            draggableHeaderRow
            if !group.isCollapsed || isEditingSettings {
                dividerLine
                contentArea
                    .transition(.opacity)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 14))
        .hearthCard(radius: 14, shadowRadius: 10)
        .animation(.easeInOut(duration: 0.2), value: isEditingSettings)
        .animation(.easeInOut(duration: 0.2), value: group.isCollapsed)
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .onChange(of: isRenamingGroup) { _, editing in
            if editing {
                installOutsideClickMonitor()
            } else {
                removeOutsideClickMonitor()
            }
        }
        .onDisappear { removeOutsideClickMonitor() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isGroupHovered = hovering }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            if !isRenamingGroup {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.setGroupCollapsed(group.id, collapsed: !group.isCollapsed)
                    }
                } label: {
                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(groupTitleColor)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isRenamingGroup {
                GroupNameTextField(
                    text: $draftGroupName,
                    color: NSColor(OcakTheme.sectionLabel),
                    onCommit: commitGroupRename,
                    onCancel: cancelGroupRename
                )
                .frame(maxWidth: .infinity)
            } else {
                Text(group.name.uppercased())
                    .font(.custom("JetBrainsMono-Medium", size: 10))
                    .foregroundColor(groupTitleColor)
                    .tracking(1.6)
                    .lineLimit(1)
                    .onTapGesture(count: 2) { startGroupRename() }
                    .contextMenu { groupContextMenuItems }
                if group.isCollapsed, let dotColor = groupStatusDotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
                if !isEditingSettings {
                    ellipsisMenu
                }
            }

            Spacer()

            if group.isCollapsed && !isEditingSettings {
                if group.openInVSCode, let dir = group.directory, !dir.isEmpty {
                    vsCodeButton(directory: dir)
                }
                collapsedTrailing
            } else if !isEditingSettings {
                if group.openInVSCode, let dir = group.directory, !dir.isEmpty {
                    vsCodeButton(directory: dir)
                }
                newSessionButton
            }
        }
    }

    @ViewBuilder private var draggableHeaderRow: some View {
        if isRenamingGroup {
            headerRow
        } else {
            headerRow
                .contentShape(Rectangle())
                .onDrag {
                    draggedGroup = group
                    let groupID = group.id
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        while NSEvent.pressedMouseButtons & 1 != 0 {
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                        if draggedGroup?.id == groupID {
                            draggedGroup = nil
                            groupDropIndex = nil
                        }
                    }
                    return NSItemProvider(object: group.id.uuidString as NSString)
                } preview: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(OcakTheme.sectionLabel)
                            .frame(width: 24, height: 24)
                        Text(group.name.uppercased())
                            .font(.custom("JetBrainsMono-Medium", size: 10))
                            .foregroundColor(OcakTheme.sectionLabel)
                            .tracking(1.6)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 260)
                    .hearthCard(radius: 10, shadowRadius: 10)
                }
        }
    }

    private func startGroupRename() {
        draftGroupName = group.name.uppercased()
        isRenamingGroup = true
    }

    private func commitGroupRename() {
        guard isRenamingGroup else { return }
        let trimmed = draftGroupName.trimmingCharacters(in: .whitespaces)
        isRenamingGroup = false
        let finalName = trimmed.isEmpty ? group.name : trimmed
        guard finalName.uppercased() != group.name.uppercased() else { return }
        onSaveGroupSettings(finalName, group.directory, group.initialCommand, group.openInVSCode)
    }

    private func cancelGroupRename() {
        isRenamingGroup = false
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

            DispatchQueue.main.async { commitGroupRename() }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    @ViewBuilder private var groupContextMenuItems: some View {
        Button("Settings") {
            editName = group.name
            editDirectory = group.directory ?? ""
            editInitialCommand = group.initialCommand ?? ""
            editOpenInVSCode = group.openInVSCode
            withAnimation(.easeInOut(duration: 0.2)) {
                store.setGroupCollapsed(group.id, collapsed: false)
                isEditingSettings = true
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.setGroupCollapsed(group.id, collapsed: false)
                isEditingSettings = true
                showingDeleteConfirmation = true
            }
        }
    }

    private var ellipsisMenu: some View {
        Button {
            groupMenuHandler.popUp(
                onSettings: {
                    editName = group.name
                    editDirectory = group.directory ?? ""
                    editInitialCommand = group.initialCommand ?? ""
                    editOpenInVSCode = group.openInVSCode
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.setGroupCollapsed(group.id, collapsed: false)
                        isEditingSettings = true
                    }
                },
                onDelete: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.setGroupCollapsed(group.id, collapsed: false)
                        isEditingSettings = true
                        showingDeleteConfirmation = true
                    }
                }
            )
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(OcakTheme.sectionLabel)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func vsCodeButton(directory: String) -> some View {
        Button {
            openInVSCode(directory: directory)
        } label: {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 13))
                .foregroundColor(groupTitleColor)
                .frame(width: 24, height: 24)
                .background(isVSCodeHovered ? OcakTheme.buttonHoverBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Open in VS Code")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isVSCodeHovered = hovering
            }
        }
    }

    private func openInVSCode(directory: String) {
        VSCodeLauncher.open(directory: directory)
    }

    private var newSessionButton: some View {
        Button(action: onNewSessionInGroup) {
            Image(systemName: "plus")
                .font(.system(size: 16))
                .foregroundColor(groupTitleColor)
                .frame(width: 24, height: 24)
                .background(isNewSessionHovered ? OcakTheme.buttonHoverBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("New terminal")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isNewSessionHovered = hovering
            }
        }
    }

    private var collapsedTrailing: some View {
        let count = sessions.count
        return Text("\(count) terminal\(count == 1 ? "" : "s")")
            .font(.system(size: 11))
            .foregroundColor(OcakTheme.sectionLabel.opacity(0.7))
    }

    private var groupTitleColor: Color {
        let highlighted = isGroupHovered || sessions.contains(where: { $0.id == activeSessionID })
        return highlighted ? OcakTheme.sectionLabelHighlighted : OcakTheme.sectionLabel
    }

    private var groupStatusDotColor: Color? {
        if sessions.contains(where: { $0.status == .needs_input }) {
            return OcakTheme.statusColor(for: .needs_input)
        }
        if sessions.contains(where: { $0.status == .working }) {
            return OcakTheme.statusColor(for: .working)
        }
        if sessions.contains(where: { $0.status == .done }) {
            return OcakTheme.statusColor(for: .done)
        }
        return nil
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(OcakTheme.divider)
            .frame(height: 1)
    }

    private var contentArea: some View {
        Group {
            if isEditingSettings {
                settingsForm
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if !sessions.isEmpty {
                sessionList
            } else {
                emptyState
            }
        }
    }

    private var sessionList: some View {
        VStack(spacing: 4) {
            ForEach(sessions, id: \.id) { session in
                SessionRowItem(
                    session: session,
                    sessions: sessions,
                    group: group,
                    groupIndex: groupIndex,
                    activeSessionID: activeSessionID,
                    onSelect: onSelect,
                    onRename: onRename,
                    onDelete: onDelete,
                    store: store,
                    draggedSession: $draggedSession,
                    dropIndicator: $dropIndicator
                )
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                .transition(.opacity)
            }
            if dropIndicator?.groupID == group.id && dropIndicator?.index == sessions.count {
                DropInsertionLine()
            }
        }
        .animation(.easeInOut(duration: 0.12), value: dropIndicator)
        .animation(.easeInOut(duration: 0.2), value: sessions.map { $0.id })
    }

    private var emptyState: some View {
        Text("no terminals")
            .font(.custom("JetBrainsMono-Regular", size: 11))
            .italic()
            .foregroundColor(OcakTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private var settingsForm: some View {
        Group {
            if showingDeleteConfirmation {
                deleteConfirmationView
            } else {
                settingsFormContent
            }
        }
    }

    private var settingsFormContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("NAME")
            TextField("", text: $editName, prompt: Text("Group name").foregroundColor(OcakTheme.sectionLabel))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(OcakTheme.labelPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(OcakTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(OcakTheme.inputBorder, lineWidth: 1))

            Spacer()
                .frame(height: 12)

            HStack {
                fieldLabel("DEFAULT FOLDER")
                Spacer()
                Text("optional")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(OcakTheme.sectionLabel.opacity(0.6))
            }

            HStack(spacing: 6) {
                TextField("", text: $editDirectory, prompt: Text("Home directory").foregroundColor(OcakTheme.sectionLabel))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(OcakTheme.labelPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(OcakTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(OcakTheme.inputBorder, lineWidth: 1))
                Button("Browse…") { browseForDirectory() }
                    .font(.system(size: 11))
                    .foregroundStyle(OcakTheme.labelPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(OcakTheme.buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)
            }

            Spacer()
                .frame(height: 12)

            HStack {
                fieldLabel("INITIAL COMMAND")
                Spacer()
                Text("optional")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(OcakTheme.sectionLabel.opacity(0.6))
            }

            TextField("", text: $editInitialCommand, prompt: Text("e.g., claude, opencode, ssh user@host").foregroundColor(OcakTheme.sectionLabel))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(OcakTheme.labelPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(OcakTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(OcakTheme.inputBorder, lineWidth: 1))

            Spacer()
                .frame(height: 12)

            if VSCodeLauncher.isInstalled {
                Toggle(isOn: $editOpenInVSCode) {
                    Text("SHOW VS CODE BUTTON")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(OcakTheme.sectionLabel)
                        .kerning(0.8)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Spacer()
                    .frame(height: 12)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingSettings = false
                    }
                }
                .font(.system(size: 11))
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let dir = editDirectory.trimmingCharacters(in: .whitespaces)
                    let cmd = editInitialCommand.trimmingCharacters(in: .whitespaces)
                    onSaveGroupSettings(editName, dir.isEmpty ? nil : dir, cmd.isEmpty ? nil : cmd, editOpenInVSCode && VSCodeLauncher.isInstalled)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingSettings = false
                    }
                }
                .font(.system(size: 11))
                .keyboardShortcut(.defaultAction)
                .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 20)
        }
    }

    private var deleteConfirmationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete Group")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.red)

            Text("This will delete \"\(group.name)\" and all \(sessions.count) terminal\(sessions.count == 1 ? "" : "s") in it. This cannot be undone.")
                .font(.system(size: 11))
                .foregroundColor(OcakTheme.sectionLabel)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingSettings = false
                        showingDeleteConfirmation = false
                    }
                }
                .font(.system(size: 11))
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Delete") {
                    store.removeGroup(group.id)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingSettings = false
                        showingDeleteConfirmation = false
                    }
                }
                .font(.system(size: 11))
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(OcakTheme.sectionLabel)
            .kerning(0.8)
    }

    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.level = .statusBar
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            editDirectory = url.path
        }
    }
}

/// Wraps a session row with its drag/drop logic to help the compiler type-check.
struct SessionRowItem: View {
    let session: ThreadSession
    let sessions: [ThreadSession]
    let group: SessionGroup
    let groupIndex: Int
    let activeSessionID: UUID?
    var onSelect: (UUID) -> Void
    var onRename: (UUID, String) -> Void
    var onDelete: (UUID) -> Void
    let store: SessionStore
    @Binding var draggedSession: ThreadSession?
    @Binding var dropIndicator: DropIndicator?

    var body: some View {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            return AnyView(EmptyView())
        }
        let isDragging = draggedSession?.id == session.id
        return AnyView(
            VStack(spacing: 0) {
                if dropIndicator?.groupID == group.id && dropIndicator?.index == index {
                    DropInsertionLine()
                }
                SessionListRowView(
                    session: session,
                    isSelected: session.id == activeSessionID,
                    isDragging: isDragging,
                    onSelect: { onSelect(session.id) },
                    onRename: { newName in onRename(session.id, newName) },
                    onDelete: { onDelete(session.id) },
                    onMark: { store.toggleMark(session.id) }
                )
                .id(session.id)
                .onDrag {
                    draggedSession = session
                    // Watchdog: SwiftUI doesn't notify us when a drag ends without a successful
                    // drop (forbidden drops, drops outside any zone), so the row would stay
                    // dimmed and `draggedSession` would stay set. Poll the physical mouse
                    // button and clear state once it's released.
                    let sessionID = session.id
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        while NSEvent.pressedMouseButtons & 1 != 0 {
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                        if draggedSession?.id == sessionID {
                            draggedSession = nil
                            dropIndicator = nil
                        }
                    }
                    return NSItemProvider(object: session.id.uuidString as NSString)
                } preview: {
                    SessionDragPreview(session: session)
                }
                .onDrop(
                    of: [.text],
                    delegate: SessionRowDropTargetDelegate(
                        targetSessionID: session.id,
                        groupID: group.id,
                        sessions: sessions,
                        destinationIndex: index,
                        draggedSession: $draggedSession,
                        dropIndicator: $dropIndicator,
                        onReorderInGroup: { draggedSession, destIndex in
                            store.reorderSessionInGroup(group.id, sessionID: draggedSession.id, to: destIndex)
                            self.draggedSession = nil
                            self.dropIndicator = nil
                        },
                        onSessionDrop: { draggedSession, destIndex in
                            store.moveSession(draggedSession.id, toGroup: group.id, at: destIndex)
                            self.draggedSession = nil
                            self.dropIndicator = nil
                        }
                    )
                )
            }
        )
    }
}

struct SessionRowDropTargetDelegate: DropDelegate {
    let targetSessionID: UUID
    let groupID: UUID
    let sessions: [ThreadSession]
    let destinationIndex: Int
    @Binding var draggedSession: ThreadSession?
    @Binding var dropIndicator: DropIndicator?
    let onReorderInGroup: (ThreadSession, Int) -> Void
    let onSessionDrop: (ThreadSession, Int) -> Void

    private func computeInsertionIndex(info: DropInfo) -> Int {
        info.location.y < SessionListRowView.approximateRowHeight / 2 ? destinationIndex : destinationIndex + 1
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let session = draggedSession else {
            dropIndicator = nil
            return false
        }
        let insertionIndex = dropIndicator?.index ?? computeInsertionIndex(info: info)
        dropIndicator = nil

        if session.groupID == groupID {
            guard let sourceIndex = sessions.firstIndex(where: { $0.id == session.id }) else { return false }
            if insertionIndex == sourceIndex || insertionIndex == sourceIndex + 1 {
                draggedSession = nil
                return true
            }
            let adjustedDest = sourceIndex < insertionIndex ? insertionIndex - 1 : insertionIndex
            onReorderInGroup(session, adjustedDest)
        } else {
            onSessionDrop(session, insertionIndex)
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let session = draggedSession else { return DropProposal(operation: .forbidden) }
        let insertionIndex = computeInsertionIndex(info: info)

        if session.groupID == groupID,
           let sourceIndex = sessions.firstIndex(where: { $0.id == session.id }),
           insertionIndex == sourceIndex || insertionIndex == sourceIndex + 1 {
            withAnimation(.easeInOut(duration: 0.12)) { dropIndicator = nil }
            return DropProposal(operation: .forbidden)
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            dropIndicator = DropIndicator(groupID: groupID, index: insertionIndex)
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropIndicator?.groupID == groupID {
            withAnimation(.easeInOut(duration: 0.12)) { dropIndicator = nil }
        }
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedSession != nil
    }
}

struct SessionDragPreview: View {
    let session: ThreadSession

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: session.statusIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(OcakTheme.sessionIconColor)
            Text(session.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(OcakTheme.labelPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(OcakTheme.dragPreviewBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// An NSTextField-backed text field that preserves kern during active editing.
/// SwiftUI's `.tracking`/`.kerning` modifiers don't apply inside the field editor;
/// setting `typingAttributes` on the NSTextView (field editor) is the reliable fix.
/// Color is passed explicitly from the SwiftUI body so it follows OcakTheme, not
/// macOS system appearance (the two can differ when the user overrides the theme).
private struct GroupNameTextField: NSViewRepresentable {
    @Binding var text: String
    let color: NSColor
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeAttrs() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont(name: "JetBrainsMono-Medium", size: 10)
                  ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: color,
            .kern: CGFloat(1.6),
        ]
    }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.isEditable = true
        tf.isSelectable = true
        tf.delegate = context.coordinator
        let attrs = makeAttrs()
        tf.attributedStringValue = NSAttributedString(string: text, attributes: attrs)

        // Apply selection/typing attributes once the field editor exists.
        let applyEditorAttrs: (NSTextField) -> Void = { field in
            if let editor = field.currentEditor() as? NSTextView {
                editor.typingAttributes = attrs
                if let storage = editor.textStorage, storage.length > 0 {
                    storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
                }
                editor.selectAll(nil)
            }
        }
        // Heavy reactivation: only used on retry paths after a drag teardown.
        // After a SwiftUI .onDrag in this accessory app, system focus returns to
        // whichever process was previously frontmost. The DrawerPanel can still claim
        // key status within our process, but key events route to the frontmost app —
        // so the field looks focused but receives nothing. Reactivate our process,
        // clear any stuck editing session, then re-key and re-target the field.
        // Note: endEditing(for:) can fire delegate callbacks (e.g. onCommit) on any
        // currently-editing field, so we only invoke it on the recovery path.
        let reactivate: (NSTextField) -> Void = { field in
            NSApp.activate(ignoringOtherApps: true)
            field.window?.endEditing(for: nil)
            field.window?.makeFirstResponder(nil)
            field.window?.makeKey()
            field.window?.orderFrontRegardless()
            guard field.window?.makeFirstResponder(field) == true else { return }
            applyEditorAttrs(field)
        }
        // Initial path: in the common no-drag case, a plain makeFirstResponder is
        // sufficient and avoids needlessly toggling app/window activation state.
        DispatchQueue.main.async { [weak tf] in
            guard let tf else { return }
            if tf.window?.makeFirstResponder(tf) == true {
                applyEditorAttrs(tf)
            }
        }
        // Drag-session cleanup can reset key status *after* the initial focus call.
        // The first responder may still be our field (or its editor) while the window
        // is no longer key, so retry when isKeyWindow / NSApp.isActive are false.
        // Delays are empirical: 0.15s covers the common case where AppKit finishes
        // drag teardown shortly after the field is installed; 0.35s and 0.6s catch
        // slower reactivation paths (e.g. Mission Control / Spaces transitions).
        for delay in [0.15, 0.35, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak tf] in
                guard let tf else { return }
                let isFirstResponder = tf.window?.firstResponder === tf ||
                                       tf.window?.firstResponder === tf.currentEditor()
                let isReady = isFirstResponder
                    && tf.window?.isKeyWindow == true
                    && NSApp.isActive
                if isReady { return }
                reactivate(tf)
            }
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        let attrs = makeAttrs()
        if nsView.stringValue != text {
            nsView.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
        } else if let storage = (nsView.currentEditor() as? NSTextView)?.textStorage, storage.length > 0 {
            storage.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: storage.length))
        }
        (nsView.currentEditor() as? NSTextView)?.typingAttributes = attrs
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: GroupNameTextField

        init(_ parent: GroupNameTextField) { self.parent = parent }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField,
                  let editor = tf.currentEditor() as? NSTextView else { return }
            editor.typingAttributes = parent.makeAttrs()
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField,
                  let editor = tf.currentEditor() as? NSTextView else { return }
            let current = editor.string
            let upper = current.uppercased()
            if current != upper {
                let sel = editor.selectedRange()
                editor.textStorage?.replaceCharacters(
                    in: NSRange(location: 0, length: (current as NSString).length),
                    with: NSAttributedString(string: upper, attributes: parent.makeAttrs())
                )
                editor.setSelectedRange(NSRange(location: min(sel.location, upper.utf16.count), length: 0))
            }
            parent.text = editor.string
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onCommit()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
