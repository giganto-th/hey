# Hey! — Hei Hei sprite generation

Fan art of Hei Hei from Disney’s Moana, for the owner’s private desktop-pet app. Generated with the built-in image generation tool, with `transparent_background: true`. No original-character fallback was needed.

The hatchling idle sprite is the master look. Every later sprite uses the closest completed image of the same bird as a reference. Native generated PNGs are copied into `Resources/Sprites/heihei/`; final canvases are normalized to 1024×1024 while preserving alpha.

## Prompts and reference chain

### hatchling_idle.png

Reference: none (master).

```text
Use case: stylized-concept
Asset type: one production-ready 2D macOS desktop-pet game sprite, hatchling_idle.png.
Primary request: fan art of baby Hei Hei, the dim-witted cross-eyed rooster from Disney's Moana, as a tiny round fluffy yellow-brown hatchling. Establish the master design for the same bird growing up.
Subject: enormous bulging white crossed eyes with very tiny inward-pointing black pupils, yellow-orange beak pointing RIGHT, pink tongue always dangling out of the side, dopey relaxed expression. Round ochre/brown fluffy body with cream chest, stubby wings, tiny scruffy head tuft instead of a comb, tiny yellow-orange legs and feet. Standing relaxed. One bird only.
Style/medium: cute clean 2D game sprite, thick warm charcoal outline with round joins, entirely flat solid color fills, at most ONE flat darker shadow patch. Simple readable silhouette at desktop-pet scale.
Composition: square PNG exactly 1024x1024; genuinely transparent alpha background. Full body centered horizontally with ample clear margin; right-facing three-quarter/profile view that shows both crossed eyes; feet resting at y=880. Entire art including tuft inside canvas, no clipping.
Avoid: gradients, texture, grain, fur rendering, glow, cast shadow, ground, scenery, background color, checkerboard pattern, text, watermark, border, extra objects. Keep transparent pixels outside the art.
```
