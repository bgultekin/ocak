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

    static func ocakTextLogo(colorScheme: ColorScheme) -> Image? {
        let name = colorScheme == .dark ? "ocak-text-light" : "ocak-text-dark"
        if let url = Bundle.module.url(forResource: name, withExtension: "png"),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return nil
    }
}

/// The 320px-wide session sidebar with Ocak app header and grouped session cards.
struct SessionListView: View {
    @Bindable var store: SessionStore
    let width: CGFloat
    var onSelect: ((UUID) -> Void)?
    var onNewSession: (UUID) -> Void
    var onNewGroup: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var draggedSession: ThreadSession?
    @State private var dropTargetGroupID: UUID?
    @State private var isHeaderNewGroupHovered = false

    var body: some View {
        VStack(spacing: 0) {
            appHeader

            if UpdateService.shared.availableUpdate != nil {
                UpdateAvailableBox(service: UpdateService.shared)
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 8))
            }

            if !HookInstaller.isInstalled() || !HookInstaller.isOpenCodeHooksInstalled() {
                HookSetupBox()
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 8))
            }

            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 10) {
                        ForEach(Array(store.groupedSessions.enumerated()), id: \.element.group.id) { index, item in
                            GroupListItem(
                                group: item.group,
                                sessions: item.sessions,
                                groupIndex: index,
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
                                isDropTarget: dropTargetGroupID == item.group.id,
                                onSessionDroppedOnGroup: { session, sourceGroupID in
                                    let targetCount = item.sessions.count
                                    store.moveSession(session.id, toGroup: item.group.id, at: targetCount)
                                    dropTargetGroupID = nil
                                    draggedSession = nil
                                },
                                draggedSession: $draggedSession,
                                dropTargetGroupID: $dropTargetGroupID,
                                store: store
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onDrop(
                                of: [.text],
                                delegate: GroupDropTargetDelegate(
                                    groupID: item.group.id,
                                    index: index,
                                    draggedSession: $draggedSession,
                                    dropTargetGroupID: $dropTargetGroupID,
                                    onSessionDrop: { session in
                                        let targetCount = item.sessions.count
                                        store.moveSession(session.id, toGroup: item.group.id, at: targetCount)
                                        dropTargetGroupID = nil
                                        draggedSession = nil
                                    },
                                    onExpandGroup: {
                                        store.setGroupCollapsed(item.group.id, collapsed: false)
                                    }
                                )
                            )
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: store.groups.map { $0.id })
                    .animation(.easeInOut(duration: 0.25), value: store.sessions.map { $0.id })
                    .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 8))
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
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(OcakTheme.buttonBackground)
                Image.ocakIcon(active: true)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            .frame(width: 26, height: 26)

            if let logo = Image.ocakTextLogo(colorScheme: colorScheme) {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 16)
            } else {
                Text("Ocak")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OcakTheme.labelPrimary)
            }

            Spacer()

            Button(action: onNewGroup) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(OcakTheme.labelPrimary.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(isHeaderNewGroupHovered ? OcakTheme.buttonHoverBackground : OcakTheme.buttonBackground)
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
        .frame(height: 64)
        .background(OcakTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 8))
    }
}

