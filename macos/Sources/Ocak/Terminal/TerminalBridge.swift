import SwiftUI
import AppKit
import SwiftTerm

/// Thin NSViewRepresentable that displays a persistent terminal from TerminalManager.
/// The terminal view is NOT recreated on session switch — it's retrieved from the manager.
struct TerminalSwiftUIView: NSViewRepresentable {
    let sessionID: UUID
    let workingDirectory: String
    let aiTool: AITool
    let initialCommand: String?
    var onStatusChange: ((SessionStatus) -> Void)?
    var onDirectoryChange: ((String) -> Void)?

    func makeNSView(context: Context) -> NSView {
        // Container that holds the terminal view
        let container = NSView(frame: .zero)
        let termView = TerminalManager.shared.terminal(
            for: sessionID,
            workingDirectory: workingDirectory,
            aiTool: aiTool,
            initialCommand: initialCommand,
            onStatusChange: onStatusChange,
            onDirectoryChange: onDirectoryChange
        )

        // Remove from previous superview if re-parented
        termView.removeFromSuperview()
        termView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(termView)
        NSLayoutConstraint.activate([
            termView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            termView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            termView.topAnchor.constraint(equalTo: container.topAnchor),
            termView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Make terminal first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            termView.window?.makeFirstResponder(termView)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update callbacks on the delegate
        let termView = TerminalManager.shared.terminal(
            for: sessionID,
            workingDirectory: workingDirectory,
            aiTool: aiTool,
            initialCommand: initialCommand,
            onStatusChange: onStatusChange,
            onDirectoryChange: onDirectoryChange
        )

        // Ensure the terminal is in this container (handles session switch)
        if termView.superview !== nsView {
            // Remove all existing subviews
            nsView.subviews.forEach { $0.removeFromSuperview() }

            termView.removeFromSuperview()
            termView.translatesAutoresizingMaskIntoConstraints = false
            nsView.addSubview(termView)
            NSLayoutConstraint.activate([
                termView.leadingAnchor.constraint(equalTo: nsView.leadingAnchor),
                termView.trailingAnchor.constraint(equalTo: nsView.trailingAnchor),
                termView.topAnchor.constraint(equalTo: nsView.topAnchor),
                termView.bottomAnchor.constraint(equalTo: nsView.bottomAnchor),
            ])
        }

        // Schedule focus with a delay — ensures button tap is fully processed first.
        // Skip if a text field is already focused (e.g., session rename input).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let window = termView.window else { return }
            // NSTextField uses a shared NSTextView (field editor) as the real first responder
            if window.firstResponder is NSTextField || window.firstResponder is NSTextView { return }
            window.makeFirstResponder(termView)
        }
    }
}
