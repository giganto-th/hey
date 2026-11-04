# Hei Hei child sprite generation — B

Created: 2026-11-03

## Subject and method

Hei Hei from Disney Moana, drawn as a scruffy half-grown chick-rooster for the owner's private Hey! desktop-pet app. The named character was accepted; the original-rooster fallback was not used.

Generated with the built-in image generation tool, one image at a time, in this order: idle, walk, eat, happy, sleep. Idle had one refinement before the remaining poses. The existing master `Resources/Sprites/heihei/hatchling_idle.png` was opened and studied first. Each generation used the closest existing same-bird reference listed with its prompt. All later poses use the finalized child idle so stage, features, palette, and proportions stay consistent.

The generated source images were 1254×1254 despite the requested 1024×1024. Final PNGs were normalized with native Swift/CoreGraphics: uniform rescaling to 1024×1024, horizontal artwork centering, and translation to an invisible ground line at y=860. Uniform palette mapping removed the source gradients; antialiasing remains at contours. Low-alpha background residue and isolated tiny artifacts were removed while retaining the corn kernel and sleep lettering. No shadow, ground, or background was added.

Flat palette: warm dark brown #402618, pupil black #100C08, ochre #E6A134, cream #F9E1B9, red-orange #E7512B, orange #FF9F07, feather brown #A16142, eye white #FFFEFA, tongue pink #F97A8B, corn yellow #F3D223.

Only the five requested sprite files were written in `Resources/Sprites/heihei/`. The pre-existing master was verified byte-for-byte unchanged with SHA-256.

## Final files and Pillow verification

All five files passed Pillow verification: PNG format, 1024×1024 pixels, RGBA mode, and alpha 0 at all four corner pixels. No failures.

Bounding boxes below use Pillow's exclusive right and bottom convention. The final antialiased lower contour reaches row 860; the solid contour ends at approximately row 859. The eat pose's toes are within two pixels of this line, beside the kernel.

| File | Dimensions | Mode | Corner alpha (TL, TR, BL, BR) | Nonzero-alpha bounding box | Result |
| --- | --- | --- | --- | --- | --- |
| child_idle.png | 1024×1024 | RGBA | 0, 0, 0, 0 | (309, 142, 716, 861) | PASS |
| child_walk.png | 1024×1024 | RGBA | 0, 0, 0, 0 | (224, 166, 801, 861) | PASS |
| child_eat.png | 1024×1024 | RGBA | 0, 0, 0, 0 | (192, 422, 833, 861) | PASS |
| child_happy.png | 1024×1024 | RGBA | 0, 0, 0, 0 | (225, 139, 799, 861) | PASS |
| child_sleep.png | 1024×1024 | RGBA | 0, 0, 0, 0 | (290, 343, 735, 861) | PASS |

Visual inspection confirmed right-facing poses, the child design, crossed eyes in awake poses, a downwards peck at one kernel, raised happy wings with open-beaked grin, and seated sleep with closed eyes, tongue, and tiny Zzz. Flat fills, warm brown rounded outlines, and transparent margins are preserved.

## Exact prompts

Every call set `transparent_background: true`.

### 1. child_idle.png

Reference: `Resources/Sprites/heihei/hatchling_idle.png`.

```text
Use case: style-transfer.
Asset type: one transparent PNG desktop-pet sprite, child_idle.png, 1024x1024.
Input image 1 is the master hatchling of this exact bird. Study and match its thick warm dark-brown rounded outlines, simple ragged feather shapes, expressive giant bulging white crossed eyes with tiny black pupils, orange beak and legs, brown wings, cream chest, and pink tongue. Generate Hei Hei from Disney Moana as a CHILD (scruffy half-grown chick-rooster) in this master illustration style, fan art for a private desktop pet.
Primary request: child IDLE, standing dopey facing RIGHT, beak points right, huge cross-eyed eyes, tongue hanging out of side of orange beak. Taller and lankier than the hatchling: longer spindly orange legs and elongated scruffy brown-ochre body, cream chest, patchy feathers, small newly emerging red-orange comb and wattle, short messy brown tail tuft. Keep youthful half-grown proportions, not an adult long rooster tail.
Composition: full single creature centered with generous transparent margin. Canvas exactly 1024x1024. Feet bottom edges resting on shared invisible baseline y=860, with 164 pixels clear below. Top of comb around y=130. No visible baseline.
Style: ONLY flat solid color fills, thick warm dark-brown outlines with round joins, ragged feather edges. Flatten the shading seen in master; no gradients, highlights, textures, glow, cast shadow, ground, background, text, border, props, watermark. Genuinely transparent RGBA background, alpha zero outside art, no checkerboard drawn into image. One sprite only.
```

