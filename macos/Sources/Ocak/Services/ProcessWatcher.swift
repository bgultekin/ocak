import Foundation
import Darwin

/// Polls the process table every 2 seconds and updates each session's isAgentRunning flag.
/// Owns a repeating Timer on the main run loop — the intentional exception to the no-polling rule,
/// since no AI agent hook exists for shell/agent process transitions (D-08).
final class ProcessWatcher {
    private weak var store: SessionStore?
    private var timer: Timer?

    init(store: SessionStore) {
        self.store = store
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let store else { return }

        // Collect shell PIDs from live terminals (via TerminalManager.shellPid accessor from Plan 01)
        var shellPids: [pid_t: UUID] = [:]
        for session in store.sessions {
            if let pid = TerminalManager.shared.shellPid(for: session.id) {
                shellPids[pid] = session.id
            }
        }

        guard !shellPids.isEmpty else { return }

        // Single sysctl batch scan for all sessions (per research Pattern 1)
        let results = ProcessDetector.agentRunning(shellPids: shellPids)

        // Update store on main thread (already on main since Timer fires on main run loop)
        for (sessionID, detectedAgent) in results {
            store.updateDetectedAgent(sessionID, detectedAgent: detectedAgent)
        }
    }
}
