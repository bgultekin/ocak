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
        var comms: [pid_t: String] = [:]
        for i in 0..<actualCount {
            let pid = procs[i].kp_proc.p_pid
            let ppid = procs[i].kp_eproc.e_ppid
            guard pid > 0 else { continue }
            children[ppid, default: []].append(pid)
            comms[pid] = readComm(from: procs[i])
        }

        var result: [UUID: AITool?] = [:]
        var pathBuf = [CChar](repeating: 0, count: 4096)
        for (shellPid, sessionID) in shellPids {
            result[sessionID] = firstAgentType(
                from: shellPid, children: children, comms: comms, pathBuf: &pathBuf
            )
        }
        return result
    }

    /// Single-pass BFS: returns the first matching AITool found in the subtree, or nil.
    private static func firstAgentType(
        from root: pid_t,
        children: [pid_t: [pid_t]],
        comms: [pid_t: String],
        pathBuf: inout [CChar]
    ) -> AITool? {
        var queue: [pid_t] = children[root] ?? []
        var head = 0
        while head < queue.count {
            let pid = queue[head]; head += 1
            if let tool = detectTool(pid: pid, comm: comms[pid], pathBuf: &pathBuf) {
                return tool
            }
            queue.append(contentsOf: children[pid] ?? [])
        }
        return nil
    }

    /// Multi-signal detection for a single PID. Returns the first matching AITool, or nil.
    /// Covers native binaries, shell wrappers (via argv[0]) and Node/Python-wrapped CLIs
    /// whose proc_pidpath resolves to the interpreter (via argv[1] script path).
    private static func detectTool(pid: pid_t, comm: String?, pathBuf: inout [CChar]) -> AITool? {
        // 1. Kernel-visible process name (p_comm, 16-char cap). Node CLIs commonly set
        //    process.title which updates this, so `claude` often shows up even when the
        //    executable is node.
        if let comm {
            if comm == "claude" { return .claudeCode }
            if comm == "opencode" { return .opencode }
        }

        // 2. Executable path's basename (native binaries, e.g. /opt/homebrew/bin/claude).
        var exeName = ""
        let len = proc_pidpath(pid, &pathBuf, UInt32(pathBuf.count))
        if len > 0 {
            exeName = ((String(cString: pathBuf)) as NSString).lastPathComponent
            if exeName == "claude" { return .claudeCode }
            if exeName == "opencode" { return .opencode }
        }

        // 3. Fall back to argv via KERN_PROCARGS2 — catches:
        //    - shell-wrapper scripts where argv[0] is the claude path but exe is /bin/bash
        //    - interpreter invocations like `node /usr/local/bin/claude` where the script
        //      path is in argv[1].
        if let args = readProcessArgs(pid: pid), !args.isEmpty {
            let argv0 = (args[0] as NSString).lastPathComponent
            if argv0 == "claude" { return .claudeCode }
            if argv0 == "opencode" { return .opencode }

            if args.count > 1, isScriptInterpreter(argv0) || isScriptInterpreter(exeName) {
                let argv1 = (args[1] as NSString).lastPathComponent
                // Handle .js / .mjs extensions some npm CLIs ship (e.g. "claude.js")
                let stem = (argv1 as NSString).deletingPathExtension
                if argv1 == "claude" || stem == "claude" { return .claudeCode }
                if argv1 == "opencode" || stem == "opencode" { return .opencode }
            }
        }

        return nil
    }

    private static func isScriptInterpreter(_ name: String) -> Bool {
        switch name {
        case "node", "deno", "bun",
             "python", "python3", "python2",
             "ruby", "bash", "zsh", "sh":
            return true
        default:
            return false
        }
    }

    /// Read the 16-char kernel process name (p_comm) from a kinfo_proc.
    private static func readComm(from proc: kinfo_proc) -> String {
        var commTuple = proc.kp_proc.p_comm
        let capacity = MemoryLayout.size(ofValue: commTuple)
        return withUnsafePointer(to: &commTuple) { tuplePtr -> String in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) {
                String(cString: $0)
            }
        }
    }

    /// Read the argv vector of a process via sysctl(KERN_PROCARGS2).
    /// Format: [argc: Int32][exe_path\0][null padding][argv[0]\0][argv[1]\0]...[env...]
    private static func readProcessArgs(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else {
            return nil
        }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }

        let argc: Int32 = buffer.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        }
        guard argc > 0 else { return nil }

        var i = MemoryLayout<Int32>.size
        while i < size && buffer[i] != 0 { i += 1 }        // skip exe path
        while i < size && buffer[i] == 0 { i += 1 }        // skip null padding

        var args: [String] = []
        args.reserveCapacity(Int(argc))
        while args.count < Int(argc) && i < size {
            let start = i
            while i < size && buffer[i] != 0 { i += 1 }
            if i > start {
                var bytes = Array(buffer[start..<i])
                bytes.append(0)
                args.append(String(cString: bytes))
            }
            i += 1                                          // skip separating null
        }
        return args.isEmpty ? nil : args
    }
}
