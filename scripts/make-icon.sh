#!/bin/bash
# Redraws the Hey! app icon and logo from Sources/Hey/LogoArt.swift.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
swiftc -O "$root/scripts/icon/main.swift" "$root/Sources/Hey/LogoArt.swift" -o "$tmp/make-icon"
"$tmp/make-icon" "$root"
rm -rf "$tmp"
