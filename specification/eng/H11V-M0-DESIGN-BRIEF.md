# H11V — design brief for Claude Design: the M0 asset pack

> **Status: delivered and accepted, 13 September 2026.** The pack is in `specification/art/h11v/`. Section 9 records the audit against this brief and the three deltas worth knowing. This brief stays the contract — re-deliveries must still satisfy it.

This brief is for Claude Design. It orders every visual asset the M0 milestone of H11V needs, with exact filenames, sizes and formats. The engineering context lives in [H11V-M0-SPEC.md](H11V-M0-SPEC.md); the world and art canon in [H11V-CONCEPT.md](H11V-CONCEPT.md), section 12. Where this brief fixes a filename or size, it is a contract with the code — deliver exactly that.

## 1. The game, in one breath

H11V is a pocket voxel world: a first-person player and three small robots share a 128x128-block island world that is slowly, visibly rewritten by an algorithm called H11. Mood: **bright, luminous, uneasy-curious** — a sunlit Minecraft-like world where something vast and quiet is editing reality, politely. Never grim, never horror. Tagline: *Build. Explore. Compute. Together.*

The game renders on a 3.5-inch 640x480 touchscreen (Raspberry Pi 5 handheld). Every asset must read at that size.

## 2. Canonical references

Three images in `specification/art/` are canon. Match their light, palette and UI voice:

- `ref-01-h11-event.png` — mutation-event moment: glyph-etched stone spreading through grass, the H11 event card, hotbar, bot markers.
- `ref-02-bot-echo.png` — bot ECHO close up: ivory rounded robot, black face screen, cyan eyes, amber accents; the bot panel UI.
- `ref-03-anchor-biomes.png` — the living green biome meeting the mutated one: pale lithic structures, lilac crystal growth, teal water.

The floating islands and megastructures in the backgrounds are mood, not deliverables. M0 needs no bot art (bots arrive at M2) — the references define the design language the M0 assets must belong to.

## 3. Palette

Starting points sampled from the references; keep the family, tune freely within it:

| Role | Hex | Notes |
| --- | --- | --- |
| Turf green | `#7CC24E` | vivid, sunlit; shadow tone `#4E8A33` |
| Dirt brown | `#8A6242` | warm; shadow `#6B4A32` |
| Leaves | `#6FB84A` | slightly cooler than turf; shadow `#56933B` |
| Stone ivory | `#E9E5DB` | warm pale grey — never blue-grey; shadow `#C9C4B6` |
| Lithic white | `#F2EFE8` | mutated stone, brighter than plain stone |
| Sand | `#E8D9A8` | pale, warm |
| Water teal | `#4FB3C9` | luminous; depth `#2E86A3` |
| Mutation lilac | `#C9A8E8` | crystal growth; deep `#9A6FC4` |
| HUD cyan | `#64E0EC` | primary accent, glyph glow |
| Amber | `#F2A93B` | secondary accent |
| Gauntlet blue | `#6E8AB8` | the player's hand accent — body colour, never used for HUD |
| Accent green | `#7ADB66` | positive state |
| Panel glass | `#14202B` @ ~80% | HUD panels, thin `#A8D8E0` borders |

## 4. Hard constraints

- **Pixel art discipline at 32x32.** Clean deliberate pixel clusters, no photographic texture, no anti-aliasing mush against transparency. PNG, sRGB, RGBA where transparency is needed.
- **Tileable.** Every node texture in §5.1 must tile seamlessly with itself on all four edges — including `h11_turf_top.png`, the most-tiled surface in the game (a whole meadow of it fills the screen), and `h11_trunk_top.png`, which repeats across adjacent cut logs. No centred motifs on tiling faces; scatter accents so they survive repetition.
- **Distance behaviour.** At view range 40-100 on a 640x480 screen, far blocks are 5-20 px tall. Keep per-texture value contrast moderate (avoid salt-and-pepper noise that shimmers at distance); make top faces clearly lighter/distinct from side faces so terrain reads in silhouette.
- **Night legibility.** The engine multiplies textures toward darkness at night; check every texture at ~30% brightness — hue families must still separate (turf vs leaves, stone vs crust).
- **Roughly ≤ 16 colors per texture**, drawn from section 3 families, so the world stays cohesive.
- **License.** All work original, owned by the project (CC0-equivalent). No sampled third-party material.

### 4.1 Export format — the engine contract

