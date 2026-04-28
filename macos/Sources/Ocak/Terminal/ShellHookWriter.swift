import Foundation

/// Creates per-session shell startup files that inject Ocak hooks (OSC 7 CWD tracking,
/// kitty keyboard reset) via ZDOTDIR (zsh) or --rcfile (bash) instead of post-launch injection.
enum ShellHookWriter {

    private static let tempBase = NSTemporaryDirectory()

    // MARK: - Zsh (ZDOTDIR)

    /// Creates a temp ZDOTDIR with wrapper startup files that source the user's real dotfiles
    /// and append Ocak hooks. Returns the temp directory path to set as ZDOTDIR.
    static func prepareZsh(sessionID: UUID, originalZDOTDIR: String?) -> String {
        let dir = (tempBase as NSString).appendingPathComponent("ocak_zdotdir_\(sessionID.uuidString)")
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        let real = #"${ZDOTDIR_ORIGINAL:-$HOME}"#

        // .zshenv — source user's real .zshenv
        write(to: dir + "/.zshenv", contents: """
        _ocak_real="\(real)"
        [[ -f "$_ocak_real/.zshenv" ]] && source "$_ocak_real/.zshenv"
        unset _ocak_real
        """)

        // .zprofile — source user's real .zprofile
        write(to: dir + "/.zprofile", contents: """
        _ocak_real="\(real)"
        [[ -f "$_ocak_real/.zprofile" ]] && source "$_ocak_real/.zprofile"
        unset _ocak_real
        """)

        // .zshrc — source user's real .zshrc, restore ZDOTDIR, add Ocak hooks
        ensureHistoryDirectory()
        let historyPath = historyBaseDirectory.appendingPathComponent("\(sessionID.uuidString).hist").path
        write(to: dir + "/.zshrc", contents: """
        _ocak_real="\(real)"
        [[ -f "$_ocak_real/.zshrc" ]] && source "$_ocak_real/.zshrc"
        unset _ocak_real

        # Restore ZDOTDIR for child processes
        export ZDOTDIR="\(real)"

        # Per-session history file (set by Ocak)
        export HISTFILE="\(historyPath)"
        export HISTSIZE=10000
        export SAVEHIST=10000

        # --- Ocak terminal hooks ---
        autoload -Uz add-zsh-hook
        __ocak_osc7() { printf '\\e]7;file://%s%s\\a' "$HOST" "$PWD" }
        add-zsh-hook chpwd __ocak_osc7
        __ocak_osc7
        __ocak_term_reset() { printf '\\033[=0u\\033[?1000l\\033[?1002l\\033[?1003l\\033[?1006l' }
        add-zsh-hook precmd __ocak_term_reset

        # --- Ocak shell command status tracking ---
        zmodload zsh/datetime 2>/dev/null
        __ocak_status_threshold=2
        __ocak_post_status() {
            [[ -z $OCAK_SESSION_ID ]] && return
            curl -sf -X POST http://localhost:${OCAK_HOOK_PORT:-27832}/hook \\
                -H "Content-Type: application/json" \\
                -H "X-Ocak-Session: $OCAK_SESSION_ID" \\
                -d "{\\"hook_event_name\\":\\"$1\\"}" \\
                >/dev/null 2>&1
        }
        __ocak_cmd_preexec() {
            __ocak_cmd_start=$EPOCHSECONDS
            ( sleep $__ocak_status_threshold && __ocak_post_status ShellCommandStart ) &!
            __ocak_cmd_pending=$!
        }
        __ocak_cmd_precmd() {
            [[ -z $__ocak_cmd_start ]] && return
            local duration=$(( EPOCHSECONDS - __ocak_cmd_start ))
            if (( duration >= __ocak_status_threshold )); then
                __ocak_post_status ShellCommandEnd &!
            elif [[ -n $__ocak_cmd_pending ]]; then
                kill $__ocak_cmd_pending 2>/dev/null
            fi
            unset __ocak_cmd_start __ocak_cmd_pending
        }
        add-zsh-hook preexec __ocak_cmd_preexec
        add-zsh-hook precmd __ocak_cmd_precmd
        """)

        // .zlogin — source user's real .zlogin
        write(to: dir + "/.zlogin", contents: """
        _ocak_real="\(real)"
        [[ -f "$_ocak_real/.zlogin" ]] && source "$_ocak_real/.zlogin"
        unset _ocak_real
        """)

        return dir
    }

    // MARK: - Bash (--rcfile)

