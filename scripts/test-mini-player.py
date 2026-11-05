#!/usr/bin/env python3
"""Smoke-test video ownership when the music popover hands off to PiP.

Run after `swift build`: python3 -I scripts/test-mini-player.py
Uses a separate save directory; does not stop or modify the user's running app.
Requires a logged-in macOS desktop and internet access for the YouTube player.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


root = Path(__file__).resolve().parent.parent
out = Path(tempfile.mkdtemp(prefix="hey-mini-player-test-"))
env = dict(os.environ,
           HEY_DATA_DIR=str(out / "data"),
           HEY_DEV="1", HEY_DEV_CALM="1",
           HEY_DEV_PLAY="M7lc1UVf-VE", HEY_DEV_LOG_MUSIC="1",
           HEY_DEV_MUSIC_POPOVER="1", HEY_DEV_MINI=str(out / "mini.png"))
log_path = out / "app.log"
with log_path.open("w") as log:
    app = subprocess.Popen([str(root / ".build/debug/Hey")], cwd=root,
                           env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 25
        while app.poll() is None and time.monotonic() < deadline:
            if "[video] js:" in log_path.read_text():
                break
            time.sleep(0.1)
        # The snapshot is asynchronous; let it finish before terminating the app.
        deadline = time.monotonic() + 3
        while app.poll() is None and time.monotonic() < deadline:
            if (out / "mini.png").exists():
                break
            time.sleep(0.1)
    finally:
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=5)

text = log_path.read_text()
print(f"Artifacts: {out}")
for line in text.splitlines():
    if "[video]" in line or "[popover]" in line:
        print(line)

snapshots = [line for line in text.splitlines() if "[video] js:" in line]
passed = ("[popover] frame:" in text and text.count("[video] attach") >= 2
          and bool(snapshots) and "window: MiniPanel visible=true" in snapshots[-1]
          and (out / "mini.png").exists())
print("PASS: video stays in PiP after popover handoff" if passed
      else "FAIL: popover did not hand video to a visible PiP window")
sys.exit(0 if passed else 1)
