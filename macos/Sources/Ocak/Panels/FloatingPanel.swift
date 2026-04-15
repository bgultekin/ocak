import AppKit
import SwiftUI

/// A non-activating panel that floats above all windows and across all Spaces.
/// Used for the ribbon and any other always-visible overlays.
final class FloatingPanel<Content: View>: NSPanel {
    init(contentView: Content, contentSize: NSSize = NSSize(width: 52, height: 52)) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        configure()
        self.contentView = NSHostingView(rootView: contentView)
    }

    private func configure() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = true
    }
}
