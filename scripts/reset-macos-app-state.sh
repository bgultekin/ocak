#!/bin/bash
# Reset Ocak prefs, Application Support, and agent plugins. Run with --help for options.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Installed .app (see scripts/build-app.sh) vs swift run / SPM debug binary (domain "Ocak").
INSTALLED_APP_DOMAIN="${OCAK_INSTALLED_APP_DOMAIN:-${OCAK_DEFAULTS_DOMAIN:-com.ocak.app}}"
SWIFT_RUN_DOMAIN="${OCAK_SWIFT_RUN_DOMAIN:-Ocak}"
APP_SUPPORT="$HOME/Library/Application Support/Ocak"
REMOVE_APP_SUPPORT=true
REMOVE_PLUGINS=true
# both | installed | swift-run
DEFAULTS_SCOPE=both

usage() {
    cat <<'EOF'
Reset Ocak preferences, Application Support, and agent plugins (Claude Code + OpenCode).

By default clears UserDefaults for BOTH the installed app (com.ocak.app) and swift run (Ocak).

Usage:
  ./scripts/reset-macos-app-state.sh
  ./scripts/reset-macos-app-state.sh --installed-app-only
  ./scripts/reset-macos-app-state.sh --swift-run-only
  ./scripts/reset-macos-app-state.sh --defaults-only    # keep ~/Library/Application Support/Ocak
  ./scripts/reset-macos-app-state.sh --no-plugins       # keep Claude/OpenCode plugin installs

Environment:
  OCAK_INSTALLED_APP_DOMAIN   UserDefaults domain for the .app install (default: com.ocak.app).
  OCAK_SWIFT_RUN_DOMAIN       UserDefaults domain for swift run (default: Ocak).
  OCAK_DEFAULTS_DOMAIN        Alias for OCAK_INSTALLED_APP_DOMAIN (backward compatible).

Examples:
  OCAK_INSTALLED_APP_DOMAIN=com.example.foo ./scripts/reset-macos-app-state.sh
EOF
}

delete_defaults_domain_if_present() {
    local d="$1"
    if defaults read "$d" &>/dev/null; then
        defaults delete "$d"
        echo "Removed UserDefaults domain: $d"
    else
        echo "No UserDefaults domain at $d"
    fi
}

find_claude_cli() {
    local p
    p=$(bash -lc 'command -v claude' 2>/dev/null) || true
    if [[ -n "$p" && -x "$p" ]]; then
        printf '%s\n' "$p"
        return 0
    fi
    for p in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do
        if [[ -x "$p" ]]; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

remove_legacy_ocak_hooks_from_claude_settings() {
    local settings="$HOME/.claude/settings.json"
    [[ -f "$settings" ]] || return 0
    if ! python3 - "$settings" <<'PY'
import json
import os
import sys
import tempfile

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError):
    sys.exit(0)

hooks = data.get("hooks")
if not isinstance(hooks, dict):
    sys.exit(0)

changed = False
for key, value in list(hooks.items()):
    if not isinstance(value, list) or not all(isinstance(m, dict) for m in value):
        continue
    filtered = []
    for matcher in value:
        hook_array = matcher.get("hooks")
        if not isinstance(hook_array, list):
            filtered.append(matcher)
            continue
        if not all(isinstance(h, dict) for h in hook_array):
            filtered.append(matcher)
            continue
        if any("OCAK_SESSION_ID" in (h.get("command") or "") for h in hook_array):
            continue
        filtered.append(matcher)
    if len(filtered) == len(value):
        continue
    changed = True
    if filtered:
        hooks[key] = filtered
    else:
        del hooks[key]

if not changed:
    sys.exit(0)

if hooks:
    data["hooks"] = hooks
else:
    data.pop("hooks", None)

parent = os.path.dirname(path) or "."
fd, tmp = tempfile.mkstemp(dir=parent, prefix=".settings.", suffix=".tmp.json")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)
except OSError:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    sys.exit(1)
PY
    then
        echo "Warning: could not strip legacy OCAK hooks from $settings (python3/json issue)." >&2
    else
        echo "Checked $settings (removed legacy OCAK_SESSION_ID hooks if present)."
    fi
}