### 2. child_idle.png — refinement

Reference: `first child idle generation`.

```text
Use case: precise-object-edit.
Asset: child_idle.png, single 1024x1024 transparent RGBA sprite.
Edit the provided rooster into the CHILD stage of Hei Hei from Disney Moana for private fan art. Keep the exact giant crossed eyes, tiny pupils, tongue poking from right-facing orange beak, dark-brown rounded outlines, brown wings, ochre scruffy feathers and cream chest.
Two corrections: (1) Make him a scruffy HALF-GROWN chick-rooster with a small emerging red-orange comb only about one-third the current comb size, little wattle, shorter neck and shorter legs than this overly adult-looking bird, a fuller youthful body and short tail tuft. Still taller than the round hatchling. (2) Use strictly UNIFORM SOLID FLAT COLOUR inside every outlined area. Completely remove all gradient shading, mottling, lighting, highlights and texture from eyes, plumage, comb, beak, legs and wings. Each fill should be one even colour like a flat vector cartoon cel, no soft color transitions anywhere.
Pose stays IDLE standing dopey, face and beak facing RIGHT.
Composition exactly square 1024x1024, full body centered around x512 with clear margins. Feet bottom at y860, top near y150. Actual transparent background with alpha zero outside artwork, no faint stray marks or cloudy background. No shadow, glow, ground, text, props or watermark. Preserve thick warm dark-brown rounded outline and ragged feather contours.
```

### 3. child_walk.png

Reference: `Resources/Sprites/heihei/child_idle.png`.

```text
Use case: precise-object-edit.
Asset type: child_walk.png, single transparent 1024x1024 desktop-pet sprite.
Input image 1 is the finalized child_idle sprite of Hei Hei from Disney Moana (private fan art). It is the exact character/stage/style reference. Keep this SAME half-grown rooster: identical head and eye proportions, small red-orange comb and little wattle, ochre patchy ragged plumage, cream chest, brown wings and short tail tuft, thick warm dark-brown outline with rounded joins, orange beak and spindly legs, pink tongue.
Change ONLY pose to WALK: facing RIGHT, mid-stride with one leg stretched forward to the right and the other leg back, head and neck bobbing forward to the right, huge bulging eyes still crossed with tiny pupils and dopey tongue poking out of side of beak. Full body, clearly walking, not standing. Keep same youthful build and apparent sprite scale as reference; comb top around y150 and lowest foot at y860.
Flat solid fills only, each enclosed region one uniform colour, NO gradients, glow, texture or cast shadow. Match the flat palette of reference exactly.
Composition: canvas 1024x1024, creature centered with margin and transparent space below the feet, lowest foot on shared invisible baseline y860. Genuine RGBA transparency alpha0 outside art. No ground, baseline, background, motion marks, props, text, frame or watermark. One sprite only.
```

### 4. child_eat.png

Reference: `Resources/Sprites/heihei/child_idle.png`.

