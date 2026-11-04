#!/bin/bash
# Build build/Hey.app (if missing) and pack it into build/Hey-$VER.dmg with an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d build/Hey.app ] || bash scripts/make-app.sh
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Hey.app/Contents/Info.plist)
STAGE=$(mktemp -d)
cp -R build/Hey.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f build/Hey-$VER.dmg
hdiutil create -volname "Hey!" -srcfolder "$STAGE" -ov -format UDZO build/Hey-$VER.dmg >/dev/null
rm -rf "$STAGE"
echo "Built build/Hey-$VER.dmg (v$VER)"
