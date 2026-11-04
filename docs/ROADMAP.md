# Roadmap: Companion life + Mac utilities

Personal-use, Mac-only. Pure logic goes in `HeyDomain` with Swift Testing; AppKit/system access stays in `Hey`.
Existing signals to build on: `ActivityMonitor` (keys, ambient), `PowerMonitor` (battery, idle, lock, fullscreen),
`PomodoroTimer`/`PomodoroModel`, `CaptureService` (shot/rec), `ShelfService`, `Quest`, `BehaviorFSM`, `CompanionMotion`.

## Phase 1 — The pet reacts to your work (no new art)

**Status (2026-11-04):** done. Survey showed most of 1.2/1.3 already existed (`ActivityReactor`: low/critical battery, plug in/out,
full, overheating, fast typist, doze/wake; `ContextTracker`: welcome back, late night, take-a-break). What was added:
`PetEvent.cheered` (pomodoro finished/break over → flap or hop, sleepers stay asleep) and `Greeting.line(hour:)` (five time-of-day
daily check-in lines). 3 new tests, 231 total.

| # | Feature | Domain (HeyDomain) | App (Hey) | Done when |
|---|---------|--------------------|-----------|-----------|
| 1.1 | Pomodoro reactions | `CompanionSignals.focusRound` events: `started`, `completed`, `broke`; new `PetEvent.cheer` mapped to existing `.happy`/`.flap` | `PomodoroModel` emits events to `PetScene`; completed round grants food/XP via an existing quest hook | Finishing a round makes the pet celebrate and pays out once; tests cover no double reward |
| 1.2 | Machine-state reactions | `MachineMood` policy (pure): battery low → `worried`, plugged in → `pleased`, long idle → sleepy, 20 min continuous typing → suggest a break | `PowerMonitor` and `ActivityMonitor` feed the policy; throttle so a reaction fires at most once per cause per N minutes | Unit tests for thresholds and cooldowns; no reaction while hidden or fullscreen |
| 1.3 | Time-of-day greetings | `Greeting.pick(now:lastSeen:)` (morning, late night, long absence → "missed you") with injected clock | Bubble via `PetBubble`, shown at most once per slot per day | Tests for each slot and the once-per-day rule |

## Phase 2 — Mac utilities (daily use)

**Status (2026-11-04):** 2.1 and 2.2 built, 2.3 already covered by `ContextTracker.takeBreak`.
- OCR: radial action `ocr` → drag an area → Vision (th-TH + en-US) → text on the clipboard. Not saved to disk. Thai recognition checked on a rendered sample.
- Clipboard: `ClipboardHistory` (HeyDomain, 6 tests) + `ClipboardService` poller; Hub → ไฟล์และโน้ต → คลิปบอร์ด (search, pin, copy again, delete, pause). Text only, memory only, skips concealed/transient pasteboard types. Radial action `clip` (in "เพิ่มเติม" by default).
- Not yet checked by hand in the running app: the OCR area picker and the clipboard tab.

| # | Feature | Notes |
|---|---------|-------|
| 2.1 | Clipboard history | `ClipboardHistory` struct in `HeyDomain` (cap 30, dedupe, pin, text/image/link kind). `Hey` polls `NSPasteboard.changeCount` every 0.5 s. Panel in the Hub plus a radial action `clip`. Skip entries when the source app marks them concealed (`org.nspasteboard.ConcealedType`), so password managers are never stored. Persist text only, in memory for images. |
| 2.2 | Screenshot OCR | Extend `CaptureService`: after region select, run Vision `VNRecognizeTextRequest` (Thai + English), copy text to the clipboard, show a bubble. Radial action `ocr`. |
| 2.3 | Break reminder | Reuses 1.2's typing-time signal. Pure `BreakPolicy` (interval, snooze, skip while focusing/fullscreen). Reminder toast with stretch / 20-20-20 / water; completing it feeds a quest. |

Add the new actions to `RadialAction` so they are pinnable in the existing customizable ring.

## Phase 3 — Reach (only if Phases 1–2 get used)

