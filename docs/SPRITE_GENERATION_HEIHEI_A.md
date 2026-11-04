# Hey! — Hei Hei hatchling and egg sprites (set A)

Created with the built-in image generation tool, one image per call, with `transparent_background: true`. These are baby **Hei Hei from Disney’s Moana** as private fan art for the owner’s desktop pet; no original-character fallback was used.

The master `Resources/Sprites/heihei/hatchling_idle.png` was opened and studied before generation. It supplies the round ochre hatchling, cream bib, brown wings and tail, scruffy tuft, enormous crossed eyes, orange beak/feet, pink side tongue, and thick warm dark-brown rounded outlines. The hatchling retains the master’s tuft instead of adding adult comb/wattle features.

## Files and reference chain

All five final PNGs are in `Resources/Sprites/heihei/` under the requested filenames. Walk, eat and happy use the idle master as their closest pose/design reference. Sleep uses the generated lowered eat pose. Egg uses the idle master only for outline and palette style; it has no face.

The tool returned 1254×1254 RGBA images. Pillow normalized the canvases to 1024×1024 using Lanczos resampling, then translated each sprite without changing scale again so its visible bottom rests at y=860 and its visible bounds are centered horizontally. Bounds were measured with alpha > 8 to ignore near-transparent generator noise. Alpha was preserved during canvas normalization. A shared ground line is not drawn. The sleep mark is the only requested lettering.

## Visual limitation awaiting cleanup

Despite explicit flat-fill prompts and two walk correction attempts, the generated art retains soft tonal variation. Therefore strict flat-fill compliance is not yet achieved. Permission for deterministic Pillow color cleanup has been requested because the image tool requires explicit authorization for Python image editing. The files below are currently the generated, canvas-normalized versions.

## Pillow verification

Corner order: top-left, top-right, bottom-left, bottom-right. These checks verify file format/transparency at the corners; they do not certify flat fills or exact character likeness.

| File | Size | Mode | Corner alpha | Result |
| --- | --- | --- | --- | --- |
| `hatchling_walk.png` | 1024×1024 | RGBA | [0, 0, 0, 0] | PASS |
| `hatchling_eat.png` | 1024×1024 | RGBA | [0, 0, 0, 0] | PASS |
| `hatchling_happy.png` | 1024×1024 | RGBA | [0, 0, 0, 0] | PASS |
| `hatchling_sleep.png` | 1024×1024 | RGBA | [0, 0, 0, 0] | PASS |
| `egg_idle.png` | 1024×1024 | RGBA | [0, 0, 0, 0] | PASS |

Failed requested file checks: none.

Previously existing files in the sprite folder changed: none (master hash unchanged).

## Exact prompts used

The walk correction attempts are included for reproducibility. Only the final selected walk is saved to the requested sprite folder.

### 1. hatchling_walk.png

Reference: hatchling_idle.png

```text
Use case: identity-preserve
Asset type: one PNG sprite hatchling_walk.png for the private macOS desktop-pet app Hey!
Primary request: Draw the WALK pose of the exact baby Hei Hei from Disney Moana shown in the reference master. Fan art for the owner's private desktop.
Input image: reference master hatchling_idle.png; preserve this same tiny round fluffy yellow-brown hatchling's identity, proportions, palette and drawing style.
Pose: facing RIGHT, mid-stride walking right, one short orange leg extended forward to the right with toes at the common baseline y=860, the other leg behind lifted slightly. Head and huge eyes bob slightly forward to the right. Stubby brown wings relaxed. Dopey expression, enormous bulging white cross-eyed eyes, tiny inward-pointing black pupils, orange right-pointing beak, pink tongue poking out the side.
Keep the hatchling design: big scruffy golden ochre head tuft instead of an adult comb, ragged fluffy ochre body, cream chest, brown stubby wings and messy tiny brown tail. Do not add adult rooster features.
Style: match the reference's thick warm dark-brown outline, round joins and simple feather shapes exactly; use entirely FLAT solid colour fills. Remove any gradient or mottled shading seen in reference. No gradients, texture, glow, cast shadow or ground.
Canvas: exactly 1024x1024 PNG RGBA with genuinely transparent background, alpha 0 everywhere outside art. One full-body creature centered horizontally with generous clear margins, same approximate height as master. Lowest grounded foot outline at y=860. Do not draw a ground line. No cropping.
No background color, checkerboard drawn into image, scenery, text, letters, watermark, border, corn or extra objects.
```

