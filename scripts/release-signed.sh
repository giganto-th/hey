#!/bin/bash
# Build a Hey-<version>.dmg that opens on any Mac without the "Apple could not verify" warning:
# sign with a Developer ID, have Apple notarize it, and staple the ticket to the .dmg.
#
# One-time setup (needs a paid Apple Developer Program account):
#   1. Create a "Developer ID Application" certificate (Xcode › Settings › Accounts › Manage Certificates, or developer.apple.com)
#      and check it is in the keychain:   security find-identity -v -p codesigning
#   2. Store notarization credentials once (an app-specific password from appleid.apple.com):
#        xcrun notarytool store-credentials hey-notary --apple-id you@example.com --team-id TEAMID --password xxxx-xxxx-xxxx-xxxx
#
# Then:
#   HEY_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" HEY_NOTARY_PROFILE=hey-notary scripts/release-signed.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${HEY_SIGN_IDENTITY:?set HEY_SIGN_IDENTITY to your Developer ID Application identity}"
: "${HEY_NOTARY_PROFILE:?set HEY_NOTARY_PROFILE to the notarytool keychain profile name}"
[[ "$HEY_SIGN_IDENTITY" == Developer\ ID* ]] || { echo "HEY_SIGN_IDENTITY must start with 'Developer ID Application'" >&2; exit 1; }

bash scripts/make-app.sh
codesign --verify --deep --strict --verbose=2 build/Hey.app

bash scripts/make-dmg.sh
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Hey.app/Contents/Info.plist)
DMG="build/Hey-$VER.dmg"

codesign --force --timestamp --sign "$HEY_SIGN_IDENTITY" "$DMG"
echo "Submitting $DMG to Apple for notarization (a few minutes) ..."
xcrun notarytool submit "$DMG" --keychain-profile "$HEY_NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "--- checks"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
echo "Ready: $DMG (upload it to the GitHub release; no install.sh workaround needed)"
