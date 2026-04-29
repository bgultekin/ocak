import AppKit
import SwiftUI

/// NSHostingView subclass that forces a redraw on every layout pass. This works around a
/// SwiftUI-in-transparent-NSPanel bug where shrinking subviews leave stale pixels behind
/// (visible as ghost rectangles) until the next user interaction invalidates the window.
///
/// Trade-off: `layout()` fires during most SwiftUI animations (collapse, drag hover,
/// scroll, resize), so we accept a small overdraw cost everywhere in exchange for a
/// single correctness fix. `needsDisplay = true` just flags the view dirty for the next
/// display cycle — SwiftUI already owns the actual drawing — so the real cost is the
/// window compositing pass, which is cheap for a single drawer-sized region.
final class RedrawingHostingView<V: View>: NSHostingView<V> {
    override func layout() {
        super.layout()
        needsDisplay = true
        window?.invalidateShadow()
    }
}

/// An edge-anchored frosted glass panel backed by NSVisualEffectView.
final class DrawerPanel: NSPanel {
    private let ribbonWidth: CGFloat = 5
    private var clickOutsideMonitor: Any?
    private var localClickMonitor: Any?
    var onDismiss: (() -> Void)?
    private var edge: PanelEdge = .right
    private var isBeingDismissed = false

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 250, height: 600)),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        configure()
        setupClearBackingView()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private func configure() {
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .utilityWindow
        acceptsMouseMovedEvents = true
    }

    private func setupClearBackingView() {
        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.clear.cgColor
        bg.layerContentsRedrawPolicy = .duringViewResize
        bg.autoresizingMask = [.width, .height]
        contentView = bg
    }

    /// Host a SwiftUI view inside the clear backing.
    func setSwiftUIContent<V: View>(_ view: V) {
        guard let bg = contentView else { return }
        let hosting = RedrawingHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layerContentsRedrawPolicy = .duringViewResize
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = bg.bounds
        bg.subviews.forEach { $0.removeFromSuperview() }
        bg.addSubview(hosting)
    }

    // MARK: - Slide Animations

    func slideIn(on screen: NSScreen, width: CGFloat, edge: PanelEdge, completion: (() -> Void)? = nil) {
        isBeingDismissed = false
        self.edge = edge
        let visibleFrame = screen.visibleFrame
        let panelHeight = visibleFrame.height

        let targetOriginX: CGFloat
        let slideOffset: CGFloat
        switch edge {
        case .right:
            targetOriginX = visibleFrame.maxX - width - ribbonWidth
            slideOffset = width
        case .left:
            targetOriginX = visibleFrame.minX + ribbonWidth
            slideOffset = -width
        }

        let targetOrigin = NSPoint(x: targetOriginX, y: visibleFrame.minY)
        setFrame(NSRect(origin: targetOrigin, size: NSSize(width: width, height: panelHeight)), display: false)

        guard let bg = contentView else { return }
        bg.wantsLayer = true
        bg.layer?.masksToBounds = false

        bg.layer?.transform = CATransform3DMakeTranslation(slideOffset, 0, 0)

        orderFrontRegardless()

        let slide = CABasicAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DMakeTranslation(slideOffset, 0, 0)
        slide.toValue = CATransform3DIdentity
        slide.duration = 0.3
        slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false
        bg.layer?.add(slide, forKey: "slideIn")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !self.isBeingDismissed else { return }
            bg.layer?.transform = CATransform3DIdentity
            bg.layer?.removeAnimation(forKey: "slideIn")
            self.makeKey()
            self.orderFrontRegardless()
            self.installClickOutsideMonitor()
            completion?()
        }
    }

    func slideOut(completion: (() -> Void)? = nil) {
        isBeingDismissed = true
        removeClickOutsideMonitor()

        guard let bg = contentView else {
            orderOut(nil)
            completion?()
            return
        }
        bg.wantsLayer = true
        bg.layer?.masksToBounds = false

        let currentWidth = frame.width

        let slideOffset: CGFloat = edge == .right ? currentWidth : -currentWidth
        let slide = CABasicAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DIdentity
        slide.toValue = CATransform3DMakeTranslation(slideOffset, 0, 0)
        slide.duration = 0.5
        slide.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.085, 0.68, 0.53)
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false
        bg.layer?.add(slide, forKey: "slideOut")

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            animator().alphaValue = 0
        }, completionHandler: {
            bg.layer?.removeAnimation(forKey: "slideOut")
            self.orderOut(nil)
            completion?()
        })
    }

    /// Resize immediately without animation (for live drag resizing).
    func setWidth(_ newWidth: CGFloat, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let newOriginX: CGFloat
        switch edge {
        case .right: newOriginX = visibleFrame.maxX - newWidth - ribbonWidth
        case .left:  newOriginX = visibleFrame.minX + ribbonWidth
        }
        let newFrame = NSRect(x: newOriginX, y: frame.origin.y, width: newWidth, height: frame.height)
        setFrame(newFrame, display: true)
    }

    /// Expand or contract the panel width while keeping the configured edge pinned.
    func animateToWidth(_ newWidth: CGFloat, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let newOriginX: CGFloat
        switch edge {
        case .right: newOriginX = visibleFrame.maxX - newWidth - ribbonWidth
        case .left:  newOriginX = visibleFrame.minX + ribbonWidth
        }
        let newFrame = NSRect(x: newOriginX, y: frame.origin.y, width: newWidth, height: frame.height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Click Outside Dismissal

    private func installClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return }
            if NSApp.modalWindow != nil { return }
            if NSApp.windows.contains(where: { $0 is NSOpenPanel && $0.isVisible }) { return }
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.contains(mouseLocation) {
                self.onDismiss?()
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            if event.window === self { return event }
            if NSApp.modalWindow != nil { return event }
            if NSApp.windows.contains(where: { $0 is NSOpenPanel && $0.isVisible }) { return event }
            let mouseLocation = NSEvent.mouseLocation
            if !self.frame.contains(mouseLocation) {
                self.onDismiss?()
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }

    deinit {
        removeClickOutsideMonitor()
    }
}
