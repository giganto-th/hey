# Hei Hei adult sprite generation — D

Character: Hei Hei from Disney Moana, private owner desktop fan art. The original-rooster fallback was not used.

Tool: built-in image_gen, transparent_background=true. Assets generated individually in requested order. Master studied first: Resources/Sprites/heihei/hatchling_idle.png. The master file was not changed.

## Generation log

Reference chain: master hatchling → adult idle; adult idle → walk; walk → eat; adult idle → happy; eat → sleep. Three idle generations were made to request flat fills; only the last idle was selected.

All five pose drafts were saved under Resources/Sprites/heihei/ using the exact requested filenames. The image tool returned non-1024 canvases and retained subtle shading despite explicit flat-fill prompts. Deterministic final export/flat-fill normalization is awaiting the user's answer to the in-session question. These drafts must not yet be described as fully compliant final sprites.

## Exact prompts

### 1. adult_idle.png

Reference: Resources/Sprites/heihei/hatchling_idle.png

```text
Use case: illustration-story.
Asset type: one transparent PNG sprite for the personal macOS desktop-pet app Hey!, 1024x1024.
Input image 1 is the master hatchling_idle.png, a STYLE reference and younger version of this same bird. Draw its ADULT form, adult_idle: Hei Hei, the dim-witted cross-eyed rooster from Disney Moana, private fan art. Match the reference's graphic style exactly, but make all fills entirely FLAT even where the reference has shading.
Adult identity: plump brown-ochre body with a cream chest, scruffy ragged feather edges, large red-orange comb and wattle, orange beak, huge bulging white cross-eyed eyes with tiny black pupils aiming inward, pink tongue poking out of one side of the beak, spindly orange legs, a fan of messy colorful tail feathers in muted teal, moss green, rusty brown and ochre. Proud upright posture but completely clueless dopey expression.
Pose: idle, standing on both feet, head upright, bird facing RIGHT in a three-quarter right view. Beak points right and tail is behind on left.
Style invariants: thick warm dark-brown outline with smooth round joins, simple bold flat color shapes, same eye design and contour language as the master, clean cartoon sprite. NO gradients, highlights, glow, texture, lighting, cast shadow, ground, border, watermark or text.
Composition: full bird centered with generous transparent margin on all four sides; entire tail, comb and feet visible. Foot soles rest on one implied shared horizontal baseline at y=860 on the 1024x1024 canvas. No visible baseline. Keep silhouette approximately inside x=130..890, y=145..860.
Background: genuinely transparent, alpha zero outside artwork, no background color or checkerboard illustration. Generate ONE sprite only, no sheet or variants.
```

### 2. adult_idle.png — flat-fill correction

Reference: first adult idle generation (discarded)

```text
Use case: style-transfer. Correct the attached adult rooster sprite into a strictly flat-color cartoon sprite. Keep this exact adult character, idle pose, rightward facing direction, shape design, large cross-eyed white eyes, tiny inward black pupils, orange beak, pink side tongue, red-orange comb and wattle, brown ochre body, cream chest, brown wings, teal/green/rust/ochre tail, orange feet, and thick dark warm-brown round-joined outlines. This is Hei Hei from Moana in the master sprite's graphic style, private fan art.
CRITICAL CORRECTION: Remove ALL gradient shading and subtle texture from EVERY colored area. Each closed color shape must contain a SINGLE uniform solid RGB color, like a screenprinted vector cartoon. No color variation within the comb, tail feather, body, wings, eyes, chest, feet, tongue or beak. White eyes must be pure uniform white. No lighting, highlight, shadow, gloss, airbrush, mottling, noise or glow. Edge antialiasing only.
Output exactly one 1024x1024 RGBA PNG with a genuinely transparent background. Entire rooster centered with generous margin. Scale the bird so top of comb is around y=130 and bottom of soles is y=860, leaving 164 transparent pixels below. Tail and beak stay inside x=120..900. No ground, no cast shadow, no visible baseline, no text. This is adult_idle.png.
```

### 3. adult_idle.png — solid-palette redraw

Reference: second adult idle generation (discarded)

```text
Redraw this rooster as a FLAT VECTOR-STYLE STICKER using only 11 SOLID COLORS. The supplied image is a character identity and line-style reference, NOT a shading reference. All previous shading must disappear completely. Replace all feather gradients with one solid ochre #D99935 for body, one solid brown #9E603E for wings, one cream #F6DEAC for chest, solid teal #358B89, green #8B9F45 and rust #AF5A39 for tail feathers, solid red-orange #EF512A for comb and wattle, solid orange #F7A51B for beak and feet, solid pink #F28094 for tongue, pure solid white for eyes, tiny black cross-eyed pupils. Thick uniform dark warm brown #4E311F outlines with round joins. Every shape is filled with ONE hex color with absolutely no color variation inside. Vector clipart / cel animation production art. No gradients of any kind, no grain, no shadows, no lighting, no dimensional rendering. Preserve this exact full adult Hei Hei from Moana cartoon rooster, three-quarter RIGHT, plump body, messy fan tail, huge crossed eyes, tongue sticking out sideways, standing idle. 1024x1024 transparent PNG. Whole rooster comfortably within canvas, foot bottoms exactly y=860, centered, generous margin, no ground line, no background or checkerboard, no text.
```

