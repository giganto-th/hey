# Pet sprite pipeline

1. Codex draws one 4x3 pose sheet per growth stage on flat #00FF00 (order: idle, walk_a, walk_b, flap_up, flap_down, peck, eat, sleep, startled, dizzy, happy, carried). Use the adult sheet as the style reference for the younger stages. Egg is a single image.
2. `python3 docs/art-tools/slice.py <sheet.png> <outdir>` keys out the green, cuts the 12 cells and places each on a 480 px canvas with the feet on the bottom edge (idle bird = 72% of the canvas height, same scale for every pose).
3. Copy the result to `Resources/Pets/heihei/<stage>/` (drop `_contact.png`). `scripts/make-app.sh` bundles `Resources/Pets`.
4. Check motion with `HEY_DEV=1 HEY_DEV_PET_FILM=<dir> .build/debug/Hey` (frames for every action).

Disney character fan art, for personal use only.

## 10-frame clips (all growth stages)

Every stage except the egg has `Resources/Pets/heihei/<stage>/anim/<clip>_0..9.png`. The adult has 12 clips; hatchling, child and teen have 10
(no `flap`/`fly`, because only adults fly; `SpritePet.hasClip` falls back to the single poses for anything missing).

1. One Codex job per clip: a 5x2 sheet on #00FF00 (`codex exec ... < /dev/null`), prompts patterned on the adult ones with the stage's own
   `/tmp/art/<stage>/sheet.png` as the style/proportion reference. 20+ jobs at once works but is slow (about 30 min per wave).
2. `python3 docs/art-tools/slice_anim.py <root> <out>`: `<root>/<clip>/sheet.png` → chroma key, per-clip scale so frame 1 matches the
   stage's idle height, feet pinned to the baseline (`carried` hangs from the top, `fly` is centred).
3. Copy `<out>/<clip>_[0-9].png` into the stage's `anim/` folder. `HEY_DEV_PET_FILM` renders sample frames for a visual check.

### Hatch sequence
`hatchling/anim/hatch_0..9.png` is a one-shot (2.4 s) that `SpritePet` plays when the stage changes from egg. The sheet came from one Codex job; the
first five frames are scaled to the static egg's height and the last five ramp up to the hatchling's idle height so there is no size jump either side.
Not played in reduced-motion mode or when the app starts with an already-hatched pet.

## Species (2026-11-04)
Art lives in `Resources/Pets/<species>/` (`heihei`, `fluff` = "Shams"); `PetSpecies.all` lists them and the Hub picker offers whatever is installed.
- `fluff`: complete (all stages, 10-frame clips, hatch).
- `shishi` ("Shi Shi", a fluffy chick with a dark-brown bob haircut, drawn from a user photo in the cinematic 3D style of the universe STYLE.md): egg and the 12 poses of every stage. Sheets and prompts were made in `/tmp/art5` (adult first, then the younger stages with the adult sheet as reference; the egg shows a few strands of hair). The wispy hatchling hair leaves a green fringe after keying, so `docs/art-tools/despill.py` clamps g to the red/blue level. 10-frame clips for every stage (adult 12, others 10) and the hatch clip are installed too.
- `heihei`: redrawn in a cinematic 3D style. The old 2D set is kept in `art-archive/heihei-2d/` (not bundled). Done: poses for every stage,
  egg, adult clips walk/type/dance/sleep/flap/fly/startled/dizzy/happy. Missing: adult idle/eat/carried, all clips for teen/child/hatchling,
  and the hatch clip (these fall back to single poses). Prompts are in the scratch folder `/tmp/art3/anim/`; resume with `runC.sh` once Codex quota is back.
- Slicing fur/feather art: `slice.py` unmixes the green share, clamps g<=r, erodes 1px and fills enclosed green holes. Set `KEY_MODE=hei` for Hei Hei
  (teal/emerald feathers need a stricter key).


## Keeping clips steady (2026-11)

Generated frames are never perfectly registered: the bird, its feet or the keyboard land a few pixels differently in every frame,
and in the app that reads as sliding or shaking. Two tools in `docs/art-tools/` measure and fix it:

- `clip_report.py` measures every clip (feet, torso, bottom, jitter) against a limit for its kind (calm clips such as idle and eat
  keep the feet still; hop clips such as happy, dance and startled keep the torso still sideways; walk keeps the torso still because
  the window carries the pet). `--sheets DIR` writes contact sheets with the anchors drawn, `--check` fails when a clip that is not in
  `clip_baseline.txt` goes over (CI runs it).
- `register_clips.py walk eat idle happy dance startled flap [--write]` translates frames so the anchor sits where it does in the idle
  clip, so switching between clips does not pop. `register_type.py` pins the keyboard in the typing clips.

After generating new clips run the report, look at the contact sheets, register what is over its limit and look again.
Measurements are by colour (orange feet), so they are approximate; trust the sheets over the numbers.