/// Wraps a single group card with its drop target logic to help the compiler type-check.
struct GroupListItem: View {
    let group: SessionGroup
    let sessions: [ThreadSession]
    let groupIndex: Int
    let activeSessionID: UUID?
    var onSelect: (UUID) -> Void
    var onRename: (UUID, String) -> Void
    var onDelete: (UUID) -> Void
    var onNewSessionInGroup: () -> Void
    var onSaveGroupSettings: (String, String?, String?, Bool) -> Void
    let isDropTarget: Bool
    var onSessionDroppedOnGroup: (ThreadSession, UUID) -> Void
    @Binding var draggedSession: ThreadSession?
    @Binding var dropTargetGroupID: UUID?
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
            dropTargetGroupID: $dropTargetGroupID,
            store: store
        )
        .onDrop(
            of: [.text],
            delegate: GroupDropTargetDelegate(
                groupID: group.id,
                index: groupIndex,
                draggedSession: $draggedSession,
                dropTargetGroupID: $dropTargetGroupID,
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
    let index: Int
    @Binding var draggedSession: ThreadSession?
    @Binding var dropTargetGroupID: UUID?
    let onSessionDrop: (ThreadSession) -> Void
    var onExpandGroup: (() -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        if let session = draggedSession {
            onSessionDrop(session)
            return true
        }
        dropTargetGroupID = nil
        return false
    }

    func dropEntered(info: DropInfo) {
        dropTargetGroupID = groupID
        onExpandGroup?()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if dropTargetGroupID == groupID {
            dropTargetGroupID = nil
        }
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedSession != nil
    }
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
    @Binding var dropTargetGroupID: UUID?
    let store: SessionStore

    @State private var isEditingSettings = false
    @State private var editName = ""
    @State private var editDirectory = ""
    @State private var editInitialCommand = ""
    @State private var editOpenInVSCode = false
    @State private var showingDeleteConfirmation = false
    @State private var isSettingsHovered = false
    @State private var isVSCodeHovered = false
    @State private var isNewSessionHovered = false

    @State private var isGroupHovered = false
    @State private var isRenamingGroup = false
    @State private var draftGroupName = ""
    @State private var outsideClickMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            if !group.isCollapsed || isEditingSettings {
                dividerLine
                contentArea
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(groupBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: isEditingSettings)
        .animation(.easeInOut(duration: 0.2), value: group.isCollapsed)
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
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
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(groupTitleColor)
                    .tracking(1.2)
                    .lineLimit(1)
                    .onTapGesture(count: 2) { startGroupRename() }
                if group.isCollapsed, let dotColor = groupStatusDotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            if group.isCollapsed && !isEditingSettings {
                if group.openInVSCode, let dir = group.directory, !dir.isEmpty {
                    vsCodeButton(directory: dir)
                }
                collapsedTrailing
            } else if !isEditingSettings {
                settingsButton
                if group.openInVSCode, let dir = group.directory, !dir.isEmpty {
                    vsCodeButton(directory: dir)
                }
                newSessionButton
            }
        }
        .onChange(of: isRenamingGroup) { _, editing in
            if editing {
                installOutsideClickMonitor()
            } else {
                removeOutsideClickMonitor()
            }
        }
        .onDisappear { removeOutsideClickMonitor() }
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

    private var settingsButton: some View {
        Button {
            editName = group.name
            editDirectory = group.directory ?? ""
            editInitialCommand = group.initialCommand ?? ""
            editOpenInVSCode = group.openInVSCode
            withAnimation(.easeInOut(duration: 0.2)) {
                store.setGroupCollapsed(group.id, collapsed: false)
                isEditingSettings = true
            }
        } label: {
            Image(systemName: "gear")
                .font(.system(size: 16))
                .foregroundColor(groupTitleColor)
                .frame(width: 24, height: 24)
                .background(isSettingsHovered ? OcakTheme.buttonHoverBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Group settings")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isSettingsHovered = hovering
            }
        }
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
                    dropTargetGroupID: $dropTargetGroupID
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: sessions.map { $0.id })
    }

    private var emptyState: some View {
        Text("No terminals")
            .font(.system(size: 11))
            .foregroundColor(OcakTheme.sectionLabel.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private var groupBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isDropTarget ? OcakTheme.dropTargetBackground : OcakTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDropTarget ? OcakTheme.dropTargetBorder : Color.clear, lineWidth: 1.5)
            )
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

            HStack {
                deleteButton

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
                    onSaveGroupSettings(editName, dir.isEmpty ? nil : dir, cmd.isEmpty ? nil : cmd, editOpenInVSCode)
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

    private var deleteButton: some View {
        Button("Delete Group") {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingDeleteConfirmation = true
            }
        }
        .font(.system(size: 11))
        .buttonStyle(.borderedProminent)
        .tint(.red)
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
    @Binding var dropTargetGroupID: UUID?

    var body: some View {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            return AnyView(EmptyView())
        }
        return AnyView(
            SessionListRowView(
                session: session,
                isSelected: session.id == activeSessionID,
                onSelect: { onSelect(session.id) },
                onRename: { newName in onRename(session.id, newName) },
                onDelete: { onDelete(session.id) }
            )
            .id(session.id)
            .onDrag {
                draggedSession = session
                return NSItemProvider(object: "session" as NSString)
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
                    dropTargetGroupID: $dropTargetGroupID,
                    onReorderInGroup: { draggedSession, destIndex in
                        store.reorderSessionInGroup(group.id, sessionID: draggedSession.id, to: destIndex)
                        self.draggedSession = nil
                    },
                    onSessionDrop: { draggedSession, sourceGroupID in
                        if sourceGroupID == group.id {
                            store.reorderSessionInGroup(group.id, sessionID: draggedSession.id, to: index)
                        } else {
                            store.moveSession(draggedSession.id, toGroup: group.id, at: index)
                        }
                        self.draggedSession = nil
                    }
                )
            )
        )
    }
}

struct SessionRowDropTargetDelegate: DropDelegate {
    let targetSessionID: UUID
    let groupID: UUID
    let sessions: [ThreadSession]
    let destinationIndex: Int
    @Binding var draggedSession: ThreadSession?
    @Binding var dropTargetGroupID: UUID?
    let onReorderInGroup: (ThreadSession, Int) -> Void
    let onSessionDrop: (ThreadSession, UUID) -> Void

    func performDrop(info: DropInfo) -> Bool {
        if let session = draggedSession {
            if session.groupID == groupID {
                onReorderInGroup(session, destinationIndex)
            } else {
                onSessionDrop(session, session.groupID)
            }
            return true
        }
        return false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
            .font: NSFont.systemFont(ofSize: 12, weight: .light),
            .foregroundColor: color,
            .kern: CGFloat(1.2),
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

        DispatchQueue.main.async {
            tf.window?.makeFirstResponder(tf)
            if let editor = tf.currentEditor() as? NSTextView {
                editor.typingAttributes = attrs
                if let storage = editor.textStorage, storage.length > 0 {
                    storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
                }
                editor.selectAll(nil)
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