### 4. adult_walk.png

Reference: Resources/Sprites/heihei/adult_idle.png

```text
Use case: illustration-story. Asset type: ONE 1024x1024 transparent PNG animation pose for a personal desktop pet.
Input image 1 is the closest existing ADULT sprite of the same bird, the character identity, proportions, palette and art-style reference. Keep this EXACT SAME adult Hei Hei rooster from Disney Moana (private fan art). Huge bulging crossed white eyes with tiny inward black pupils, pink tongue out the side of orange beak, plump brown-ochre body, cream chest, brown wings, large red-orange comb and wattle, spindly orange legs, same messy fan of teal, moss-green, rust and ochre tail feathers on the left. Face RIGHT. Same full-grown age and body proportions.
Graphic style: thick warm dark-brown outlines with rounded joins and scruffy feather edges, simple cartoon shapes. STRICTLY FLAT solid-color fills, single uniform color per shape, no gradients or shading even if present in reference. No lighting, glow, texture or cast shadow.
Output: full bird centered on genuinely transparent alpha-zero background, no scene or ground, no visible baseline. Entire artwork inside canvas with margin. Foot soles on implied y=860 baseline. Match reference's creature scale across poses. No watermark or text except the tiny Zzz allowed only for sleep. ONE pose, never a contact sheet.
Pose: adult_walk.png. Change the idle pose into an obvious mid-stride walk toward the RIGHT: one orange leg reaches forward to the right with toes landing on y=860; other leg steps behind to the left and lifts slightly. Head and neck bob noticeably forward toward the right; tail remains fanned behind to the left. Wings held loosely at sides. Crossed eyes and tongue-out clueless expression. Preserve adult identity and thick rounded outline weight. Leave transparent margins around all extremities.
```

### 5. adult_eat.png

Reference: Resources/Sprites/heihei/adult_walk.png

```text
Use case: illustration-story. Asset type: ONE 1024x1024 transparent PNG animation pose for a personal desktop pet.
Input image 1 is the closest existing ADULT sprite of the same bird, the character identity, proportions, palette and art-style reference. Keep this EXACT SAME adult Hei Hei rooster from Disney Moana (private fan art). Huge bulging crossed white eyes with tiny inward black pupils, pink tongue out the side of orange beak, plump brown-ochre body, cream chest, brown wings, large red-orange comb and wattle, spindly orange legs, same messy fan of teal, moss-green, rust and ochre tail feathers on the left. Face RIGHT. Same full-grown age and body proportions.
Graphic style: thick warm dark-brown outlines with rounded joins and scruffy feather edges, simple cartoon shapes. STRICTLY FLAT solid-color fills, single uniform color per shape, no gradients or shading even if present in reference. No lighting, glow, texture or cast shadow.
Output: full bird centered on genuinely transparent alpha-zero background, no scene or ground, no visible baseline. Entire artwork inside canvas with margin. Foot soles on implied y=860 baseline. Match reference's creature scale across poses. No watermark or text except the tiny Zzz allowed only for sleep. ONE pose, never a contact sheet.
Pose: adult_eat.png. The reference bird is walking with head leaning forward; now change it to PECKING DOWN at one tiny golden corn kernel near the right foot. Both thin legs planted with soles on implied y=860; rounded rump and messy tail on left; neck bends dramatically forward and DOWN, head low beside the chest on the RIGHT, orange beak pointing diagonally down-right, very close to the corn kernel near y=850. Huge bulging eyes remain comically CROSSED even while pecking, pink tongue peeks out to the side. Comb droops with the lowered head. Keep plump adult body, long adult wattle and colorful adult tail identity. Wings folded. Corn kernel is the only extra object, no ground. Maintain the same adult bird scale as the reference, so bending lowers the pose; do not enlarge the crouched bird to fill the canvas.
```

### 6. adult_happy.png

Reference: Resources/Sprites/heihei/adult_idle.png