### 2. hatchling_walk.png — flat-fill correction

Reference: first generated walk

```text
Use case: identity-preserve
Edit target: attached walking baby Hei Hei sprite. Keep the exact existing bird, pose, crossed eyes, tongue, feather contours, thick warm dark brown rounded outline, composition and transparent background. Correct ONLY the color rendering: replace ALL shading, gradients, mottling, lighting and texture with perfectly uniform flat solid fills. This is a flat cartoon game sprite, like clean screenprinted spot colors. Golden plumage must be one uniform ochre #E9AC46 across head and body. Chest must be one uniform cream #F4D9A0. Wings and tail one uniform brown #A96640. Orange beak and legs one uniform #FFA814. Tongue one uniform pink #F77D91. Eyes solid white #FFFFFF. Pupils solid dark brown #160E0A. Outline solid warm dark brown #50301D, thick with round joins. No highlights, darker interior shading, gradients, grain or blended transitions anywhere; only antialiasing along edges.
Output one PNG exactly 1024x1024, genuinely transparent alpha 0 outside the bird. Reframe to put the sole of the forward grounded foot at y=860, centered with margin; no ground, shadow, scenery or text. Keep facing right, mid-stride, rear leg lifted, enormous goofy crossed eyes and tongue. This is the hatchling WALK pose of Disney Moana's Hei Hei, private fan art.
```

### 3. hatchling_walk.png — flat cel-art redraw

Reference: corrected generated walk

```text
Create a NEW flat cel-art drawing of the same hatchling walking right in the reference. Do not reuse or retain the reference's shaded pixels. Use the reference ONLY for character identity, outlines, proportions and walk pose. REDRAW every color region with one single SOLID spot color, like a vector sticker illustration. No lighting simulation. No gradients or soft tonal variation at all. Plain uniform cream chest, plain uniform golden ochre plumage, plain uniform reddish-brown wings and tail, plain uniform orange beak and feet, plain uniform pink tongue, plain white eyes, solid dark brown outlines and tiny pupils. The flat fills matter more than matching any reference shading.
This is the tiny round baby Hei Hei from Disney Moana as private fan art: huge crossed bulging eyes with tiny pupils pointing inward, orange beak pointing RIGHT, pink tongue out to the side, messy golden head tuft, round scruffy feathered body, cream chest, little brown wings and tail. Walk pose: head bobbed forward, forward right foot planted, other foot lifted behind. Thick warm dark-brown outline with round joins. One bird only.
One transparent PNG game sprite exactly 1024x1024. Full body horizontally centered with margin; tuft top about y=190, grounded forward sole exactly y=860. Transparent alpha 0 outside artwork; NO ground, shadow, glow, text or background.
```

### 4. hatchling_eat.png

Reference: hatchling_idle.png

```text
Use case: identity-preserve
Asset type: hatchling_eat.png, one transparent 2D game sprite for Hey!
Reference: hatchling_idle.png is the exact baby Hei Hei character design to preserve. Disney Moana fan art for private desktop use.
Draw the same tiny round fluffy ochre-yellow/brown hatchling in an unmistakable EAT pose: torso leans forward right and head bends all the way DOWN toward a single small golden corn kernel near his right toes. Beak points diagonally DOWN-RIGHT, almost touching the kernel. The enormous protruding white eyes remain comically crossed with tiny inward black pupils even though head is bent down. Tongue pokes from the side of the orange beak. Short orange legs both planted, tiny brown stubby wings held against body, brown messy tail at left, cream bib and scruffy ochre head tuft. Preserve the master chick's proportions, feather shapes, thick warm dark-brown rounded outline and same bird identity.
Render as FLAT cel art with uniform solid fills only: one golden ochre plumage color, one cream bib, one reddish-brown wing/tail color, one orange for beak and feet, one pink tongue, pure white eyes, dark pupils and thick warm dark-brown outlines. ABSOLUTELY NO gradients, soft shading, highlights, mottled texture, glow, lighting effects or cast shadow. Ignore the master's shading; copy only its shapes and colors.
Canvas exactly 1024x1024 transparent PNG RGBA, genuine alpha 0 outside artwork. Center full bird with generous transparent margin; keep feet on shared baseline y=860. Kernel beside toes on that same baseline. No drawn ground line or background. No text, watermark, scenery or extra objects. One baby bird and one tiny corn kernel only.
```