remove_ocak_plugins() {
    echo "Removing Ocak agent plugins…"

    local claude_bin
    if claude_bin=$(find_claude_cli); then
        echo "Using Claude CLI: $claude_bin"
        "$claude_bin" plugin uninstall ocak@ocak-plugins 2>/dev/null || \
            echo "Note: Claude plugin uninstall failed or plugin was not installed."
        "$claude_bin" plugin marketplace remove ocak-plugins 2>/dev/null || true
    else
        echo "Claude CLI not found; skipping \`claude plugin uninstall\` / marketplace remove."
    fi

    remove_legacy_ocak_hooks_from_claude_settings

    local opencode_plugin="$HOME/.config/opencode/plugins/ocak.js"
    if [[ -f "$opencode_plugin" ]]; then
        rm -f "$opencode_plugin"
        echo "Removed OpenCode plugin: $opencode_plugin"
    else
        echo "No OpenCode plugin at $opencode_plugin"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --installed-app-only)
            if [[ "$DEFAULTS_SCOPE" == "swift-run" ]]; then
                echo "Error: --installed-app-only conflicts with --swift-run-only." >&2
                exit 1
            fi
            DEFAULTS_SCOPE=installed
            shift
            ;;
        --swift-run-only)
            if [[ "$DEFAULTS_SCOPE" == "installed" ]]; then
                echo "Error: --swift-run-only conflicts with --installed-app-only." >&2
                exit 1
            fi
            DEFAULTS_SCOPE=swift-run
            shift
            ;;
        --defaults-only)
            REMOVE_APP_SUPPORT=false
            shift
            ;;
        --no-plugins)
            REMOVE_PLUGINS=false
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$DEFAULTS_SCOPE" in
    both)
        echo "Ocak state reset (UserDefaults: $INSTALLED_APP_DOMAIN + $SWIFT_RUN_DOMAIN)"
        ;;
    installed)
        echo "Ocak state reset (UserDefaults: $INSTALLED_APP_DOMAIN only)"
        ;;
    swift-run)
        echo "Ocak state reset (UserDefaults: $SWIFT_RUN_DOMAIN only)"
        ;;
esac

if pgrep -xq Ocak; then
    echo "Quitting Ocak…"
    osascript -e 'tell application "Ocak" to quit' 2>/dev/null || true
    for _ in $(seq 1 30); do
        pgrep -xq Ocak || break
        sleep 0.2
    done
    if pgrep -xq Ocak; then
        echo "Ocak did not exit in time; sending SIGTERM…"
        killall Ocak 2>/dev/null || true
        sleep 0.5
    fi
    if pgrep -xq Ocak; then
        echo "Warning: Ocak is still running. Quit it manually and re-run this script." >&2
        exit 1
    fi
else
    echo "Ocak is not running."
fi

if [[ "$REMOVE_PLUGINS" == true ]]; then
    remove_ocak_plugins
else
    echo "Skipped plugin removal (--no-plugins)."
fi

case "$DEFAULTS_SCOPE" in
    both)
        delete_defaults_domain_if_present "$INSTALLED_APP_DOMAIN"
        delete_defaults_domain_if_present "$SWIFT_RUN_DOMAIN"
        ;;
    installed)
        delete_defaults_domain_if_present "$INSTALLED_APP_DOMAIN"
        ;;
    swift-run)
        delete_defaults_domain_if_present "$SWIFT_RUN_DOMAIN"
        ;;
esac

if [[ "$REMOVE_APP_SUPPORT" == true ]]; then
    if [[ -d "$APP_SUPPORT" ]]; then
        rm -rf "$APP_SUPPORT"
        echo "Removed: $APP_SUPPORT"
    else
        echo "No Application Support folder at $APP_SUPPORT"
    fi
else
    echo "Skipped Application Support ( --defaults-only )"
fi

echo "Done."
