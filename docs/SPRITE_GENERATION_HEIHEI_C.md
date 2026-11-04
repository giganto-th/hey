# Hey! — teen rooster sprite generation, part C

Date: 2026-11-03.

## Delivered files

All five images are saved in `Resources/Sprites/heihei/`:

- `teen_idle.png`
- `teen_walk.png`
- `teen_eat.png`
- `teen_happy.png`
- `teen_sleep.png`

Generated individually, in that order, with the built-in image generation tool, using `transparent_background: true`. No CLI/API fallback was used.

The master `Resources/Sprites/heihei/hatchling_idle.png` was opened and studied before generation. It supplied the warm dark-brown rounded outline, ochre/brown/cream palette, oversized crossed eyes, orange beak and legs, pink tongue, and ragged feather shapes. The adolescent design adds a narrow torso and neck, long legs, a large crooked red-orange comb, a wattle, and longer ragged tail feathers. All prompts explicitly request uniform flat fills and forbid gradients, glow, ground, and cast shadows. Sleep has the requested tiny Zzz; eat has one corn kernel.

**Subject wording:** The idle sprite was generated as named Hei Hei fan art for the owner's private desktop. The named walk request was rejected by input moderation (category `other`, without a specific explanation). Following the user's explicit fallback, walk, eat, happy, and sleep were prompted as an **original goofy cartoon rooster**, retaining the saved teen bird as the visual reference.

## Reference chain and export

- Idle: hatchling master → initial teen idle draft → corrected teen idle.
- Walk: saved teen idle.
- Eat: saved teen walk, the closest existing forward-leaning pose.
- Happy: saved teen idle, the closest existing standing pose.
- Sleep: saved teen eat, the closest existing bent-neck pose.

Every selected output was visually reviewed. The built-in outputs required export normalization: native macOS CoreGraphics removed nearly transparent background noise (alpha ≤ 8), trimmed the remaining alpha bounds, uniformly resized the art without stretching, centered it on a clear 1024×1024 canvas, and placed the bottom art row at y=860. Python/Pillow was used for inspection and verification, not painting. Standing poses retain more height; bent eating and curled sleeping poses have shorter silhouettes.

Generated originals remain in the tool's default directory:

`/Users/cdimac/.codex/generated_images/01a1a097-de5a-7763-bd07-74852c4c69b1/`

| Final file | Selected generated source | Export art height |
| --- | --- | ---: |
| `teen_idle.png` | `exec-ec847e50-1d71-4d74-a5e7-04e6197b6efd.png` | 691 px |
| `teen_walk.png` | `exec-9ee1f7aa-232a-41e4-bdd8-5920eb7a97e4.png` | 650 px |
| `teen_eat.png` | `exec-360eb20c-4db6-4728-8ca7-57d9c6bfc02a.png` | 420 px |
| `teen_happy.png` | `exec-59078ca6-780b-4f8a-95c9-d3e846dc4815.png` | 691 px |
| `teen_sleep.png` | `exec-381a9169-de59-42c8-a9dc-334fc248ae07.png` | 430 px |

## Pillow verification

All five saved files passed. **Failed files: none.**

| File | Format | Dimensions | Mode | Corner alpha (TL, TR, BL, BR) | Alpha bounding box¹ | Bottom art row | Result |
| --- | --- | --- | --- | --- | --- | ---: | --- |
| `teen_idle.png` | PNG | 1024×1024 | RGBA | 0, 0, 0, 0 | (310, 170, 713, 861) | 860 | PASS |
| `teen_walk.png` | PNG | 1024×1024 | RGBA | 0, 0, 0, 0 | (259, 211, 764, 861) | 860 | PASS |
| `teen_eat.png` | PNG | 1024×1024 | RGBA | 0, 0, 0, 0 | (144, 441, 879, 861) | 860 | PASS |
| `teen_happy.png` | PNG | 1024×1024 | RGBA | 0, 0, 0, 0 | (246, 170, 778, 861) | 860 | PASS |
| `teen_sleep.png` | PNG | 1024×1024 | RGBA | 0, 0, 0, 0 | (180, 431, 843, 861) | 860 | PASS |

¹ Bounding box uses Pillow's exclusive right and bottom coordinates. Every pixel below y=860 has alpha 0. The outer margins and all four corners are transparent.

