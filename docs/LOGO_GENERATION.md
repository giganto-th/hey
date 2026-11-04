# Hey! logo generation

Generated 2026-11-03 using the built-in `image_gen.imagegen` tool, one asset at a time. No CLI/API fallback was used. Hei Hei was accepted by name; an original-character fallback was not needed.

## Deliverables

- `Resources/Logo/heihei_head.png`: transparent colour head master.
- `Resources/Logo/heihei_icon.png`: head on teal rounded-square tile with shadow.
- `Resources/Logo/heihei_mark.png`: black alpha-mask glyph, transparent eye holes, black pupils, no tongue.

## Inputs inspected before generation

1. `/private/tmp/claude-501/-Users-cdimac-myProject-Hey-/261330fb-7b94-4da6-aa60-39d779ae461d/images/2.webp`: character reference. Crooked jagged red comb, large bulging eyes, yellow-orange beak, red wattle.
2. `Resources/Sprites/heihei/adult_idle.png`: supporting style reference.
3. `Resources/Sprites/heihei/hatchling_idle.png`: supporting style reference.

The two sprites supplied the thick warm brown outlines, rounded joins, cute sticker proportions and tongue-out expression. The requested flatter treatment was specified explicitly in the prompts.

## Head: initial generation

All three input images were supplied in the order above. `transparent_background: true`.

```text
Use case: logo-brand.
Asset type: 1024x1024 transparent PNG master logo for the personal macOS desktop-pet app Hey!.
Input images: Image 1 is the character reference: Hei Hei from Disney Moana, showing the crooked red jagged comb and bulging eyes. Images 2 and 3 are supporting STYLE references: the existing adult and hatchling app sprites with thick warm dark-brown outlines and goofy tongue-out expression.
Primary request: Draw ONLY the HEAD of Hei Hei, front-facing with a slight playful head tilt, as cute 2D sticker art. Preserve his recognizable dim-witted cross-eyed rooster character.
Subject details: a tall crooked RED comb with several irregular jagged lobes, two HUGE bulging WHITE eyes with tiny solid BLACK pupils turned inward toward each other, a YELLOW-ORANGE beak, RED hanging wattle, and a little PINK tongue visibly sticking out of the SIDE of the beak. A small warm golden head/cheek area is fine, but stop entirely at the bottom of the wattle: absolutely NO neck below the wattle and NO body. Eyes and crooked comb dominate the silhouette.
Style: thick consistent warm DARK-BROWN outline with smooth round joins, flat solid colour fills, at most ONE flat darker shading shape total. Clean large readable shapes that remain recognizable at 64 pixels. Match the cute existing sprites but simplify their feather detail for a logo. No white sticker border.
Composition: one head centered on a square canvas, approximately 80% of the canvas height, balanced generous transparent margins, no clipping.
Background: genuinely transparent RGBA, alpha 0 everywhere outside the artwork. No checkerboard or coloured background drawn in.
Avoid: gradients, texture, glow, shadows, lighting, 3D, text, letters, watermark, borders, neck, chest, shoulders, wings, body, feet, multiple heads.
```

The initial result had pupils that were too large and a tighter crop. It was refined with the following prompt, using that generated head as the edit target.

## Head: final refinement prompt

`transparent_background: true`.

```text
Use case: precise-object-edit.
Edit target: the supplied transparent Hei Hei rooster head logo.
Keep the same recognizable character, tilted front-facing pose, tall crooked jagged red comb, huge white bulging eyes, warm thick dark-brown round outline, yellow-orange beak, red wattle, and pink tongue sticking out to the side. Keep HEAD ONLY, no neck or body.
Change only these finishing details:
1. Make every colour region a truly UNIFORM FLAT SOLID FILL. Absolutely NO gradients, lighting variation, highlights, texture or shading in the red comb, wattle, yellow beak, cheeks, tongue or white eyes. Pure white eye fill. One uniform warm dark-brown outline colour. Clean flat vector sticker illustration, not a rendering.
2. Make both pupils tiny black dots, around 12% of each eye's diameter, still clearly turned inward, cross-eyed.
3. Make the head smaller within the transparent square canvas: all art centered, from about y=102 to y=922 on a 1024x1024 canvas (80% canvas height), generous transparent margin on every side, no stray pixels.
Deliver one 1024x1024 RGBA PNG with true transparent background, alpha 0 outside the head. No text, background, shadows, tile, body or neck.
```

Selected generated source: `/Users/cdimac/.codex/generated_images/01a1a0fd-5813-7210-880e-220ef258c7a8/exec-5380b2fb-1055-41f1-a3c7-17e98b0f7e3e.png`.

## Icon: final prompt

Reference/edit input: the saved `Resources/Logo/heihei_head.png`, inspected before this call. `transparent_background: true`.

