import SwiftUI

/// Animatable offset used for the terminal pane fade-from-below transition.
private struct VerticalOffsetModifier: ViewModifier, Animatable {
    var offset: CGFloat
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    func body(content: Content) -> some View {
        content.offset(y: offset)
    }
}

private extension AnyTransition {
    static let fadeFromBelow = AnyTransition
        .modifier(active: VerticalOffsetModifier(offset: 24), identity: VerticalOffsetModifier(offset: 0))
        .combined(with: .opacity)
}

/// The main content view inside the DrawerPanel.
struct DrawerView: View {
    @Bindable var store: SessionStore
    let panelSizeStore: PanelSizeStore
    let currentScreen: NSScreen
    let edge: PanelEdge
    let onWidthChange: ((CGFloat) -> Void)?
    var onNewSession: (UUID) -> Void
    var onNewGroup: () -> Void
    var onSessionSelected: (() -> Void)?
    var onCloseTerminal: (() -> Void)?

    @State private var sessionListDragStart: CGFloat = 0
    @State private var terminalDragStart: CGFloat = 0
    @State private var terminalHeightDragStart: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0, content: mainContent)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(
                store.activeSessionID != nil
                    ? .spring(duration: 0.4, bounce: 0.2)
                    : .easeIn(duration: 0.2),
                value: store.activeSessionID != nil
            )
            .onChange(of: store.activeSessionID) { _, newID in
                if newID != nil {
                    onSessionSelected?()
                }
            }
    }

    // Drag sign: right-edge handles are left of their pane (drag left = expand, sign = -1).
    // Left-edge handles are right of their pane (drag right = expand, sign = +1).
    private var dragSign: CGFloat { edge == .left ? 1 : -1 }

    @ViewBuilder
    private func terminalPaneGroup() -> some View {
        let terminalResizeHandle = ResizeHandle(
            onDragStart: { terminalDragStart = panelSizeStore.terminalWidth },
            onDrag: { [panelSizeStore] translation in
                let newWidth = terminalDragStart + dragSign * translation
                panelSizeStore.updateTerminalWidth(newWidth, for: currentScreen)
                onWidthChange?(panelSizeStore.expandedWidth)
            },
            onEnd: {}
        )

        HStack(spacing: 0) {
            if edge == .right { terminalResizeHandle }

            VStack(spacing: 0) {
                TerminalPaneView(
                    session: store.activeSession,
                    groupName: store.activeSession.flatMap { session in
                        store.groups.first { $0.id == session.groupID }?.name
                    },
                    initialCommand: store.activeSession.flatMap { session in
                        store.groups.first { $0.id == session.groupID }?.initialCommand
                    },
                    onStatusChange: { id, status in
                        store.updateStatus(id, status: status)
                    },
                    onDirectoryChange: { id, dir in
                        store.updateDirectory(id, directory: dir)
                    },
                    onClose: {
                        onCloseTerminal?()
                    }
                )
                .frame(width: panelSizeStore.terminalWidth)
                .frame(maxHeight: .infinity)

                ResizeHandle(
                    axis: .vertical,
                    size: 6,
                    onDragStart: { terminalHeightDragStart = panelSizeStore.terminalPaneHeight },
                    onDrag: { [panelSizeStore] deltaY in
                        // In macOS coords: dragging down = negative deltaY = taller
                        let newHeight = terminalHeightDragStart - deltaY
                        panelSizeStore.updateTerminalPaneHeight(newHeight, for: currentScreen)
                    },
                    onEnd: {}
                )
                .frame(width: panelSizeStore.terminalWidth, height: 6)
            }

            if edge == .left { terminalResizeHandle }
        }
        .frame(height: panelSizeStore.terminalPaneHeight)
        .transition(.fadeFromBelow)
    }

    @ViewBuilder
    private func sessionListGroup() -> some View {
        let sessionResizeHandle = ResizeHandle(
            onDragStart: { sessionListDragStart = panelSizeStore.sessionListWidth },
            onDrag: { [panelSizeStore] translation in
                let newWidth = sessionListDragStart + dragSign * translation
                panelSizeStore.updateSessionListWidth(newWidth, for: currentScreen)
                let total: CGFloat = store.activeSessionID != nil
                    ? panelSizeStore.expandedWidth
                    : panelSizeStore.collapsedWidth
                onWidthChange?(total)
            },
            onEnd: {}
        )

        if edge == .right { sessionResizeHandle.padding(.trailing, 6) }

        SessionListView(
            store: store,
            width: panelSizeStore.sessionListWidth,
            onSelect: { id in
                onSessionSelected?()
                store.selectSession(id)
            },
            onNewSession: { groupID in
                onSessionSelected?()
                onNewSession(groupID)
            },
            onNewGroup: onNewGroup
        )

        if edge == .left { sessionResizeHandle.padding(.leading, 6) }
    }

    @ViewBuilder
    private func mainContent() -> some View {
        if edge == .right {
            if store.activeSessionID != nil {
                terminalPaneGroup()
            }
            Spacer(minLength: 0)
            sessionListGroup()
        } else {
            sessionListGroup()
            Spacer(minLength: 0)
            if store.activeSessionID != nil {
                terminalPaneGroup()
            }
        }
    }
}
