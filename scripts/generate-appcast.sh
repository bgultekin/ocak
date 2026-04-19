#!/bin/bash
# Signs the release DMG with Sparkle's EdDSA sign_update tool and emits an
# appcast.xml containing a single <item> for the current version.
#
# Required env vars:
#   VERSION             - e.g. 0.8.0
#   TAG                 - e.g. v0.8.0
#   REPO                - GitHub slug, e.g. bgultekin/ocak
#   SPARKLE_PRIVATE_KEY - EdDSA private key (Sparkle-generated base64 string)
#
# The public counterpart is baked into the app's Info.plist via SPARKLE_PUBLIC_KEY
# at build time. Generate the keypair once with Sparkle's `generate_keys` binary
# (from the Sparkle SPM package) and store the private key as a GitHub Actions
# secret; commit the public key as a GitHub Actions variable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/.dist"
DMG_PATH="$DIST_DIR/Ocak.dmg"
APPCAST_PATH="$DIST_DIR/appcast.xml"

: "${VERSION:?VERSION is required}"
: "${TAG:?TAG is required}"
: "${REPO:?REPO is required}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is required}"

if [ ! -f "$DMG_PATH" ]; then
    echo "error: $DMG_PATH not found" >&2
    exit 1
fi

# Locate Sparkle's sign_update tool from the resolved SPM artifact.
SIGN_UPDATE=$(find "$REPO_ROOT/macos/.build" \
    -type f -name sign_update -perm -u+x 2>/dev/null | head -1 || true)
if [ -z "$SIGN_UPDATE" ]; then
    echo "Resolving Sparkle to fetch sign_update tool..."
    (cd "$REPO_ROOT/macos" && swift package resolve)
    SIGN_UPDATE=$(find "$REPO_ROOT/macos/.build" \
        -type f -name sign_update -perm -u+x 2>/dev/null | head -1 || true)
fi
if [ -z "$SIGN_UPDATE" ]; then
    echo "error: Could not locate Sparkle's sign_update tool." >&2
    exit 1
fi

# sign_update accepts the private key on stdin via --ed-key-file -
KEY_FILE=$(mktemp)
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE"

SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH" --ed-key-file "$KEY_FILE")
# sign_update prints something like: sparkle:edSignature="..." length="12345"
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
ED_LENGTH=$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

if [ -z "$ED_SIGNATURE" ] || [ -z "$ED_LENGTH" ]; then
    echo "error: sign_update output did not contain signature/length:" >&2
    echo "$SIGN_OUTPUT" >&2
    exit 1
fi

PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
DMG_URL="https://github.com/$REPO/releases/download/$TAG/Ocak.dmg"
RELEASE_NOTES_URL="https://github.com/$REPO/releases/tag/$TAG"

cat > "$APPCAST_PATH" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Ocak</title>
        <link>https://github.com/$REPO</link>
        <description>Ocak updates</description>
        <language>en</language>
        <item>
            <title>Ocak $VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>
            <enclosure
                url="$DMG_URL"
                length="$ED_LENGTH"
                type="application/octet-stream"
                sparkle:edSignature="$ED_SIGNATURE" />
        </item>
    </channel>
</rss>
XML

echo "Wrote $APPCAST_PATH"
