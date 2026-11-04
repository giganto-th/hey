#!/bin/bash
# Builds a release Hey.app. Run from anywhere:  scripts/make-app.sh [output-dir]
#
# macOS ties Screen Recording / Camera / Mic permission to the app's code signature, so sign with a
# stable identity or the permission is asked again after every build:
#   HEY_SIGN_IDENTITY="Apple Development: you@example.com (TEAMID)" scripts/make-app.sh
# Without it the app is ad-hoc signed (works, but permissions reset when the binary changes).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/build}"
app="$out/Hey.app"

cd "$root"
swift build -c release
bin="$(swift build -c release --show-bin-path)/Hey"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Hey"
cp Sources/Hey/Info.plist "$app/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
mkdir -p "$app/Contents/Frameworks"
cp "$(swift build -c release --show-bin-path)/libheynp.dylib" "$app/Contents/Frameworks/libheynp.dylib"
[ -d Resources/Icons ] && rsync -a Resources/Icons/ "$app/Contents/Resources/Icons/"
[ -d Resources/Logo ] && rsync -a Resources/Logo/ "$app/Contents/Resources/Logo/"
[ -d Resources/About ] && rsync -a Resources/About/ "$app/Contents/Resources/About/"
# originals are the untouched generator output; the app only needs the processed art
if [ -d Resources/Sprites ]; then rsync -a --exclude "_originals" Resources/Sprites/ "$app/Contents/Resources/Sprites/"; fi
if [ -d Resources/Pets ]; then rsync -a Resources/Pets/ "$app/Contents/Resources/Pets/"; fi

codesign --force --sign "${HEY_SIGN_IDENTITY:--}" "$app/Contents/Frameworks/libheynp.dylib"
codesign --force --deep --sign "${HEY_SIGN_IDENTITY:--}" "$app"
echo "Built $app (signed with ${HEY_SIGN_IDENTITY:-ad-hoc})"
