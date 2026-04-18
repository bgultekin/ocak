import AppKit
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.o, modifiers: [.command, .control]))
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static var _retained: AppDelegate?

    private var ribbonPanels: [NSPanel] = []
    private var drawerPanel: DrawerPanel?
    private let store = SessionStore()
    private var hookServer: HookServer?

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var dwellTimer: DispatchSourceTimer?
    private var isInHoverZone = false
    private var hoverScreen: NSScreen?

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var settingsModel: SettingsViewModel?
    private var processWatcher: ProcessWatcher?
    
    private let screenConfig = ScreenConfigStore.shared
    private var screenForDrawer: NSScreen?
    private let panelSizeStore = PanelSizeStore.shared

    private static let smokeRibbonWidthFactor: CGFloat = 0.06

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate._retained = self
        NSApp.setActivationPolicy(.accessory)
        ShellHookWriter.cleanupStale()
        store.restore()
        TerminalHistoryLogger.cleanupStale(validSessionIDs: store.allSessionIDs)
        startHookServer()
        setupRibbon()
        setupEdgeDetection()
        setupStatusItem()
        setupProcessWatcher()

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.toggleDrawer()
        }

        setupAppearanceObserver()
    }

    private func setupAppearanceObserver() {
        AppearanceConfigStore.shared.onChange = {
            DispatchQueue.main.async {
                TerminalManager.shared.updateAllTerminalsAppearance()
                self.updateSettingsWindowAppearance()
                if let panel = self.drawerPanel, panel.isVisible {
                    let currentWidth = panel.frame.width
                    panel.slideOut { [weak self] in
                        self?.drawerPanel = nil
                        self?.showDrawer()
                        if let screen = self?.screenForDrawer, let panel = self?.drawerPanel {
                            panel.setWidth(currentWidth, on: screen)
                        }
                    }
                }
            }
        }
        TerminalThemeConfigStore.shared.onChange = {
            DispatchQueue.main.async {
                TerminalManager.shared.updateAllTerminalsAppearance()
            }
        }
    }

    private func resolvedAppearance() -> NSAppearance {
        AppearanceConfigStore.shared.effectiveMode == .dark
            ? NSAppearance(named: .darkAqua)!
            : NSAppearance(named: .aqua)!
    }

    private func updateSettingsWindowAppearance() {
        guard let window = settingsWindow else { return }
        window.appearance = resolvedAppearance()
    }

    func applicationWillTerminate(_ notification: Notification) {
        processWatcher?.stop()
        hookServer?.stop()
        TerminalManager.shared.flushAllHistoryLogs()
        store.save()
        screenForDrawer.flatMap { panelSizeStore.save(for: $0) }
        removeEdgeMonitors()
    }

    // MARK: - Hook Server

    private func startHookServer() {
        let server = HookServer()
        server.onEvent = { [weak self] event in
            self?.store.processHookEvent(event)
        }
        do {
            try server.start()
            hookServer = server
        } catch {
            print("[Ocak] Hook server failed to start: \(error)")
        }
    }

    // MARK: - Ribbon (replaces old circular anchor)

    private func setupRibbon() {
        screenConfig.onChange = { [weak self] in
            DispatchQueue.main.async { self?.rebuildRibbons() }
        }
        RibbonConfigStore.shared.onChange = { [weak self] in
            DispatchQueue.main.async { self?.rebuildRibbons() }
        }
        rebuildRibbons()
    }

    private func rebuildRibbons() {
        for panel in ribbonPanels { panel.close() }
        ribbonPanels.removeAll()

        let screens = screenConfig.activeScreens
        for screen in screens {
            let visibleFrame = screen.visibleFrame
            let ribbonHeight = visibleFrame.height * 0.4

            let style = RibbonConfigStore.shared.ribbonStyle
            guard style == .solid || style == .smoke else { continue }

            let ribbonWidth: CGFloat = style == .smoke ? ribbonHeight * Self.smokeRibbonWidthFactor : 5

            let panel: NSPanel
            switch style {
            case .solid:
                panel = FloatingPanel(
                    contentView: RibbonView(store: store),
                    contentSize: NSSize(width: ribbonWidth, height: ribbonHeight)
                )
            case .smoke:
                panel = FloatingPanel(
                    contentView: SmokeRibbonView(store: store),
                    contentSize: NSSize(width: ribbonWidth, height: ribbonHeight)
                )
            default:
                continue
            }

            let panelEdge = screenConfig.panelEdge(for: screen)
            let ribbonOriginX: CGFloat = panelEdge == .right
                ? visibleFrame.maxX - ribbonWidth
                : visibleFrame.minX
            let origin = NSPoint(x: ribbonOriginX, y: visibleFrame.midY - ribbonHeight / 2)
            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
            ribbonPanels.append(panel)
        }
    }

    // MARK: - Edge Detection (hover zone + dwell timer)

    private func setupEdgeDetection() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    private func handleMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = findScreenForMouse(mouseLocation) else { return }
        let visibleFrame = screen.visibleFrame
        let ribbonHeight = visibleFrame.height * 0.4
        let ribbonTop = visibleFrame.midY - ribbonHeight / 2
        let ribbonBottom = visibleFrame.midY + ribbonHeight / 2

        let style = RibbonConfigStore.shared.ribbonStyle
        let hoverWidth: CGFloat = style == .smoke ? max(ribbonHeight * Self.smokeRibbonWidthFactor, 25) : 25
        let panelEdge = screenConfig.panelEdge(for: screen)
        let inHorizontalZone: Bool
        switch panelEdge {
        case .right: inHorizontalZone = mouseLocation.x > visibleFrame.maxX - hoverWidth
        case .left:  inHorizontalZone = mouseLocation.x < visibleFrame.minX + hoverWidth
        }
        let inVerticalZone = mouseLocation.y >= ribbonTop && mouseLocation.y <= ribbonBottom
        let inZone = inHorizontalZone && inVerticalZone

        if inZone && !isInHoverZone {
            isInHoverZone = true
            hoverScreen = screen
            if style != .none,
               drawerPanel == nil || !drawerPanel!.isVisible {
                startDwellTimer()
            }
        } else if !inZone && isInHoverZone {
            isInHoverZone = false
            hoverScreen = nil
            cancelDwellTimer()
        }
    }

    /// Find the screen that contains the mouse location and is in the active screen config.
    /// Falls back to the primary active screen if no match.
    private func findScreenForMouse(_ location: NSPoint) -> NSScreen? {
        let activeScreens = screenConfig.activeScreens
        let matching = activeScreens.first { NSPointInRect(location, $0.frame) }
        return matching ?? activeScreens.first
    }

    private func startDwellTimer() {
        cancelDwellTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(300))
        timer.setEventHandler { [weak self] in
            self?.showDrawer()
        }
        timer.resume()
        dwellTimer = timer
    }

    private func cancelDwellTimer() {
        dwellTimer?.cancel()
        dwellTimer = nil
    }

    private func removeEdgeMonitors() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        cancelDwellTimer()
    }

    // MARK: - Drawer Panel

    private func toggleDrawer() {
        if store.isPanelVisible, let panel = drawerPanel, panel.isVisible {
            dismissDrawer()
        } else {
            showDrawer()
        }
    }

    private func screenForCurrentMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return screenConfig.activeScreens.first { NSPointInRect(location, $0.frame) }
    }

    private func showDrawer() {
        guard let screen = hoverScreen ?? screenForCurrentMouse() ?? screenConfig.primaryActiveScreen else { return }
        if store.isPanelVisible, drawerPanel?.isVisible == true { return }

        screenForDrawer = screen
        panelSizeStore.load(for: screen)

        let panel = DrawerPanel()
        let width = store.activeSessionID != nil ? panelSizeStore.expandedWidth : panelSizeStore.collapsedWidth
        let panelEdge = screenConfig.panelEdge(for: screen)

        let drawerView = DrawerView(
            store: store,
            panelSizeStore: panelSizeStore,
            currentScreen: screen,
            edge: panelEdge,
            onWidthChange: { [weak self] newWidth in
                guard let self, let screen = self.screenForDrawer, let panel = self.drawerPanel else { return }
                panel.setWidth(newWidth, on: screen)
            },
            onNewSession: { [weak self] groupID in
                self?.store.addQuickSession(in: groupID)
            },
            onNewGroup: { [weak self] in
                self?.store.addGroup()
            },
            onSessionSelected: { [weak self] in
                self?.expandDrawerIfNeeded()
            },
            onCloseTerminal: { [weak self] in
                guard let self else { return }
                self.store.activeSessionID = nil
                // Delay the panel collapse until the SwiftUI fade-out has played,
                // otherwise the panel shrinking dominates and looks like a slide.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self,
                          let screen = self.screenForDrawer,
                          let panel = self.drawerPanel else { return }
                    panel.setWidth(self.panelSizeStore.collapsedWidth, on: screen)
                }
            }
        )
        panel.appearance = resolvedAppearance()
        panel.setSwiftUIContent(drawerView)

        panel.onDismiss = { [weak self] in
            self?.dismissDrawer()
        }

        drawerPanel = panel
        store.isPanelVisible = true
        panel.slideIn(on: screen, width: width, edge: panelEdge)
    }

    private func dismissDrawer() {
        store.isPanelVisible = false
        drawerPanel?.slideOut { [weak self] in
            self?.drawerPanel = nil
            self?.store.clearSessionStatuses()
        }
    }

    private func expandDrawerIfNeeded() {
        guard let screen = screenForDrawer ?? screenConfig.primaryActiveScreen, let panel = drawerPanel else { return }
        if panel.frame.width < panelSizeStore.expandedWidth {
            panel.setWidth(panelSizeStore.expandedWidth, on: screen)
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon()
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings\u{2026}",
                                       action: #selector(openSettings),
                                       keyEquivalent: "")
        settingsItem.target = self
        let quitItem = NSMenuItem(title: "Quit Ocak",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu

        observeAttention()
    }

    private func observeAttention() {
        withObservationTracking {
            _ = store.hasAttention
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusIcon()
                self?.observeAttention()
            }
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let resourceName = store.hasAttention ? "ocak-menubar-icon-active" : "ocak-menubar-icon-default"
        if let url = Bundle.module.url(forResource: resourceName, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 18)
            img.isTemplate = !store.hasAttention
            button.image = img
        }
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        if settingsWindow != nil {
            hideSettings()
            return
        }
        showSettings()
    }

    private func showSettings() {
        let model = SettingsViewModel()
        let hostingView = NSHostingView(rootView: SettingsView(model: model))
        let fittingSize = hostingView.fittingSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: fittingSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ocak Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.appearance = resolvedAppearance()

        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
        settingsModel = model
    }

    private func hideSettings() {
        settingsWindow?.close()
        settingsWindow = nil
        settingsModel = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow = nil
        settingsModel = nil
    }

    // MARK: - Process Watcher

    private func setupProcessWatcher() {
        let watcher = ProcessWatcher(store: store)
        watcher.start()
        processWatcher = watcher
    }
}