```text
Use case: illustration-story. Asset type: ONE 1024x1024 transparent PNG animation pose for a personal desktop pet.
Input image 1 is the closest existing ADULT sprite of the same bird, the character identity, proportions, palette and art-style reference. Keep this EXACT SAME adult Hei Hei rooster from Disney Moana (private fan art). Huge bulging crossed white eyes with tiny inward black pupils, pink tongue out the side of orange beak, plump brown-ochre body, cream chest, brown wings, large red-orange comb and wattle, spindly orange legs, same messy fan of teal, moss-green, rust and ochre tail feathers on the left. Face RIGHT. Same full-grown age and body proportions.
Graphic style: thick warm dark-brown outlines with rounded joins and scruffy feather edges, simple cartoon shapes. STRICTLY FLAT solid-color fills, single uniform color per shape, no gradients or shading even if present in reference. No lighting, glow, texture or cast shadow.
Output: full bird centered on genuinely transparent alpha-zero background, no scene or ground, no visible baseline. Entire artwork inside canvas with margin. Foot soles on implied y=860 baseline. Match reference's creature scale across poses. No watermark or text except the tiny Zzz allowed only for sleep. ONE pose, never a contact sheet.
Pose: adult_happy.png. Input adult_idle is the closest upright adult reference. Change only the pose and expression: both brown feathered WINGS RAISED and spread upward in a joyous silly flap, head upright and facing RIGHT, big open goofy GRIN in the orange beak with the pink tongue hanging out to the side, eyes remain huge and crossed. Proud plump adult stance with both spindly orange feet planted on y=860. Messy colorful adult tail fan behind on left, large red-orange comb and wattle. Keep character scale, body proportions and individual feather colors matching idle. Wings and comb and tail must fit with clear transparent margins. Capture one flapping instant, no motion lines, no text or symbols. Solid uniform flat colors, no gradients or shading.
```

### 7. adult_sleep.png

Reference: Resources/Sprites/heihei/adult_eat.png

```text
Use case: illustration-story. Asset type: ONE 1024x1024 transparent PNG animation pose for a personal desktop pet.
Input image 1 is the closest existing ADULT sprite of the same bird, the character identity, proportions, palette and art-style reference. Keep this EXACT SAME adult Hei Hei rooster from Disney Moana (private fan art). Huge bulging crossed white eyes with tiny inward black pupils, pink tongue out the side of orange beak, plump brown-ochre body, cream chest, brown wings, large red-orange comb and wattle, spindly orange legs, same messy fan of teal, moss-green, rust and ochre tail feathers on the left. Face RIGHT. Same full-grown age and body proportions.
Graphic style: thick warm dark-brown outlines with rounded joins and scruffy feather edges, simple cartoon shapes. STRICTLY FLAT solid-color fills, single uniform color per shape, no gradients or shading even if present in reference. No lighting, glow, texture or cast shadow.
Output: full bird centered on genuinely transparent alpha-zero background, no scene or ground, no visible baseline. Entire artwork inside canvas with margin. Foot soles on implied y=860 baseline. Match reference's creature scale across poses. No watermark or text except the tiny Zzz allowed only for sleep. ONE pose, never a contact sheet.
Pose: adult_sleep.png. Input adult_eat is the closest pose with the neck and head lowered. Redraw this same ADULT bird curled up/sitting asleep on the implied y=860 baseline. Compact plump brown-ochre body rests low with legs folded/tucked underneath, two little orange toe tips may peek out on the baseline. Adult colorful messy tail curves up on the LEFT; large adult comb and wattle on head on the RIGHT. Neck folds and head nestles against the cream chest. Face and orange beak still point RIGHT. Both eyes completely CLOSED, drawn as curved thick dark-brown sleepy eyelid arcs; no visible white eyeballs or pupils. Pink tongue still pokes out of the side of the beak. Wings folded snugly against sides. No corn or food. Add only a TINY 'Zzz' above the sleeping head in warm dark brown, hand-drawn simple lettering, no speech bubble. No other text. Retain adult age, tail size and body scale, with naturally lower silhouette than standing idle and generous empty transparent space overhead. Solid uniform flat colors with absolutely no gradients, texture, shine or shading. No ground, blanket, bed or shadow.
```


## Pillow verification of saved drafts

| File | Required 1024×1024 | Required RGBA | Corner alpha (TL, TR, BL, BR) |
| --- | --- | --- | --- |
| adult_idle.png | 1254×1254 — FAIL | RGBA — PASS | [0, 0, 0, 0] — PASS |
| adult_walk.png | 1254×1254 — FAIL | RGBA — PASS | [0, 0, 0, 0] — PASS |
| adult_eat.png | 1254×1254 — FAIL | RGBA — PASS | [0, 0, 0, 0] — PASS |
| adult_happy.png | 1254×1254 — FAIL | RGBA — PASS | [0, 0, 0, 0] — PASS |
| adult_sleep.png | 1254×1254 — FAIL | RGBA — PASS | [0, 0, 0, 0] — PASS |

All five fail the required dimensions. All five pass RGBA mode and transparent corners. Visual inspection shows the requested poses and rightward orientation, but subtle gradients remain. Alpha inspection also detects faint stray transparency outside the main silhouette. Shared y=860 alignment and completely flat fills are pending normalization approval. No original file in the destination folder was changed.
