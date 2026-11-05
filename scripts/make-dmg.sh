#!/bin/bash
# Build build/Hey.app (if missing) and pack it into build/Hey-$VER.dmg: Hey and an Applications shortcut on a
# branded background, with the Hey! icon on the disk itself.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d build/Hey.app ] || bash scripts/make-app.sh
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Hey.app/Contents/Info.plist)
OUT="build/Hey-$VER.dmg"
RW=$(mktemp -u).dmg
STAGE=$(mktemp -d)
cp -R build/Hey.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/.background"
cp Resources/DMG/background.png "$STAGE/.background/background.png"
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
rm -f "$OUT"
hdiutil create -volname "Hey!" -srcfolder "$STAGE" -ov -format UDRW "$RW" >/dev/null
rm -rf "$STAGE"

# Lay the window out through Finder (icon positions, background, no toolbar). If Finder cannot be scripted
# (headless CI, or Automation not allowed) the disk still works, just with the default layout.
MNT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -o '/Volumes/.*' | head -1)
SetFile -a C "$MNT" 2>/dev/null || true
osascript <<OSA || echo "note: could not style the window (Finder scripting unavailable); using the default layout"
tell application "Finder"
  tell disk "Hey!"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to (POSIX file "$MNT/.background/background.png") as alias
    set position of item "Hey.app" of container window to {170, 215}
    set position of item "Applications" of container window to {490, 215}
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA
sync; sleep 1
hdiutil detach "$MNT" >/dev/null || { sleep 3; hdiutil detach -force "$MNT" >/dev/null; }
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -f "$RW"
echo "Built $OUT (v$VER)"
