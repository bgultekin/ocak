#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPM_DIR="$REPO_ROOT/macos"
APP_NAME="Ocak"
APP_BUNDLE="$REPO_ROOT/.dist/$APP_NAME.app"
DIST_DIR="$REPO_ROOT/.dist"

# Version can be overridden at build time: APP_VERSION=1.2.3 ./scripts/build-macos-app.sh
APP_VERSION="${APP_VERSION:-0.1.0}"

echo "Building release binaries for Apple Silicon and Intel..."
cd "$SPM_DIR"

# Build each architecture natively to avoid Metal toolchain cross-compilation issues
echo "Building arm64..."
swift build -c release --arch arm64
ARM_BUILD_DIR="$SPM_DIR/.build/arm64-apple-macosx/release"

echo "Building x86_64..."
swift build -c release --arch x86_64
X86_BUILD_DIR="$SPM_DIR/.build/x86_64-apple-macosx/release"

echo "Creating universal app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Create universal binary using lipo
lipo -create \
  "$ARM_BUILD_DIR/$APP_NAME" \
  "$X86_BUILD_DIR/$APP_NAME" \
  -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy SPM resource bundle from arm64 build (architecture-independent)
if [ -d "$ARM_BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "$ARM_BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

# Create app icon (AppIcon.icns) from assets
ASSETS_IMAGES_DIR="$REPO_ROOT/assets/images"
ICONSET_DIR="$REPO_ROOT/.dist/AppIcon.iconset"
ICON_LIGHT="$ASSETS_IMAGES_DIR/ocak-icon-light@2x.png"
ICON_DARK="$ASSETS_IMAGES_DIR/ocak-icon-dark@2x.png"

echo "Creating AppIcon.icns..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Light (default) variants
sips -z 16 16     "$ICON_LIGHT" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32     "$ICON_LIGHT" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     "$ICON_LIGHT" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64     "$ICON_LIGHT" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   "$ICON_LIGHT" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256   "$ICON_LIGHT" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$ICON_LIGHT" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512   "$ICON_LIGHT" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$ICON_LIGHT" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$ICON_LIGHT" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# Dark mode variants
sips -z 16 16     "$ICON_DARK" --out "$ICONSET_DIR/icon_16x16~dark.png"      > /dev/null
sips -z 32 32     "$ICON_DARK" --out "$ICONSET_DIR/icon_16x16@2x~dark.png"   > /dev/null
sips -z 32 32     "$ICON_DARK" --out "$ICONSET_DIR/icon_32x32~dark.png"      > /dev/null
sips -z 64 64     "$ICON_DARK" --out "$ICONSET_DIR/icon_32x32@2x~dark.png"   > /dev/null
sips -z 128 128   "$ICON_DARK" --out "$ICONSET_DIR/icon_128x128~dark.png"    > /dev/null
sips -z 256 256   "$ICON_DARK" --out "$ICONSET_DIR/icon_128x128@2x~dark.png" > /dev/null
sips -z 256 256   "$ICON_DARK" --out "$ICONSET_DIR/icon_256x256~dark.png"    > /dev/null
sips -z 512 512   "$ICON_DARK" --out "$ICONSET_DIR/icon_256x256@2x~dark.png" > /dev/null
sips -z 512 512   "$ICON_DARK" --out "$ICONSET_DIR/icon_512x512~dark.png"    > /dev/null
sips -z 1024 1024 "$ICON_DARK" --out "$ICONSET_DIR/icon_512x512@2x~dark.png" > /dev/null

iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

# Write Info.plist (version values come from APP_VERSION / APP_BUILD above)
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
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
    <key>CFBundleDisplayName</key>
    <string>Ocak</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

echo "App bundle: $APP_BUNDLE"

DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_STAGING="$DIST_DIR/dmg-staging"

echo "Creating $DMG_PATH..."
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format ULFO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING"
echo "Done. DMG: $DMG_PATH"