The only pre-existing file in the sprite folder at the start was `hatchling_idle.png`. Its SHA-256 remained unchanged:

`d0e644487ad35893ec1d3e0114664fae366aea5c4773988e6768ab6fe973724a`

No other pre-existing sprite file was modified. Scratch/export utilities and verification data were kept outside the project.

Verification used `PIL.Image.open` and `load()`, checked `format == "PNG"`, `size == (1024, 1024)`, `mode == "RGBA"`, all four corner alpha values equal to 0, alpha bounding-box bottom equal to 861, and alpha extrema below y=860 equal to (0, 0).

## Exact prompts and outcomes

Each prompt below was passed verbatim to the built-in image generation tool, together with the listed reference image and `transparent_background: true`.

### Attempt 1: teen_idle.png

Reference: `Resources/Sprites/heihei/hatchling_idle.png`.

Outcome: Generated initial teen idle draft; superseded by attempt 2 to reduce inherited shading.

```text
Use case: stylized-concept.
Asset type: single transparent PNG desktop-pet sprite for the personal macOS app Hey!, 1024x1024.
Reference image: the supplied hatchling_idle.png is the master for the same character and art style. Create an older TEENAGE Hei Hei, the goofy dim-witted cross-eyed rooster from Disney Moana, fan art for the owner's private desktop.
Primary request: teen_idle.png, standing in a dopey idle pose, facing RIGHT in the same three-quarter side orientation as the reference. Make this unmistakably an adolescent rooster, lanky narrow torso and neck, long spindly orange legs, bigger crooked red-orange comb, red-orange wattle distinct from the pink tongue, scruffy ragged tail feathers sweeping back to the left. Keep the enormous bulging white crossed eyes with tiny black pupils looking toward the orange beak, silly pink tongue poking out from the side of the beak. Brown-ochre plumage, cream chest, brown wings and messy brown tail feathers. Visually the same bird grown older.
Style: exactly match the master's thick warm dark-brown outlines, smooth round joins, flat simple cartoon shapes with ragged feather edges. Use ONLY solid flat color fills. Remove all the master's gradient shading; no gradients, texture, lighting, shine, glow, or shadows.
Composition: one creature centered with generous clear margin, full body entirely visible, 1024x1024 square. Feet rest on a shared invisible ground line at y=860 pixels, toes' bottom outline at y=860. Top of comb roughly y=170. Long legs visibly separate the body from the ground. Beak points to the RIGHT.
Background: genuinely transparent, alpha 0 everywhere outside the artwork. No background color, checkerboard graphic, ground, ground line, cast shadow, scenery, extra object, lettering, or watermark. No text. Generate just this one idle sprite.
```

### Attempt 2: teen_idle.png

Reference: `generated teen idle initial draft`.

Outcome: Selected teen idle artwork; exported as teen_idle.png.

```text
Use case: precise-object-edit. Correct this teen_idle sprite of Hei Hei from Disney Moana for a flat-color 2D desktop pet. Reference/edit target: supplied teen idle bird. Preserve this exact teenage bird design, standing pose, right-facing orientation, huge crossed eyes, tiny pupils, tongue, comb shape, wattle, lanky proportions, long legs, and tail.
Change only rendering and canvas spacing: use SOLID UNIFORM FLAT COLOR inside every shape, like a flat vector sticker. Ochre feathers one uniform ochre; brown feathers one uniform brown; cream chest one uniform cream; comb and wattle one uniform red-orange; beak and feet one uniform orange; tongue one uniform pink; eyeballs pure white. The prior image has gradient shading, especially comb and tail: REMOVE ALL GRADIENTS and textured shading. Thick uniform warm dark-brown outlines with rounded joins and ragged feather silhouettes. No highlights, shadows, glows, texture, lighting, ground, or background.
Canvas 1024x1024 transparent PNG. Scale and place the full bird in centered composition, leave generous clear margin all around. Top comb around y=170 and bottom of planted toes exactly y=860. Transparent empty canvas below y=861 and above y=160. Genuine alpha transparency outside art. No text or extra objects.
```

### Attempt 3: teen_walk.png

Reference: `Resources/Sprites/heihei/teen_idle.png`.