### 5. hatchling_happy.png

Reference: hatchling_idle.png

```text
Use case: identity-preserve
Asset type: hatchling_happy.png, one transparent PNG game sprite.
Reference: hatchling_idle.png is the exact character and outline style master. Draw that SAME tiny round fluffy baby Hei Hei from Disney Moana, private desktop fan art. Preserve scruffy ochre-yellow head tuft, round ochre body, cream chest, little brown wings and messy brown tail, orange short legs and feet, enormous bulging white cross-eyed eyes with tiny inward dark pupils. Right-facing three-quarter view.
Change pose to HAPPY: both little brown wings raised high and spread in mid-flap, joyful bouncy upright posture, big open silly orange-beaked grin with pink tongue hanging sideways out. Feet planted, full body visible. Keep tiny round chick proportions; no adult comb or wattle, no new accessories.
Use the master's THICK warm dark-brown outlines with round joins and ragged feather edges, but make ALL color fills perfectly FLAT, uniform, unshaded solid colors. One ochre for plumage, one cream for bib, one brown for wings/tail, one orange for beak/legs, one pink tongue, white eyes, dark brown tiny pupils and outline. No gradients, highlights, shadows, lighting, texture or glow.
Canvas exactly 1024x1024 PNG RGBA, fully transparent alpha 0 outside art. Bird centered with generous margins around raised wings and tuft. Soles on shared ground baseline y=860. No ground line or cast shadow. No motion lines, text, watermark, background or extra objects.
```

### 6. hatchling_sleep.png

Reference: hatchling_eat.png

```text
Use case: identity-preserve
Asset type: hatchling_sleep.png, one transparent PNG sprite for Hey!
Reference: use the attached lowered pecking hatchling as the nearest completed pose of the SAME bird, baby Hei Hei from Disney Moana, private desktop fan art. Preserve thick warm dark-brown rounded outlines, scruffy golden ochre feather shapes, cream chest, tiny reddish-brown wings and tail, orange beak, pink side tongue, big goofy head and messy golden tuft.
Change to SLEEP: tiny round fluffy hatchling curled up SITTING low, resting on its belly at y=860, legs tucked under with tiny orange toes resting on the same baseline. Head droops gently to the RIGHT, beak pointing right, both huge eye shapes have closed eyelids with simple dark curved closed-eye lines, sleepy peaceful expression; tongue still pokes out the side of beak. Small wings tucked around body. Tail at left. Clearly asleep, not pecking. Remove the corn kernel entirely.
Above the head place a TINY unobtrusive warm dark-brown 'Zzz' sleep mark. This is the only permitted text.
Match reference proportions and feather design but use only perfectly uniform FLAT spot colors: golden ochre body and tuft, cream bib, brown wings and tail, orange beak and tiny feet, pink tongue, dark warm-brown outlines. Closed eyelids golden ochre. No gradient, shading, highlights, texture, glow or cast shadow.
Output exactly 1024x1024 PNG RGBA, actual alpha 0 outside art. One sleeping chick centered with generous clear margins and small Zzz above. Lower silhouette/toes at shared y=860. No drawn ground line, background, scenery, bed, pillow, corn, other text or extra objects.
```

### 7. egg_idle.png

Reference: hatchling_idle.png (style only)

```text
Use case: stylized-concept
Asset type: egg_idle.png, single transparent PNG game sprite for the baby Hei Hei pet in Hey!
Reference image: hatchling_idle.png is STYLE REFERENCE ONLY for outline weight and warm palette. Do not draw any bird. Draw ONE simple upright unhatched cream egg, narrower rounded top and wider rounded bottom, with just a few small scattered brown speckles. Plain shell. No face, eyes, beak, tongue, feathers, wings, legs, cracks, decorations or accessories.
Match the reference's thick warm dark-brown outline and round joins exactly. Entire shell a single uniform flat cream color, with flat brown speckles. NO shading, highlights, gradients, texture, glow, lighting or cast shadow. Clean simple flat 2D cel-art game sprite.
Canvas exactly 1024x1024 PNG RGBA with truly transparent alpha 0 background. Egg centered horizontally, full egg visible with generous margin, about 380 pixels wide and 530 pixels tall; bottom rests on the same invisible baseline at y=860. Do not draw a ground line. No scenery, nest, ground, text, watermark, border or background color. ONE egg only.
```