    /// Creates a temp rcfile that sources login profiles + ~/.bashrc, then appends Ocak hooks.
    /// Returns the file path to pass as --rcfile argument.
    static func prepareBash(sessionID: UUID) -> String {
        let path = (tempBase as NSString).appendingPathComponent("ocak_bashrc_\(sessionID.uuidString)")
        ensureHistoryDirectory()
        let historyPath = historyBaseDirectory.appendingPathComponent("\(sessionID.uuidString).hist").path

        write(to: path, contents: """
        [ -f /etc/profile ] && source /etc/profile
        if [ -f ~/.bash_profile ]; then
            source ~/.bash_profile
        elif [ -f ~/.bash_login ]; then
            source ~/.bash_login
        elif [ -f ~/.profile ]; then
            source ~/.profile
        fi
        [ -f ~/.bashrc ] && source ~/.bashrc

        # Per-session history file (set by Ocak after user config)
        export HISTFILE="\(historyPath)"
        export HISTSIZE=10000
        export HISTFILESIZE=10000

        # --- Ocak terminal hooks ---
        __ocak_prompt_command() {
            printf '\\e]7;file://%s%s\\a' "$HOSTNAME" "$PWD"
            printf '\\033[=0u\\033[?1000l\\033[?1002l\\033[?1003l\\033[?1006l'
        }
        if [ -n "$PROMPT_COMMAND" ]; then
            PROMPT_COMMAND="__ocak_prompt_command;$PROMPT_COMMAND"
        else
            PROMPT_COMMAND="__ocak_prompt_command"
        fi

        # --- Ocak shell command status tracking ---
        __ocak_status_threshold=2
        __ocak_post_status() {
            [ -z "$OCAK_SESSION_ID" ] && return
            ( curl -sf -X POST http://localhost:${OCAK_HOOK_PORT:-27832}/hook \\
                -H "Content-Type: application/json" \\
                -H "X-Ocak-Session: $OCAK_SESSION_ID" \\
                -d "{\\"hook_event_name\\":\\"$1\\"}" \\
                >/dev/null 2>&1 & ) 2>/dev/null
        }
        __ocak_in_cmd=0
        __ocak_cmd_start=0
        __ocak_cmd_pending=0
        __ocak_debug_trap() {
            case "$BASH_COMMAND" in
                __ocak_*|*PROMPT_COMMAND*) return ;;
            esac
            [ -n "$COMP_LINE" ] && return
            [ "$__ocak_in_cmd" = "1" ] && return
            __ocak_in_cmd=1
            __ocak_cmd_start=$SECONDS
            ( sleep $__ocak_status_threshold && __ocak_post_status ShellCommandStart ) &
            __ocak_cmd_pending=$!
            disown $__ocak_cmd_pending 2>/dev/null
        }
        __ocak_cmd_prompt() {
            if [ "$__ocak_in_cmd" = "1" ]; then
                local duration=$(( SECONDS - __ocak_cmd_start ))
                if [ "$duration" -ge "$__ocak_status_threshold" ]; then
                    __ocak_post_status ShellCommandEnd
                elif [ "$__ocak_cmd_pending" != "0" ]; then
                    kill $__ocak_cmd_pending 2>/dev/null
                fi
                __ocak_in_cmd=0
                __ocak_cmd_pending=0
            fi
        }
        trap '__ocak_debug_trap' DEBUG
        PROMPT_COMMAND="__ocak_cmd_prompt;$PROMPT_COMMAND"
        """)

        return path
    }

    // MARK: - Cleanup

    /// Remove temp files/directories for a specific session.
    static func cleanup(sessionID: UUID) {
        let fm = FileManager.default
        let id = sessionID.uuidString
        try? fm.removeItem(atPath: (tempBase as NSString).appendingPathComponent("ocak_zdotdir_\(id)"))
        try? fm.removeItem(atPath: (tempBase as NSString).appendingPathComponent("ocak_bashrc_\(id)"))
        try? fm.removeItem(atPath: (tempBase as NSString).appendingPathComponent("ocak_bashrc_\(id)_hist"))
        try? fm.removeItem(at: historyBaseDirectory.appendingPathComponent("\(id).hist"))
    }

    /// Remove any stale Ocak temp files left from a previous crash.
    static func cleanupStale() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: tempBase) else { return }
        for item in items where item.hasPrefix("ocak_zdotdir_") || item.hasPrefix("ocak_bashrc_") {
            try? fm.removeItem(atPath: (tempBase as NSString).appendingPathComponent(item))
        }
    }

    // MARK: - Private

    private static var historyBaseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Ocak/terminal-history", isDirectory: true)
    }

    private static func ensureHistoryDirectory() {
        try? FileManager.default.createDirectory(at: historyBaseDirectory, withIntermediateDirectories: true)
    }

    private static func write(to path: String, contents: String) {
        fm.createFile(atPath: path, contents: contents.data(using: .utf8), attributes: [.posixPermissions: 0o600])
    }

    private static let fm = FileManager.default
}
