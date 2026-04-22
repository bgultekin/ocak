import Darwin
import Foundation

enum ProcessDetector {
    /// Testable pure function: BFS walk from root through children map, returns true if any descendant satisfies predicate.
    static func subtreeMatches(
        from root: pid_t,
        children: [pid_t: [pid_t]],
        predicate: (pid_t) -> Bool
    ) -> Bool {
        var queue: [pid_t] = children[root] ?? []
        var head = 0
        while head < queue.count {
            let pid = queue[head]; head += 1
            if predicate(pid) { return true }
            queue.append(contentsOf: children[pid] ?? [])
        }
        return false
    }

    /// Live batch scan: one sysctl(KERN_PROC_ALL) call, builds children map, walks tree for each shell PID.
    /// Returns [sessionID: detectedAITool] for all provided shell PIDs.
    /// Returns nil if no agent is detected, .claudeCode for claude, .opencode for opencode.
    static func agentRunning(shellPids: [pid_t: UUID]) -> [UUID: AITool?] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [:] }

        // Overallocate by 12.5% to handle race between two sysctl calls
        size += size / 8
        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [:] }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        var children: [pid_t: [pid_t]] = [:]
        for i in 0..<actualCount {
            let pid = procs[i].kp_proc.p_pid
            let ppid = procs[i].kp_eproc.e_ppid
            guard pid > 0 else { continue }
            children[ppid, default: []].append(pid)
        }

        var result: [UUID: AITool?] = [:]
        var pathBuf = [CChar](repeating: 0, count: 4096)
        for (shellPid, sessionID) in shellPids {
            result[sessionID] = firstAgentType(from: shellPid, children: children, pathBuf: &pathBuf)
        }
        return result
    }

    /// Single-pass BFS: returns the first matching AITool found in the subtree, or nil.
    private static func firstAgentType(from root: pid_t, children: [pid_t: [pid_t]], pathBuf: inout [CChar]) -> AITool? {
        var queue: [pid_t] = children[root] ?? []
        var head = 0
        while head < queue.count {
            let pid = queue[head]; head += 1
            let len = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
            if len > 0 {
                let path = String(cString: pathBuf)
                let exeName = (path as NSString).lastPathComponent
                if exeName == "claude" { return .claudeCode }
                if exeName == "opencode" { return .opencode }
            }
            queue.append(contentsOf: children[pid] ?? [])
        }
        return nil
    }
}
