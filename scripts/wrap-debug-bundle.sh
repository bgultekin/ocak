#!/usr/bin/env bash
# Wraps the debug binary in a minimal .app bundle so TCC identifies it by
# team ID + bundle ID (stable across rebuilds) rather than CDHash.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$REPO_ROOT/macos/.build/debug"
APP_BUNDLE="$BUILD_DIR/Ocak.app"
BIN="$BUILD_DIR/Ocak"

if [[ ! -f "$BIN" ]]; then
  echo "error: debug binary not found at $BIN" >&2
  exit 1
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Only rewrite Info.plist if missing (avoid needless re-sign)
if [[ ! -f "$APP_BUNDLE/Contents/Info.plist" ]]; then
  cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Ocak</string>
    <key>CFBundleIdentifier</key>
    <string>com.ocak.app</string>
    <key>CFBundleName</key>
    <string>Ocak</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST
fi

# Copy binary into bundle (use cp to avoid breaking hardlinks)
cp -f "$BIN" "$APP_BUNDLE/Contents/MacOS/Ocak"

# Embed Sparkle.framework so dyld can find it at @rpath
SPARKLE_FW="$BUILD_DIR/Sparkle.framework"
if [[ -d "$SPARKLE_FW" ]]; then
  mkdir -p "$APP_BUNDLE/Contents/Frameworks"
  cp -Rf "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/"
  # Add rpath so the binary resolves @rpath/Sparkle.framework
  install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/Ocak" 2>/dev/null || true
fi

# Remove any SPM resource bundles from the app root before signing
# (codesign rejects "unsealed contents" at bundle root)
shopt -s nullglob
for old_bundle in "$APP_BUNDLE"/*.bundle; do
  rm -rf "$old_bundle"
done
shopt -u nullglob

# Sign the bundle — TCC uses (TeamID, BundleID) for .app bundles
codesign --force --sign "Apple Development" "$APP_BUNDLE" 2>/dev/null || \
  codesign --force --sign - --identifier "com.ocak.app" "$APP_BUNDLE"

# Copy SPM resource bundles so Bundle.module resolves correctly at runtime
shopt -s nullglob
for bundle in "$BUILD_DIR"/*_*.bundle; do
  [[ "$(basename "$bundle")" == "Ocak.app" ]] && continue
  cp -Rf "$bundle" "$APP_BUNDLE/"
done
shopt -u nullglob
