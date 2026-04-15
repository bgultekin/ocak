import AppKit
import SwiftUI

/// An edge-anchored frosted glass panel backed by NSVisualEffectView.
final class DrawerPanel: NSPanel {
    private let ribbonWidth: CGFloat = 5
    private var clickOutsideMonitor: Any?
    private var localClickMonitor: Any?
    var onDismiss: (() -> Void)?

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
        bg.autoresizingMask = [.width, .height]
        contentView = bg
    }

    /// Host a SwiftUI view inside the clear backing.
    func setSwiftUIContent<V: View>(_ view: V) {
        guard let bg = contentView else { return }
        let hosting = NSHostingView(rootView: view)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = bg.bounds
        bg.subviews.forEach { $0.removeFromSuperview() }
        bg.addSubview(hosting)
    }

    // MARK: - Slide Animations

    func slideIn(on screen: NSScreen, width: CGFloat) {
        let visibleFrame = screen.visibleFrame
        let panelHeight = visibleFrame.height

        let targetOrigin = NSPoint(
            x: visibleFrame.maxX - width - ribbonWidth,
            y: visibleFrame.minY
        )

        setFrame(NSRect(origin: targetOrigin, size: NSSize(width: width, height: panelHeight)), display: false)

        guard let bg = contentView else { return }
        bg.wantsLayer = true
        bg.layer?.masksToBounds = false

        // Start translated to the right — content appears to come from off-screen
        bg.layer?.transform = CATransform3DMakeTranslation(width, 0, 0)

        orderFrontRegardless()

        let slide = CABasicAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DMakeTranslation(width, 0, 0)
        slide.toValue = CATransform3DIdentity
        slide.duration = 0.3
        slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false
        bg.layer?.add(slide, forKey: "slideIn")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            bg.layer?.transform = CATransform3DIdentity
            bg.layer?.removeAnimation(forKey: "slideIn")
            self.makeKey()
            self.orderFrontRegardless()
            self.installClickOutsideMonitor()
        }
    }

    func slideOut(completion: (() -> Void)? = nil) {
        removeClickOutsideMonitor()

        guard let bg = contentView else {
            orderOut(nil)
            completion?()
            return
        }
        bg.wantsLayer = true
        bg.layer?.masksToBounds = false

        let currentWidth = frame.width

        let slide = CABasicAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DIdentity
        slide.toValue = CATransform3DMakeTranslation(currentWidth, 0, 0)
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
        let newOriginX = visibleFrame.maxX - newWidth - ribbonWidth
        let newFrame = NSRect(
            x: newOriginX,
            y: frame.origin.y,
            width: newWidth,
            height: frame.height
        )
        setFrame(newFrame, display: true)
    }

    /// Expand or contract the panel width while keeping the right edge pinned.
    func animateToWidth(_ newWidth: CGFloat, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let newOriginX = visibleFrame.maxX - newWidth - ribbonWidth
        let newFrame = NSRect(
            x: newOriginX,
            y: frame.origin.y,
            width: newWidth,
            height: frame.height
        )
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
