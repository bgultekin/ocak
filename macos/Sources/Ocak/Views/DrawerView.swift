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

    @ViewBuilder
    private func mainContent() -> some View {
        if store.activeSessionID != nil {
            HStack(spacing: 0) {
                ResizeHandle(
                    onDragStart: { terminalDragStart = panelSizeStore.terminalWidth },
                    onDrag: { [panelSizeStore] translation in
                        let newWidth = terminalDragStart - translation
                        panelSizeStore.updateTerminalWidth(newWidth, for: currentScreen)
                        onWidthChange?(panelSizeStore.expandedWidth)
                    },
                    onEnd: {}
                )

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
            }
            .frame(height: panelSizeStore.terminalPaneHeight)
            .transition(.fadeFromBelow)
        }

        Spacer(minLength: 0)

        // Resize handle at left edge of session list
        ResizeHandle(
            onDragStart: { sessionListDragStart = panelSizeStore.sessionListWidth },
            onDrag: { [panelSizeStore] translation in
                let newWidth = sessionListDragStart - translation
                panelSizeStore.updateSessionListWidth(newWidth, for: currentScreen)
                let total: CGFloat = store.activeSessionID != nil
                    ? panelSizeStore.expandedWidth
                    : panelSizeStore.collapsedWidth
                onWidthChange?(total)
            },
            onEnd: {}
        )
        .padding(.trailing, 6)

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
    }
}
