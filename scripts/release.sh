#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Validate arguments ---
VERSION="$1"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.2.0"
    exit 1
fi

# Strip leading 'v' if provided
VERSION="${VERSION#v}"
TAG="v$VERSION"

# --- Check prerequisites ---
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI is not installed. Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: not authenticated with gh. Run: gh auth login"
    exit 1
fi

# --- Tag ---
if git -C "$REPO_ROOT" tag | grep -qx "$TAG"; then
    echo "Error: tag $TAG already exists locally. Delete it first: git tag -d $TAG"
    exit 1
fi

echo "Creating and pushing tag $TAG..."
git -C "$REPO_ROOT" tag "$TAG"
git -C "$REPO_ROOT" push origin "$TAG"

# --- Build ---
echo "Building Ocak $VERSION..."
APP_VERSION="$VERSION" "$SCRIPT_DIR/build-macos-app.sh"

DMG_PATH="$REPO_ROOT/.dist/Ocak.dmg"
if [ ! -f "$DMG_PATH" ]; then
    echo "Error: expected DMG not found at $DMG_PATH"
    exit 1
fi

# --- Create draft GitHub release ---
echo "Creating draft GitHub release $TAG..."
gh release create "$TAG" \
    --draft \
    --title "Ocak $VERSION" \
    --generate-notes \
    "$DMG_PATH#Ocak.dmg"

echo "Done. Draft release $TAG created — publish it when ready."