```text
Use case: precise-object-edit.
Asset type: child_eat.png, one transparent 1024x1024 desktop-pet sprite.
Input image 1 is the finalized child_idle sprite of Hei Hei from Disney Moana, private fan art. This is the exact closest same-stage character reference. Preserve its half-grown youthful build, small red-orange comb and wattle, giant bulging white crossed eyes with tiny black pupils, scruffy ochre/brown feathers, cream chest patch, brown wings, short messy tail tuft, pink tongue, orange beak and thin orange legs, thick warm dark-brown rounded outlines. Keep all these character features consistent.
Change pose to EAT: right-facing bird bending its neck sharply down, body leaning forward, orange beak pecking down at ONE small yellow corn kernel just in front of it at the right. Eyes must remain visibly huge and crossed, following the kernel; pink tongue still peeks out at side of beak. Both orange feet support the body, right side view. No extra food or props.
Keep sprite scale consistent with reference: head and eyes same size, legs same length, lower silhouette naturally compact from bending. Feet bottom edges on invisible shared ground line y860, kernel rests at same line. Full bird centered with transparent margin. Exactly 1024x1024 PNG, actual transparent RGBA background alpha0 outside art.
Match flat palette exactly. Strictly solid uniform colour fills, thick warm dark-brown outlines with round joins, ragged feather edges; NO gradients, shading, texture, glow, cast shadow, ground, visible baseline, background, text or watermark. One sprite only.
```

### 5. child_happy.png

Reference: `Resources/Sprites/heihei/child_idle.png`.

```text
Use case: precise-object-edit.
Asset type: child_happy.png, single transparent 1024x1024 desktop-pet sprite.
Input image 1 is finalized child_idle: exact character design, stage, palette, scale and outline reference of Hei Hei from Disney Moana for private fan art. Keep this same scruffy half-grown chick-rooster with giant bulging cross-eyed white eyes and tiny pupils, small emerging red-orange comb and wattle, ochre patchy plumage, cream chest, brown wings and short tail tuft, thin orange legs, orange beak, pink tongue. Thick warm dark-brown outline, rounded joins and ragged feather edges.
Change ONLY pose and expression to HAPPY: standing facing RIGHT, BOTH brown wings raised high and spread in a flapping pose, big silly open-beaked grin and tongue hanging out, eyes still crossed, joyful dopey expression. Feet grounded, no jump. Keep eyes same size and head/body proportions as reference. Short child tail, no long adult feathers.
Exactly 1024x1024 canvas. Full bird centered with generous transparent margins, feet bottom on invisible shared baseline y860, comb top around y150, raised wings fully within frame.
Strictly FLAT SOLID UNIFORM fills, no gradients, lighting or shading, matching reference flat colours. Genuine RGBA transparency alpha0 outside artwork. No ground, shadow, glow, background, motion marks, props, words, frame or watermark. One bird only.
```

### 6. child_sleep.png

Reference: `Resources/Sprites/heihei/child_idle.png`.

```text
Use case: precise-object-edit.
Asset type: child_sleep.png, single transparent 1024x1024 desktop-pet sprite.
Input image 1 is finalized child_idle of Hei Hei from Disney Moana, private fan art, exact closest same-stage character reference. Keep the same half-grown scruffy chick-rooster design, small emerging red-orange comb and small wattle, ochre patchy ragged feathers, cream chest, brown wings and short messy tail tuft, orange beak and thin orange feet, pink tongue. Same thick warm dark-brown outlines, rounded joins, flat palette and feather edges.
Change ONLY pose to SLEEP: curled up SITTING on its folded legs, relaxed compact body, head lowered and nuzzled toward chest, face and orange beak point RIGHT. Huge rounded eye shapes now closed with simple curved dark-brown eyelid lines, tongue still poking out of side of beak. Wings folded snugly. A small glimpse of tucked orange toes at bottom, resting at invisible baseline y860. Keep head and body size consistent with reference; lower height results from curling up.
Add only a tiny hand-drawn dark-brown “Zzz” above head, one Z and two lowercase z, no speech bubble. This tiny sleep mark is the ONLY permitted text.
Composition exactly 1024x1024, full single bird centered horizontally with margin and transparent space all around, sitting bottom / toes at y860, no ground or shadow. Genuine RGBA transparency alpha0 everywhere outside bird and Zzz.
Strictly solid uniform flat color fills, no gradients, shading, glow, texture or lighting. No background, props, ground line, other text, border or watermark.
```