The Luanti engine consumes these files directly; deviations fail silently (wrong faces, fringes, checkerboards), so treat this list as law:

- **PNG only**, 8 bits per channel (PNG-24 opaque / PNG-32 with alpha), sRGB, **no embedded ICC profile**, no interlacing, no 16-bit channels. Ship the files **metadata-free** — no content-credential (`caBX`/C2PA), EXIF or text chunks: on a 32x32 texture such a chunk outweighs the image roughly 20:1.
- **Exact lowercase filenames** as ordered — the device filesystem is case-sensitive; a stray capital letter is a missing texture.
- **Alpha is three regimes, never mixed:** terrain tiles (dirt, turf, stone, sand, trunk, crust) are **fully opaque** — no stray semi-transparent pixels; leaves, the hand and the crosshair use **binary alpha** (every pixel 0% or 100% — anti-aliased edges against transparency produce fringes, and the hand is literally extruded); only water and the HUD glass panels use **partial alpha**.
- **The hand is extruded.** The engine turns `h11_hand.png` into a thin 3D mesh by extruding its opaque pixels — design the silhouette to survive extrusion: chunky, closed shapes, binary alpha, no floating anti-aliased specks (each becomes a floating 3D crumb).
- **Animation strips** are exact vertical stacks of 32x32 frames, frame 1 at the top, playing downward; total heights exactly 256 (still water) and 512 (flowing). No frame gutters or padding.
- **Tiling seams:** the turf side's green fringe occupies the topmost pixel rows so it meets `h11_turf_top.png` cleanly at the block edge.

## 5. Deliverables

### 5.1 Node textures — to `games/h11v/mods/h11_world/textures/`

| File | Size | Content |
| --- | --- | --- |
| `h11_dirt.png` | 32x32 | warm brown soil, few small stones |
| `h11_turf_top.png` | 32x32 | vivid green grass cap, tiny flower/blade accents |
| `h11_turf_side.png` | 32x32 | dirt with a green fringe along the top edge |
| `h11_stone.png` | 32x32 | ivory stone, soft warm-grey clusters |
| `h11_sand.png` | 32x32 | pale warm sand, subtle ripple |
| `h11_water.png` | 32x256 | still water: 8 vertical frames, gentle luminous teal shimmer (frame 1 on top), semi-transparent |
| `h11_water_flowing.png` | 32x512 | flowing water: 16 vertical frames (frame 1 on top) of downhill motion, same palette and alpha as the still frames |
| `h11_trunk_top.png` | 32x32 | pale cut face with rings |
| `h11_trunk_side.png` | 32x32 | warm brown bark, vertical grain |
| `h11_leaves.png` | 32x32 | two-tone foliage with a few fully transparent holes (binary alpha — see §4.1) |
| `h11_crust.png` | 32x32 | the H11 block: lithic white surface with one etched circuit-glyph, faint cyan-to-lilac glow |

### 5.2 UI textures — to `games/h11v/mods/h11_world/textures/`

| File | Size | Content |
| --- | --- | --- |
| `crosshair.png` | 32x32 | thin white plus with a soft cyan glow, open center (per ref-01/02) |
| `h11_hand.png` | 64x64 | first-person wield image: ivory gauntlet with medium-blue accents (`#6E8AB8`) and a dark grey band, exactly as the hand appears in all three references — not HUD cyan. Binary alpha; the engine extrudes it into a 3D mesh (§4.1) |
| `h11_hotbar.png` | 512x64 | 8-slot bar background: dark glass slots, thin light borders, per the references. **Build it from 8 identical 64x64 cells** so the code can crop a lossless 6-slot version — the device may have to drop to 6 slots for width (M0 spec §4) |
| `h11_hotbar_selected.png` | 64x64 | selected-slot frame: brighter border, subtle cyan emphasis |

### 5.3 Menu art — to `games/h11v/menu/`

| File | Size | Content |
| --- | --- | --- |
| `icon.png` | 256x256 | the H11 hex-cluster glyph (see ref-01 event card), works at 32 px |
| `header.png` | 1024x256 | H11V logotype as in the references' top-left corner (monospace, all-caps, tagline optional), transparent background |
| `background.png` | 1920x1080 | key-art background in the canon mood; may quote ref imagery, must stay calm behind menu text |
| `screenshot.png` | 1080x720 | optional, to the game root (`games/h11v/`): a 3:2 key shot for content listings |

