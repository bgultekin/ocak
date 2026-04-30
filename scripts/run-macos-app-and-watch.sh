#!/usr/bin/env bash
# Watch Swift sources under macos/ and re-run `swift run` from the SPM package root.
# Requires: fswatch (brew install fswatch)
#
# Only Package.swift, Sources/, and Tests/ are watched so .build, .swiftpm, and
# Package.resolved (which swift can rewrite on run) do not retrigger endless rebuilds.
# If you quit the app and `swift run` exits with status 0, this script stops.
# Press Ctrl+C to stop the watcher at any time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$REPO_ROOT/macos"

terminate_tree() {
  local pid="$1"
  local c
  for c in $(pgrep -P "$pid" 2>/dev/null || true); do
    terminate_tree "$c"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

if [[ ! -d "$MACOS_DIR" ]]; then
  echo "error: macos directory not found: $MACOS_DIR" >&2
  exit 1
fi

if ! command -v fswatch >/dev/null 2>&1; then
  echo "error: fswatch is required (brew install fswatch)" >&2
  exit 1
fi

watch_paths=()
[[ -f "$MACOS_DIR/Package.swift" ]] && watch_paths+=("$MACOS_DIR/Package.swift")
[[ -d "$MACOS_DIR/Sources" ]] && watch_paths+=("$MACOS_DIR/Sources")
[[ -d "$MACOS_DIR/Tests" ]] && watch_paths+=("$MACOS_DIR/Tests")
if ((${#watch_paths[@]} == 0)); then
  echo "error: nothing to watch under $MACOS_DIR (need Package.swift and/or Sources or Tests)" >&2
  exit 1
fi

cleanup_watch() {
  local pid="${1:-}"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
}

trap 'exit 130' INT
trap 'exit 143' TERM

while true; do
  ( cd "$MACOS_DIR" && exec swift run ) &
  swift_pid=$!

  (
    fswatch -1 -l 5 -r "${watch_paths[@]}" >/dev/null
    terminate_tree "$swift_pid"
  ) &
  watch_pid=$!

  set +e
  wait "$swift_pid"
  waited=$?
  set -e

  cleanup_watch "$watch_pid"

  if [[ "$waited" -eq 0 ]]; then
    echo "swift run exited; stopping watcher."
    exit 0
  fi

  sleep 0.2
done