Outcome: Rejected at input moderation with category 'other'; no image generated. The tool did not provide a more specific reason.

```text
Use case: stylized-concept. Asset: one 1024x1024 transparent PNG desktop-pet sprite, teen_walk.png.
Reference: supplied teen_idle.png is the exact teenage Hei Hei rooster from Disney Moana to match. Preserve this same bird's lanky teenage proportions, long spindly orange legs, narrow ochre feathered neck and body, cream chest, oversized crooked red-orange comb and separate red-orange wattle, messy brown tail and brown wings, enormous bulging crossed white eyes with tiny black pupils, orange beak, pink tongue poking sideways out.
Change pose to WALKING toward the RIGHT: full body mid-stride, one long leg stepping forward to the right with toes planted at ground level, the other leg extended back to the left with heel lifted; head bobbing forward, neck tilted forward, wings relaxed. Keep it visibly teenage, same age and design as reference.
Art style: thick warm dark-brown outlines with round joins, ragged feather silhouettes, clean flat cartoon color fills. Every fill one uniform solid color, absolutely no gradients or shading or textures. Preserve reference palette and outline thickness. No lighting, glow, motion blur, cast shadow, or ground.
Full bird centered in square canvas with margin on all sides. Face RIGHT, tail to LEFT. Ground-contact foot bottom at y=860, invisible ground. Keep body scale consistent with reference: total standing height about 690px; stride can widen silhouette, forward-bobbing head can lower the top. Fully transparent background, alpha 0 outside the bird. No background, checkerboard pattern, scenery, labels, lettering, watermark, or other object. Only one walking bird, no sequence or sheet.
```

### Attempt 4: teen_walk.png

Reference: `Resources/Sprites/heihei/teen_idle.png`.

Outcome: Selected teen walk artwork using the user's original-goofy-rooster fallback.

```text
Use case: stylized-concept. Asset: one transparent PNG cartoon desktop-pet sprite, 1024x1024, teen_walk.png.
The supplied image is the visual reference: an original goofy teenage cartoon rooster. Match the same bird: lanky narrow torso and neck, long spindly orange legs, huge bulging cross-eyed white eyes with tiny black pupils, orange beak with pink tongue poking out the side, crooked red-orange comb and wattle, scruffy brown-ochre feathers, cream chest, brown wings, messy brown tail.
Draw this rooster WALKING to the RIGHT, mid-stride with one leg forward to the right and the other leg back to the left. The forward foot is planted, the back heel lifted. Head bobbing forward with the neck tilted forward. A funny vacant expression with crossed eyes. Keep the character design, age, scale, colors, and thick warm dark-brown rounded outlines consistent with the reference.
Flat 2D cartoon sprite, ragged feather edges, ONLY uniform solid color fills, no gradients, shading, textures, glow, cast shadow, or ground.
One complete bird centered with clear margin, facing right. Full planted foot bottom on invisible y=860 ground line, full creature about 650-690 pixels high. Genuinely transparent background, alpha zero outside the artwork. No background, scene, checkerboard graphic, lettering, logo, watermark, or extra object.
```

### Attempt 5: teen_eat.png

Reference: `Resources/Sprites/heihei/teen_walk.png`.

Outcome: Selected teen eat artwork using the original-goofy-rooster fallback.

```text
Use case: stylized-concept. Asset: one transparent PNG desktop-pet sprite, teen_eat.png, canvas 1024x1024.
Reference image: the supplied teen_walk.png is the exact original goofy teenage cartoon rooster whose design must stay consistent. Same lanky long-legged adolescent, brown-ochre feathering, cream chest, brown wings and ragged tail, large crooked red-orange comb, distinct red-orange wattle, huge bulging crossed white eyes with tiny pupils, orange beak, pink tongue poking out sideways. Same thick warm dark-brown rounded outlines and ragged feather contours.
Change pose to EATING: both long spindly orange legs planted, body leaning forward toward the RIGHT, long neck curved downward, head lowered with beak pointing down and right toward one tiny yellow corn kernel beside the right foot. Crossed eyes stay wide open, pupils converge on the tiny kernel. Tongue still pokes from side of beak. Tail extends back to the LEFT. One single small kernel only.
Flat 2D cartoon, solid UNIFORM color in every region, NO gradients, shading, highlights, texture, glow, shadows, or ground. Match reference colors and outline weight.
Entire bird and kernel centered with clear margin, no cropping. Same scale as reference, total silhouette shorter because head is bent downward. Feet and kernel sit on invisible shared line y=860. All outside art genuinely transparent alpha 0. No colored background, checkerboard graphic, scenery, cast shadow, other objects, text, logos, or watermark. Only one eating bird and one small corn kernel.
```

