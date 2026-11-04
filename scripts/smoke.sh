#!/bin/bash
# Opens every Hub page in the built app and checks that the window shows something (not blank, app still alive).
#   bash scripts/make-app.sh && bash scripts/smoke.sh
# Needs the screen recording permission for Terminal (screencapture) and uses the HEY_DEV hooks.
set -uo pipefail
cd "$(dirname "$0")/.."
[ -d build/Hey.app ] || { echo "build/Hey.app is missing, run scripts/make-app.sh first" >&2; exit 1; }
swiftc -O scripts/tools/windowlist.swift -o /tmp/hey-windowlist 2>/dev/null || { echo "could not compile the window lister" >&2; exit 1; }
OUT=$(mktemp -d)
fail=0
for page in today pet quests shop achievements game vault music capture reminders focus notes clipboard usage gestures settings; do
  pkill -x Hey 2>/dev/null; sleep 2
  open --env HEY_DEV=1 --env HEY_DEV_HUB=$page --env HEY_DEV_USAGE_DEMO=1 build/Hey.app
  sleep 6
  if ! pgrep -x Hey >/dev/null; then echo "FAIL $page: the app is not running"; fail=1; continue; fi
  id=$(/tmp/hey-windowlist | awk '$2==0 && $3>=900 && $3<=1100 {print $1; exit}')
  if [ -z "$id" ]; then echo "FAIL $page: no Hub window"; fail=1; continue; fi
  screencapture -x -o -l "$id" "$OUT/$page.png"
  colors=$(python3 -c "
from PIL import Image
im = Image.open('$OUT/$page.png').convert('RGB').resize((96, 68))
print(len(set(im.getdata())))")
  if [ "${colors:-0}" -lt 40 ]; then echo "FAIL $page: the window looks blank ($colors colours)"; fail=1; else echo "ok   $page ($colors colours)"; fi
done
pkill -x Hey 2>/dev/null
echo "screenshots: $OUT"
exit $fail