```text
Use case: compositing.
Asset type: finished macOS app icon, 1024x1024 PNG RGBA.
Input image: the supplied heihei_head.png is the EXACT MASTER HEAD to place on the icon. Preserve the head identically: same silhouette, slight tilt, comb lobes, eye shapes, tiny inward black pupils, beak, tongue, wattle, thick warm dark-brown outline, flat fills and proportions. Do not redesign or redraw the character.
Primary request: place this same head centered on one clean Apple-style squircle tile. The tile occupies the central 80% of the square canvas, approximately x=102..922 and y=102..922, with Apple macOS-style continuous rounded corners (large radius about 180px), front-on with no perspective. The head should fit comfortably inside the tile with modest padding, retaining its exact original pose and proportions, approximately 680px tall. No neck or body.
Tile colour: smooth vertical teal gradient from exactly #6BD1BE at the top to #2A8F84 at the bottom. The gradient belongs ONLY on the tile; keep the mascot's fills flat. Add a subtle soft neutral shadow directly below the tile, still within the canvas margins. No bevel, extrusion, reflection, gloss or glow.
Backdrop: actual TRANSPARENT alpha 0 outside the squircle and its soft shadow. Wide transparent margin around tile. All four corner pixels must have alpha 0. Do not draw checkerboard, white, grey or black background.
Constraints: one icon, no text, no letters, no watermark, no frame, no extra elements.
```

Selected generated source: `/Users/cdimac/.codex/generated_images/01a1a0fd-5813-7210-880e-220ef258c7a8/exec-e6e44d7f-76dd-47eb-8790-424a09784ebd.png`.

## Mark: final prompt

Reference/edit input: the saved `Resources/Logo/heihei_head.png`. `transparent_background: true`.

```text
Use case: precise-object-edit.
Asset type: single-colour macOS menu-bar glyph, 1024x1024 RGBA PNG.
Edit target: the supplied heihei_head.png is the MASTER geometry.
Primary request: convert this EXACT head into a pure black silhouette with two transparent eye holes and tiny black pupils inside them. Keep the same pose, size and placement as the reference image: same slightly tilted head, same tall crooked comb with identical jagged lobes, same beak and cheek silhouette, same red wattle outline now all solid black, same eye shapes and tiny inward-pointing pupil positions. Do not restyle, reframe, center differently, scale, or redesign. The original artwork fills about 80% of the canvas height.
Change only: every visible shape becomes PURE BLACK #000000. Both large WHITE eye interiors must instead be fully TRANSPARENT CUT-OUTS, alpha 0, not white fill. Keep the two tiny pupils as detached PURE BLACK dots inside the transparent eye holes. Remove the tongue completely; merge the remaining beak area into a thick simple uninterrupted silhouette.
The whole head is one bold black shape plus two black pupil dots. No internal beak lines, no outline details, no feather lines, no shading, no colours, no tongue, no gradients, no shadow, no background tile. Pure transparent background alpha 0 outside the silhouette and in both eye holes. Antialiasing at contour edges only. No text or watermark.
Deliver exactly one transparent PNG, square 1024x1024.
```

Selected generated source: `/Users/cdimac/.codex/generated_images/01a1a0fd-5813-7210-880e-220ef258c7a8/exec-f638a88d-7b6f-4b41-a4ba-af252f6fe51c.png`.

## File normalization and verification

The tool returned 1254×1254 RGBA PNGs despite the requested dimensions. Pillow resized each selected output to exactly 1024×1024 with Lanczos resampling. Original generated files were preserved. The generated mark contained nearly black pixels (RGB values up to 5); its RGB channels were normalized to exactly (0, 0, 0), preserving its generated alpha channel and all contour geometry.

Pillow verified exactly three files in `Resources/Logo/`, all PNG, all RGBA, all 1024×1024:

| File | Mode | Size | Corner alpha: TL, TR, BL, BR |
| --- | --- | --- | --- |
| heihei_head.png | RGBA | 1024×1024 | 0, 0, 0, 0 |
| heihei_icon.png | RGBA | 1024×1024 | 0, 0, 0, 0 |
| heihei_mark.png | RGBA | 1024×1024 | 0, 0, 0, 0 |

Additional mark checks passed: every pixel has RGB (0, 0, 0), eye-interior samples (360, 530) and (590, 600) have alpha 0, and both pupil samples (454, 538) and (508, 582) have alpha above 240. The head and mark's visible bounds occupy approximately 75% of canvas height, close to the requested 80%.

Visual QA used a light-background contact sheet at 240 px and 64 px. The large eye shapes and crooked comb remain recognizable at 64 px. No text, body, or neck below the wattle is present.

## Known limitations

- File-format, dimension, corner-transparency and exact-black glyph checks passed.
- The image model retained slight tonal variation in the colour fills despite the flat-fill refinement prompt. These are not mathematically uniform vector fills.
- The icon's teal gradient is an approximate rendering of the requested hex endpoints, not an exact numeric #6BD1BE-to-#2A8F84 ramp.
- Both derivatives used the final master as their reference and closely preserve its pose and features. Image generation introduced small contour/proportion differences; the icon head and glyph are not pixel-identical copies of the master.


## Revision 2 (2026-11-03)

Redrawn with Codex from the user's new reference (crimson jagged comb, lilac bulging eyes with purple lids, orange beak, yellow-orange neck fuzz). `head.png` and `mark.png` come straight from the generator; the app tile was composed locally (navy-teal gradient, soft shadow) because the generated tile had a stray smudge. `Resources/AppIcon.icns` rebuilt with `scripts/make-icon.sh`; the menu-bar glyph now loads `heihei_mark.png`. Previous art is kept outside the repo in `/tmp/old_logo` only for this session.