### Attempt 6: teen_happy.png

Reference: `Resources/Sprites/heihei/teen_idle.png`.

Outcome: Selected teen happy artwork using the original-goofy-rooster fallback.

```text
Use case: stylized-concept. Asset: teen_happy.png, single 1024x1024 transparent PNG desktop-pet sprite.
Reference image: supplied teen_idle.png, the exact original goofy teenage cartoon rooster. Preserve this same bird, age, proportions, silhouette details and palette: lanky narrow ochre body with cream chest, long thin orange legs, long scruffy ochre neck, giant bulging crossed white eyes with tiny black pupils, orange beak, crooked red-orange comb and separate red-orange wattle, pink tongue, brown wings and messy ragged brown tail.
Pose: HAPPY, facing RIGHT. Both wings raised outward and upward in mid-flap, distinct spread ragged wing feathers, beak open in a big silly grin with the pink tongue sticking out to the side. Keep both eyes open and cross-eyed. Full bird standing on long legs, toes planted at y=860. Comb slightly tilted with the excited pose. Tail sweeps left. Make happiness readable through wing pose and open goofy grin.
Art style must match the reference: thick warm dark-brown outline with rounded joins and ragged feather edges, FLAT solid uniform color fills. Think clean vector cartoon sticker. No gradients, shading, texture, highlights, lighting, glow, motion blur, motion lines, cast shadows, or ground.
Creature centered, full wings and comb and toes visible with generous margin on every side. Same standing scale as reference, top comb near y=170 and toes bottom at y=860. Genuine transparent alpha 0 outside artwork. No scenery, background color, checkerboard graphic, words, labels, watermark, extra object, or extra characters. One single happy bird.
```

### Attempt 7: teen_sleep.png

Reference: `Resources/Sprites/heihei/teen_eat.png`.

Outcome: Selected teen sleep artwork using the original-goofy-rooster fallback.

```text
Use case: stylized-concept. Asset: teen_sleep.png, one 1024x1024 genuinely transparent PNG desktop-pet sprite.
Reference image: supplied teen_eat.png is the same original goofy teenage cartoon rooster, with its neck already bent down. Preserve this bird's adolescent identity: lanky narrow torso and long scruffy ochre neck, brown-ochre feathers, cream chest patch, brown wings, messy ragged brown tail, large crooked red-orange comb, separate red-orange wattle, orange beak and orange spindly legs, pink tongue.
Pose: SLEEPING, curled up and SITTING with long neck folded into a comfortable low curve, wings folded against the sides, legs tucked under the body, a little orange foot/toes visible along the bottom. Face RIGHT with beak pointing right, tail feathers splay behind to LEFT. The huge bulging eyes are closed, drawn as large rounded eyelids with simple dark-brown closed-eye arcs. Pink tongue still pokes from side of beak. Keep the large crooked comb and wattle, older scruffy tail and adolescent proportions; do not turn into a round baby chick. Put one tiny hand-drawn 'Zzz' above the sleeping head in warm dark-brown. No corn kernel or food.
Style: exactly the reference's thick warm dark-brown rounded outline, ragged feather edges and simple flat cartoon shapes. Every fill solid UNIFORM flat color; no gradients, textures, shading, lighting, highlights, glow, shadow, or ground.
Full curled bird centered with generous margin. Keep the eyes and beak at roughly the same absolute size as in the reference. As a curled sleeping pose it should be much shorter than standing: body and head together about 350-400px tall, small Zzz above that. Bottom of seated body and tucked toes aligned to invisible y=860 ground line. Transparent alpha 0 outside art, including around and between Zzz letters. No background color, scenery, checkerboard pattern, ground line, cast shadow, logo, watermark, or other words. One sleeping bird with tiny Zzz only.
```

