import SwiftUI

enum ResizeAxis {
    case horizontal
    case vertical
}

/// Narrow strip that shows a resize cursor and tracks drag gestures.
/// Fully AppKit-backed for reliable cursor handling.
struct ResizeHandle: NSViewRepresentable {
    let axis: ResizeAxis
    let size: CGFloat
    let onDragStart: () -> Void
    let onDrag: (CGFloat) -> Void
    let onEnd: () -> Void

    init(axis: ResizeAxis = .horizontal, size: CGFloat = 6, onDragStart: @escaping () -> Void, onDrag: @escaping (CGFloat) -> Void, onEnd: @escaping () -> Void) {
        self.axis = axis
        self.size = size
        self.onDragStart = onDragStart
        self.onDrag = onDrag
        self.onEnd = onEnd
    }

    /// Convenience for horizontal handles (original API).
    init(width: CGFloat = 6, onDragStart: @escaping () -> Void, onDrag: @escaping (CGFloat) -> Void, onEnd: @escaping () -> Void) {
        self.axis = .horizontal
        self.size = width
        self.onDragStart = onDragStart
        self.onDrag = onDrag
        self.onEnd = onEnd
    }

    func makeNSView(context: Context) -> HandleView {
        HandleView(
            axis: axis,
            size: size,
            onDragStart: onDragStart,
            onDrag: onDrag,
            onEnd: onEnd
        )
    }

    func updateNSView(_ nsView: HandleView, context: Context) {}

    class HandleView: NSView {
        let axis: ResizeAxis
        let size: CGFloat
        let onDragStart: () -> Void
        let onDrag: (CGFloat) -> Void
        let onEnd: () -> Void

        private var dragStartPosition: CGFloat = 0
        private var monitor: Any?
        private var trackingArea: NSTrackingArea?
        private var isHovering = false
        private var isDragging = false

        init(axis: ResizeAxis, size: CGFloat, onDragStart: @escaping () -> Void, onDrag: @escaping (CGFloat) -> Void, onEnd: @escaping () -> Void) {
            self.axis = axis
            self.size = size
            self.onDragStart = onDragStart
            self.onDrag = onDrag
            self.onEnd = onEnd
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: NSSize {
            switch axis {
            case .horizontal:
                return NSSize(width: size, height: NSView.noIntrinsicMetric)
            case .vertical:
                return NSSize(width: NSView.noIntrinsicMetric, height: size)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.acceptsMouseMovedEvents = true
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
            let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
        }

        override func resetCursorRects() {
            let cursor: NSCursor = axis == .horizontal ? .resizeLeftRight : .resizeUpDown
            addCursorRect(bounds, cursor: cursor)
        }

        override func mouseEntered(with event: NSEvent) {
            isHovering = true
            updateAppearance()
        }

        override func mouseExited(with event: NSEvent) {
            isHovering = false
            updateAppearance()
        }

        override func mouseDown(with event: NSEvent) {
            isDragging = true
            let loc = NSEvent.mouseLocation
            dragStartPosition = axis == .horizontal ? loc.x : loc.y
            onDragStart()
            startGlobalTracking()
        }

        private func startGlobalTracking() {
            let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
            monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event -> NSEvent? in
                guard let self, isDragging else { return event }
                switch event.type {
                case .leftMouseDragged:
                    let loc = NSEvent.mouseLocation
                    let current = axis == .horizontal ? loc.x : loc.y
                    let delta = current - dragStartPosition
                    onDrag(delta)
                    return nil
                case .leftMouseUp:
                    stopTracking()
                    return nil
                default:
                    return event
                }
            }
        }

        private func stopTracking() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            isDragging = false
            isHovering = false
            updateAppearance()
            onEnd()
        }

        private func updateAppearance() {
            layer?.backgroundColor = (isHovering || isDragging)
                ? NSColor.white.withAlphaComponent(0.08).cgColor
                : NSColor.clear.cgColor
        }

        override func makeBackingLayer() -> CALayer {
            let layer = CALayer()
            layer.backgroundColor = NSColor.clear.cgColor
            return layer
        }
    }
}
