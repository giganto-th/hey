#!/bin/bash
# Install the latest Hey! from GitHub without the "Apple could not verify" warning.
#   curl -fsSL https://raw.githubusercontent.com/giganto-th/hey/main/scripts/install.sh | bash
# A file downloaded by curl carries no quarantine flag, so macOS Gatekeeper does not ask about it.
# HEY_INSTALL_DIR changes the target folder (default /Applications).
set -euo pipefail
REPO="giganto-th/hey"
DEST="${HEY_INSTALL_DIR:-/Applications}"

echo "Looking for the latest Hey! ..."
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep -o '"browser_download_url": *"[^"]*\.dmg"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
[ -n "$URL" ] || { echo "No .dmg found in the latest release." >&2; exit 1; }

TMP=$(mktemp -d)
MNT="$TMP/mnt"
cleanup() { hdiutil detach "$MNT" -quiet 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

echo "Downloading $URL"
curl -fL --progress-bar -o "$TMP/Hey.dmg" "$URL"
mkdir -p "$MNT"
hdiutil attach "$TMP/Hey.dmg" -mountpoint "$MNT" -nobrowse -quiet

pkill -x Hey 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/Hey.app"
cp -R "$MNT/Hey.app" "$DEST/Hey.app"
xattr -dr com.apple.quarantine "$DEST/Hey.app" 2>/dev/null || true

echo "Installed $DEST/Hey.app"
[ "$DEST" = "/Applications" ] && open "$DEST/Hey.app"