### 5.4 Optional, welcome now (reused in M1)

| File | Size | Content |
| --- | --- | --- |
| `h11_glyph_a.png` … `h11_glyph_f.png` | 16x16 each | six distinct circuit-like H11 stencil glyphs, pure white on transparency (code will tint and overlay them on mutated blocks) |
| `h11_crust_2.png` | 32x32 | a second crust variant with a different glyph, for variety |

## 6. Notes per asset group

- **Turf/dirt/stone/sand** carry the game's ground truth — they are on screen constantly. Bias toward calm: fewer, larger pixel clusters; personality lives in the palette, not in busy detail.
- **The crust block is the star.** It must be instantly recognizable as "H11 touched this" at a glance and at distance: brightest surface in the terrain set, one confident glyph, restrained glow (the engine adds real light emission — do not paint a halo).
- **Water** should feel luminous and safe, not deep or ominous; frames should loop imperceptibly. Both water textures must be **semi-transparent (roughly 70-85% alpha)** — the engine renders the liquid with the texture's own alpha, and ref-03 clearly shows the bed through the water. The flowing frames read as downhill motion; the still frames as a slow surface shimmer.
- **UI set** must sit on top of a bright noisy world and stay readable: dark glass + thin light lines, exactly like the reference cards. No opaque heavy boxes.
- **Logotype/icon**: the references' H11V wordmark and hex-cluster glyph are the identity — refine, don't reinvent.

## 7. Not in this order

Bot models or skins (M2), the H11 event card and cycle HUD (M1), the anchor device (M4), skybox or sun/moon art, fonts, sounds, marketing material.

## 8. Delivery

Files named exactly as in section 5 (lowercase, case-sensitive), PNG per the §4.1 export contract, in a flat folder per destination (`textures/`, `menu/`, game root for `screenshot.png`). If a texture wants a variant you believe in, deliver it as `<name>_alt.png` alongside the contracted file, never instead of it.

The delivered pack took the better option and mirrored the destination tree directly — `specification/art/h11v/{menu,mods/h11_world/textures,screenshot.png}` — which makes installation a single `rsync` into `games/h11v/`. Keep that shape for re-deliveries.

## 9. Delivery audit — 13 September 2026

All 26 ordered files present, exact filenames, exact dimensions. Verified programmatically:

| Check | Result |
| --- | --- |
| Filenames and sizes vs §5 | all match, including the optional glyph set and `h11_crust_2.png` |
| Alpha regimes vs §4.1 | exactly as specified: terrain opaque; leaves, hand, crosshair, glyphs binary; water and HUD glass partial |
| Colours per node texture | 4-14, within the ~16 budget |
| ICC profiles | none |
| Tiling (all §5.1 node faces) | seamless; edge discontinuity is within interior variance |
| Frame strips | `h11_water` 8 frames, `h11_water_flowing` 16, correct vertical layout |
| Hotbar cell structure | 8 pixel-identical 64x64 cells — the lossless 6-slot crop works as required |
| Hand silhouette | binary alpha, closed chunky shapes, safe to extrude |

Three deltas, none blocking:

1. **Content-credential metadata.** Every PNG carries a 5,758-byte `caBX` (C2PA) chunk — ~95% of a 32x32 texture's bytes, ~150 KB across the pack. Harmless to the engine (PNG decoders skip unknown ancillary chunks) but pointless weight on a device that syncs over the network, so the M0 spec strips it during installation. Future deliveries should omit it (§4.1).
2. **Water alpha is 204-228 (80-89%)** where §6 asked for 70-85% — slightly more opaque than specified. Judge it on the device during the section 5 eyeball pass; if the bed reads too faintly through a lake, ask for a lighter pass rather than editing the delivery.
3. **`h11_water_flowing` has 16 frames but only 8 unique ones** (the sequence repeats at frame 9). It animates correctly and matches the ordered dimensions; it is simply twice the bytes it needs. Leave as is unless the flow animation reads as too fast, in which case the duplicate half is free headroom.

Two things that look like defects and are not: `h11_turf_side` and `h11_trunk_side` show a top-to-bottom discontinuity, which is correct — the turf side carries its green fringe in the top rows by design, and both tile horizontally, which is the axis that matters for block sides. And `screenshot.png` is an isometric mockup composited from the real textures rather than an in-game capture, which is the only thing it could be before the game exists; replace it after the M0 device session.
