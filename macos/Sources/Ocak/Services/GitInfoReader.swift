import Foundation

struct GitInfo {
    let branch: String?
    let isWorktree: Bool

    var displayText: String {
        guard let branch = branch else { return "" }
        if isWorktree {
            return "\(branch) (worktree)"
        }
        return branch
    }

    static func read(from directory: String) -> GitInfo {
        let fm = FileManager.default
        let gitPath = (directory as NSString).appendingPathComponent(".git")

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: gitPath, isDirectory: &isDirectory) else {
            return GitInfo(branch: nil, isWorktree: false)
        }

        let isWorktree = !isDirectory.boolValue

        let headPath: String
        if isWorktree {
            // .git is a file containing "gitdir: <path>"
            guard let content = try? String(contentsOfFile: gitPath, encoding: .utf8),
                  let gitdirLine = content.components(separatedBy: "\n").first,
                  gitdirLine.hasPrefix("gitdir: ") else {
                return GitInfo(branch: nil, isWorktree: true)
            }
            let gitdir = String(gitdirLine.dropFirst("gitdir: ".count)).trimmingCharacters(in: .whitespaces)
            let resolvedGitdir: String
            if gitdir.hasPrefix("/") {
                resolvedGitdir = gitdir
            } else {
                resolvedGitdir = (directory as NSString).appendingPathComponent(gitdir)
            }
            headPath = (resolvedGitdir as NSString).appendingPathComponent("HEAD")
        } else {
            headPath = (gitPath as NSString).appendingPathComponent("HEAD")
        }

        guard let headContent = try? String(contentsOfFile: headPath, encoding: .utf8) else {
            return GitInfo(branch: nil, isWorktree: isWorktree)
        }

        let trimmed = headContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let refPrefix = "ref: refs/heads/"
        if trimmed.hasPrefix(refPrefix) {
            let branch = String(trimmed.dropFirst(refPrefix.count))
            return GitInfo(branch: branch, isWorktree: isWorktree)
        }

        // Detached HEAD — show short SHA
        let shortSHA = String(trimmed.prefix(7))
        return GitInfo(branch: shortSHA, isWorktree: isWorktree)
    }
}