- Shortcuts: built (2026-11-04) as `hey://` links (`HeyURL`), usable from Shortcuts' "Open URLs": `focus/start`, `focus/stop`, `note?text=`, `clip?n=0`, `hub?page=`. Real App Intents were skipped: they need Xcode metadata extraction, which the SwiftPM build does not run.
- Calendar next-event heads-up through EventKit (read-only): built (2026-11-04), `CalendarHeadsUp` + `CalendarService`, opt-in toggle in Hub → ตั้งค่า → ปฏิทิน, asks for calendar access only when turned on.
- Frontmost-app awareness: built (2026-11-04) as `AppFocusEngine` (bundle id only, one speech bubble per long stay: coding 40 min, reading 30, gaming 45, 1 h cooldown). Idle-pose changes per app still need art.
- Dress-up items in the shop; rare idle poses.

## Art tasks (parallel, via Codex pipeline in `docs/SPRITE_PIPELINE.md`)

1. ~~10-frame clip sets for hatchling, child, teen~~ (done 2026-11-04)
2. ~~Egg → hatch animation~~ (done: `hatchling/anim/hatch_0..9.png`, played once by `SpritePet` when the stage leaves egg).
3. Optional new clips: stretch, drink water, sweat/hot.

## Order and risks

1. 1.1 → 1.2 → 1.3 (one session, shared plumbing), then 2.3 (needs 1.2).
2. 2.1 and 2.2 are independent; do 2.2 first (smaller), then 2.1.
3. Risks: clipboard privacy (handled by the concealed-type skip and a pause toggle); Vision Thai accuracy (test on real screenshots); reaction spam (every reaction has a cooldown and a Settings toggle).
4. Every phase ends with `swift test`, `scripts/make-app.sh`, and a check in the running app.

## Done 2026-11-04 (late)

- Menu-bar title scrolls without a blank gap (tiled copies, fixed gap).
- Vault and Gallery items start a real drag session (copy only), so they drop onto the Finder, the desktop and other apps.
- Food is placed anywhere on screen; it falls to the floor and the pet walks over to eat it (`FoodController`, `Seek`).
- Bubble chase: `BubbleField` (pure) + `BubbleController`; the pet walks under the nearest bubble and pecks it.
- Food art regenerated in the 3D animated-film style (cookie, apple, honey jar, rice bowl); the sheet is drawn on flat blue, keyed with a blue key (the apple leaf and the rice bowl clash with green).
- Radial menu: sized for the busiest page (was a fixed 8, which clipped the old "more" page), and the unpinned actions now sit in three folders (capture, notes, other) instead of one crowded page. The hide action left the ring (still in the menu-bar menu). The fluff species is now called Shams (an old "Foo" save is renamed on load).
- Two languages (Thai, English): every visible string goes through `tr("ไทย", args…)` with the Thai text as the key; `Resources/Localization/en.json` holds the English (`scripts/l10n_keys.py` lists missing keys, a test fails when one is missing). The language is picked at launch (Settings › Language: follow the system, Thai or English) and changing it offers to relaunch. `HEY_LANG=en` tries a language without saving it. Not translated: the usage descriptions in Info.plist, the website and the README.
- The pet menu is now a ring of actions and your own folders, edited in Settings (move, hide, reorder, rename, delete).
- AI credits (Hub › AI credits, radial action, menu-bar lines, pet alerts at 80%/95%): Codex quota is read from the last `rate_limits` event in `~/.codex/sessions` (local only); Claude quota comes from `api.anthropic.com/api/oauth/usage` with the Claude Code login read from the Keychain through `/usr/bin/security` (opt-in, unofficial endpoint). ChatGPT/Claude web chat have no API. The new radial action is in the default "other" folder; an existing save finds it under Hidden in Settings.
- AI credits now handle several Claude accounts: every `Claude Code-credentials*` Keychain item with a Claude login is listed (labelled by the email from the profile endpoint, duplicates dropped), and tokens pasted by hand (`claude setup-token`) are kept in Hey!'s own Keychain items. Not verified: a second login made with `CLAUDE_CONFIG_DIR=~/.claude-2 claude`, and whether a setup-token may read the usage endpoint. Claude Code refreshes access tokens only while it runs, so a rarely used account shows "expired" until it is opened again.
- AI credits for ChatGPT (Codex), Claude and Antigravity, several accounts each, in one list with the provider's real logo (the icon of its installed app, read at run time, nothing bundled). Codex: every `~/.codex*` folder with a login/sessions is an account (email from `auth.json`), more folders can be added. Antigravity: the running app's local server (`agy --hub-port --csrf_token`, `GetUserStatus`) per running copy, last readings remembered per account. Not verified: a second Codex home, a second Claude login, two Antigravity copies at once.
