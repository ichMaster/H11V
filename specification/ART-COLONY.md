# Art — H11V, the colony direction

The canon and the asset-pack brief for the world H11V becomes after v0. It supersedes part one of
[ART.md](ART.md); that document stays as the record of the v0 pack, which is what currently ships.

**Why this exists.** The v0 pack is well drawn and it works on the panel. The world it builds still
reads as Minecraft with a better palette — because grass, soil, bark, leaves and cobble *are* the
Minecraft vocabulary. Recolouring that vocabulary cannot escape it. So the vocabulary changes: the
player is not standing in a meadow, they are standing on another planet, beside the wreck that
brought them there.

---

# Part one — the canon

## 1. The game, in one breath

A lander came down on a world nobody had surveyed. What is left of it is the colony: a broken hull, a
few prefab shells, a greenhouse, a mast, and three small robots that outlived the landing. The player
is the only human presence. The planet is beautiful and entirely mineral — pale bone regolith,
crystal growth instead of forest, luminous meltwater instead of rivers — and it is being quietly
reorganised by something the colony's logs call **H11**, which rewrites terrain and matter in slow,
visible cycles. There is no win condition and nothing to fight.

Mood: **bright, luminous, uneasy-curious.** Daylight, open sky, a gas giant on the horizon. Never
grim, never horror, never a dark cave shooter. Tagline: *Build. Explore. Compute. Together.*

It renders on a 3.5-inch 640x480 touchscreen. Every asset must read at that size.

## 2. What this replaces

The rule for every deliverable: **if a block could appear in Minecraft unmodified, it is wrong.**

| v0 — do not continue | this direction |
| --- | --- |
| grass turf, vivid green | **regolith** — bone-pale mineral crust with a thin cyan biofilm |
| brown soil | **fines** — violet-grey compacted mineral dust |
| grey-ivory stone | **lithic** — bone bedrock in fractured plates |
| sand | **drift** — pale wind-blown dust |
| tree trunk with bark grain | **spire** — a faceted crystal stalk, grown not grown-from-seed |
| leaf canopy | **bloom** — hanging crystal filaments, a weeping crown |
| water | **meltwater** — luminous cyan, cold, lit from within |
| — | **colony tech**: hull plate, prefab panel, cargo crate, beacon lamp |

Never, anywhere in the pack: chlorophyll green, warm brown soil, bark, cobblestone, moss, wood
planks, anything that reads as Earth vegetation.

**Two silhouette languages, never blended.** Every block belongs to exactly one, and the two must be
distinguishable at 8 pixels:

- **Grown** — crystal and mineral. Facets, vertical needles, hanging filaments, uneven edges,
  internal light. Cool violets and cyans.
- **Built** — colony hardware. Flat plates, straight seams, rivet grids, stencil marks, machined
  right angles. Whites, greys, safety orange, amber.

The tension between those two is the whole picture. The planet did not invite the colony, and the
colony did not soften the planet.

## 3. Canonical references

Two images in [art/space/](art/space/) are canon for this direction. Match their light, palette,
material language and UI voice:

- the establishing shot — the crashed lander, the prefab cluster and greenhouse dome, the three bots,
  the SCAN tool in the player's hand, the hotbar of eight cubes, the gas giant behind floating lithic
  plateaus, cyan meltwater running through bone-white terraces.
- the mutation shot — the same world mid-H11-event: weeping violet crystal growth flooding the
  cliffs, the event card, the WORLD CHANGE panel, `H11 // MUTATION ACTIVE` in the corner.

The three older images (`ref-01`…`ref-03`) are **retired as world canon**. They remain canon for one
thing only: the **UI voice** — dark glass panels, thin light borders, cyan monospace type.

Floating islands, megastructures, the gas giant, the bots and the buildings in the references are
mood and future work, not deliverables in this order. They define the language the ordered assets
must belong to.

## 4. Palette — yours to choose

The table below is a **starting sketch** sampled from the two canon references. It is deliberately
*not* a contract: choose your own values, and let the references be the authority on mood.

| Role | Sketch | Notes |
| --- | --- | --- |
| Regolith | `#E8E2D4` | the ground truth of the world |
| Biofilm | `#7FD9D0` | the thin living film on the regolith cap — sparse, never a lawn |
| Fines | `#A79CB0` | subsoil |
| Lithic | `#F1EDE4` | bedrock plates |
| Drift | `#EFE6CF` | wind dust |
| Crystal | `#B98FE0` | spire body |
| Bloom | `#C05BD0` | hanging filaments; rose accent `#E86FA8` |
| Meltwater | `#57D8E8` | luminous; depth `#2E8FB0` |
| H11 glow | `#64E0EC` | the crust's light, and the HUD's primary accent |
| Hull | `#F3F2EE` | lander plating; panel grey `#9AA2A8`, dark grey `#3A4248` |
| Safety orange | `#E2622A` | stencils and hazard marks — always used as *marking*, never as a field |
| Crate amber | `#E8A33C` | cargo, banding `#2F2A24` |
| Panel glass | `#14202B` @ ~80% | HUD panels, thin `#A8D8E0` borders |

Two things about this sketch are load-bearing and should survive whatever you choose: the world's
**warm notes come only from the colony** — the planet itself is cool — and **safety orange is a mark,
never a surface**.

## 4.1 Separation — this part is binding

The sketch above is also a worked example of how this world goes wrong, and the reason is worth
stating before the rules.

**At 5–20 pixels a texture collapses to its mean colour.** View range is 40–100 nodes on a 640x480
panel, so most of what is on screen at any moment is a block a handful of pixels tall. Detail,
clusters, glyphs, rivets — none of it survives that. Two materials are told apart by their *means*
and by nothing else. And this fiction pushes hard in the wrong direction: regolith, lithic, drift and
hull are all, in plain language, "pale mineral white".

Measured on the sketch, four of the six opaque materials sat within ΔL\* 4 of each other — regolith
and drift differed by **1.4** at an identical hue, lithic and the ship's hull by **1.6**. That palette
would have rendered as one grey planet with a grey shipwreck on it. The reference images get away with
it because ray-traced shadows and ambient occlusion do the separating; the device has **no shadows at
all** — they are off in every profile, and that is a frame-rate decision, not an oversight.

So the colours are yours, and these six rules are not.

**Rule 1 — the value ladder.** The opaque materials share one ladder, and **neighbours sit at least 8
L\* apart**. This order is chosen so the ground you walk on sits in the middle and the cliffs and
dunes read brighter against it:

```
brightest   drift          wind dust catches the light
            lithic         bedrock, cliff faces
            regolith       the walkable surface
            hull           worn plating, entry-scorched
            prefab         habitat panels
darkest     fines          subsoil
```

Eight points is not arbitrary: it is roughly the smallest lightness step that still separates two
flat 8-pixel patches under the engine's own light modulation.

**Rule 2 — hue does the work when value cannot.** Any two materials closer than 8 L\* must be **at
least 60° apart in hue**. Spread the ladder around the wheel rather than stacking one family: a warm
dust, a cool bedrock, a cyan-cast regolith, a violet subsoil. Hue is also what survives nightfall,
when the engine compresses every value toward black and the ladder flattens.

**Rule 3 — four collisions are structural in this fiction.** They are not mistakes waiting to happen;
they are where this world naturally wants to fold. Solve each deliberately:

| pair | why they collide | the lever |
| --- | --- | --- |
| lithic ↔ meltwater | both pale and cool | water carries much higher chroma, and is the only partial-alpha surface — lean on saturation |
| regolith ↔ meltwater | the shore, where they are literally adjacent | keep the biofilm's cyan *desaturated*; the water owns saturated cyan |
| hull ↔ crate | both warm mid-tone colony hardware | the crate is saturated amber, the hull is nearly neutral — separate by chroma, not lightness |
| fines ↔ bloom | both violet | bloom is far more saturated and has binary-alpha gaps; fines is flat and muted |

**Rule 4 — spatial frequency is the third axis.** Between about 10 and 20 pixels, before detail fully
dissolves, cluster size still reads. Give each material its own:

| material | frequency |
| --- | --- |
| lithic | large flat plates, few long fracture lines — reads smooth |
| drift | fine even ripple — reads soft and uniform |
| regolith | a plain field with sparse discrete specks — reads speckled |
| fines | medium mottled clusters — reads grainy |
| hull | a regular seam-and-rivet lattice — reads manufactured |
| prefab | one strong vertical seam, otherwise flat — reads panelled |

**Rule 5 — top faces are brighter than side faces**, in every material that has both. Terrain reads in
silhouette only if the horizontal planes separate from the vertical ones. The engine's own face shading
helps, but it is not enough on its own and it must not be relied on.

**Rule 6 — check at 30% brightness.** At night the world is lit by the H11 crust and the colony's
beacons, and everything else is multiplied toward black. The value ladder compresses; the hue spread
from Rule 2 is what still separates regolith from lithic when it does.

### How to verify, before delivering

Two checks, both cheap, both worth more than any amount of looking at the tiles at full size:

1. **Downscale each node texture to a single pixel** and lay the results side by side. That one pixel
   is, near enough, what the engine puts on screen at distance. Any two that look alike there *are*
   alike. Check every pair, not only the ones you expect to be close.
2. **Render the set at 8x8 and squint.** If the terrain set turns into a single field of porridge, the
   ladder is too tight — no amount of detail at 32x32 will rescue it.

### One palette that passes, as proof the rules are satisfiable

Not a proposal — a demonstration that an 8-point ladder with a spread of hues actually exists inside
this fiction. Take it, ignore it, or use it as a floor to beat:

| material | L\* | C\* | hue | hex |
| --- | --- | --- | --- | --- |
| drift | 92 | 16 | 85° | `#F7E6CA` |
| lithic | 84 | 6 | 250° | `#C8D3DC` |
| regolith | 76 | 13 | 175° | `#A2C2B9` |
| hull | 68 | 9 | 45° | `#B6A19B` |
| prefab | 60 | 5 | 250° | `#899299` |
| fines | 52 | 16 | 300° | `#7E7894` |

It is cooler and less creamy than the references, which is the honest cost of losing ray-traced
shadows. If you can hold the reference's warm bone light *and* the ladder, that is a better answer than
this one — the rules are the requirement, the hexes never were.

---

# Part two — the asset pack

Where this brief fixes a filename or a size, it is a contract with the code — deliver exactly that.
Lowercase, case-sensitive; a stray capital is a missing texture on the device.

## 5. Hard constraints

- **Pixel art discipline at 32x32.** Deliberate pixel clusters, no photographic texture, no
  anti-aliasing mush against transparency. PNG, sRGB, RGBA where transparency is needed.
- **Tileable.** Every node texture in §6.1 and §6.2 tiles seamlessly with itself on all four edges —
  including `h11_regolith_top.png`, which fills whole screens, and `h11_hull.png`, which a player will
  place in walls twenty blocks wide. No centred motifs on tiling faces; scatter accents so they
  survive repetition. A rivet grid or seam lattice must line up across the join.
- **Distance behaviour.** At view range 40–100 on 640x480, far blocks are 5–20 px tall. Keep
  per-texture value contrast moderate — salt-and-pepper noise shimmers — and make top faces clearly
  lighter than side faces so terrain reads in silhouette.
- **Night legibility.** At night the world is lit by the H11 crust and the colony's own beacons, and
  the engine multiplies everything else toward darkness. Check every texture at ~30% brightness: the
  hue families must still separate — regolith from lithic, spire from bloom, hull from prefab.
- **Roughly ≤ 16 colours per texture**, from §4, so the world stays one world.
- **Licence.** All work original, owned by the project (CC0-equivalent). No sampled third-party
  material.

### 5.1 Export contract — the engine reads these files directly

Deviations here fail **silently** — wrong faces, alpha fringes, checkerboards — so treat this as law.

- **PNG only**, 8 bits per channel (PNG-24 opaque / PNG-32 with alpha), sRGB, **no embedded ICC
  profile**, no interlacing, no 16-bit channels. Ship **metadata-free**: no content-credential
  (`caBX`/C2PA), EXIF or text chunks. On a 32x32 texture such a chunk outweighs the image ~20:1.
- **Alpha is three regimes, never mixed.** Opaque: every terrain and colony tile. Binary (each pixel
  0% or 100%): `h11_bloom.png`, `h11_scanner.png`, `crosshair.png`, the glyphs — an anti-aliased edge
  against transparency produces a fringe, and the scanner is literally extruded into geometry.
  Partial alpha: meltwater and the HUD glass only.
- **The wield image is extruded.** The engine turns `h11_scanner.png` into a thin 3D mesh from its
  opaque pixels. Design a silhouette that survives that: chunky closed shapes, binary alpha, no
  floating specks — each speck becomes a floating 3D crumb.
- **Animation strips** are exact vertical stacks of 32x32 frames, frame 1 at the top, playing
  downward; total height exactly 256 (still) and 512 (flowing). No gutters, no padding.
- **Tiling seam at the ground cap:** the regolith side's biofilm fringe occupies the topmost pixel
  rows, so it meets `h11_regolith_top.png` cleanly at the block edge.

## 6. Deliverables

### 6.1 Planet nodes — to `mods/h11_world/textures/`

| File | Size | Content |
| --- | --- | --- |
| `h11_regolith_top.png` | 32x32 | the world's surface: bone dust, fine crazing, a sparse cyan biofilm bloom and two or three tiny crystal specks. **Sparse** — this is not a lawn |
| `h11_regolith_side.png` | 32x32 | fines with the biofilm crust fringe along the top edge only |
| `h11_fines.png` | 32x32 | violet-grey compacted subsoil, a few embedded pebbles. Also the bottom face of regolith |
| `h11_lithic.png` | 32x32 | bedrock: ivory plates with fracture lines, flatter and brighter than regolith |
| `h11_drift.png` | 32x32 | pale wind-drift dust, soft ripple, no pebbles (it falls when unsupported) |
| `h11_spire_top.png` | 32x32 | cut face of a crystal stalk: concentric growth rings, translucent core, brightest at the centre |
| `h11_spire_side.png` | 32x32 | stalk flank: vertical facets, lilac, a faint internal vertical light line |
| `h11_bloom.png` | 32x32 | the crown: hanging violet filaments with genuine gaps. Binary alpha; must read as *hanging*, so weight the mass toward the top |
| `h11_melt.png` | 32x256 | still meltwater: 8 frames, slow luminous cyan shimmer, semi-transparent (~70–85%) |
| `h11_melt_flowing.png` | 32x512 | flowing meltwater: 16 frames of downhill motion, same palette and alpha |
| `h11_crust.png` | 32x32 | **the H11 block.** Lithic white shot through with a crystal core, one etched circuit-glyph, cyan-to-lilac. The brightest surface in the world |
| `h11_crust_2.png` | 32x32 | a second crust variant, different glyph |

### 6.2 Colony nodes — to `mods/h11_world/textures/`

These are what the player builds with, and they are the strongest signal that this is not Minecraft.
All four are **built**, not grown: machined, flat, deliberate.

| File | Size | Content |
| --- | --- | --- |
| `h11_hull.png` | 32x32 | lander plating: off-white panel with a seam lattice and rivets, one small orange stencil dash. Must tile into a believable twenty-block wall |
| `h11_prefab.png` | 32x32 | habitat wall: pale grey panel, one vertical seam, a thin cyan trim line, slightly recessed centre |
| `h11_crate_top.png` | 32x32 | cargo lid: amber with a dark latch cross and a small stencil square |
| `h11_crate_side.png` | 32x32 | crate flank: amber with two dark bands and corner brackets |
| `h11_beacon.png` | 32x32 | colony lamp: dark machined housing around a cyan lens. **This block emits light** — paint the lens bright but do not paint a halo, the engine adds real emission |

### 6.3 UI — to `mods/h11_world/textures/`

| File | Size | Content |
| --- | --- | --- |
| `crosshair.png` | 32x32 | thin white plus, soft cyan glow, open centre |
| `h11_scanner.png` | 64x64 | **replaces the v0 gauntlet.** The first-person tool exactly as held in both canon references: a white-and-dark-grey armoured gauntlet gripping a square scanner whose cyan screen shows a bracket reticle. Binary alpha; extruded (§5.1) |
| `h11_hotbar.png` | 512x64 | 8-slot bar: dark glass slots, thin light borders. **Build it from 8 identical 64x64 cells** so the code can crop a lossless 6-slot version if width forces it |
| `h11_hotbar_selected.png` | 64x64 | selected-slot frame: brighter border, cyan emphasis |

### 6.4 Menu — to `menu/`

| File | Size | Content |
| --- | --- | --- |
| `icon.png` | 256x256 | the H11 mark from the references' banner — the hexagonal orbit glyph. Must work at 32 px |
| `header.png` | 1024x256 | the `H11V` logotype as in the references' top-left: monospace, all-caps, the four-line tagline optional. Transparent background |
| `background.png` | 1920x1080 | key art in this canon — the lander, the colony, the crystal horizon. Calm enough to sit behind menu text |
| `screenshot.png` | 1080x720 | to the game root: a 3:2 key shot for content listings |

### 6.5 Optional, welcome now

| File | Size | Content |
| --- | --- | --- |
| `h11_glyph_a.png` … `h11_glyph_f.png` | 16x16 | six distinct circuit-like H11 stencil glyphs, pure white on transparency — the code tints and overlays them on mutated blocks |

## 7. Notes per group

- **Regolith, fines, lithic and drift are on screen constantly.** Bias toward calm: fewer, larger
  clusters. The personality is in the palette, not in busy detail. If the four are hard to tell apart
  at distance the set has failed — separate them by *value* first, hue second.
- **The spire is a plant that is a mineral.** It should be obvious it grew, and equally obvious it was
  never wood. No bark texture, no knots, no rings that look like sawn timber — the rings on the cut
  face are crystal growth bands, brightest at the core.
- **The crust block is the star.** Instantly readable as "H11 touched this" at a glance and at
  distance: brightest surface in the terrain set, one confident glyph, restrained glow. It is also the
  world's ambient light source at night, so its colour decides what night looks like.
- **The colony set must look manufactured by people.** Straight lines, tolerances, stencils, wear.
  Beside the crystal it should feel a little crude and a little reassuring.
- **UI sits on top of a bright, busy world.** Dark glass and thin light lines, exactly as in the
  references. No opaque heavy boxes.
- **The logotype and the H11 mark are the identity.** Refine them, do not reinvent them.

## 8. Not in this order

Bot models or skins (they arrive at M2 and get their own brief), the H11 event card and cycle HUD
(M1), the anchor device (M4), the lander wreck and prefab buildings as placeable structures, skybox,
gas giant, sun and moon art, fonts, sounds, marketing material.

## 9. Delivery

Mirror the destination tree, exactly as the v0 pack did — it makes installation a single `rsync`:

```
colony/
  menu/{icon,header,background}.png
  mods/h11_world/textures/*.png
  screenshot.png
```

Deliver into `specification/art/colony/`. If a texture wants a variant you believe in, ship it as
`<name>_alt.png` beside the contracted file, never instead of it.

## 10. What the code must change when this lands

Stated here so the brief is honest about its cost. This is not the designer's work; it is the
engineering work the delivery triggers, and it is why the pack cannot simply be dropped over the old
one:

- `nodes.lua` — the `NODES` table gains four colony blocks and every planet block is renamed
  (`h11_world:turf` → `regolith`, `dirt` → `fines`, `stone` → `lithic`, `sand` → `drift`, `trunk` →
  `spire`, `leaves` → `bloom`, `water` → `melt`). The beacon is a second `light_source` block, which
  gives the player a light that is theirs rather than H11's.
- `mapgen.lua` — the three structural aliases, the biome's `node_top` / `node_filler` / `node_riverbed`
  and the tree schematic all address blocks by id.
- `player.lua` — the starting inventory, and the wield image name.
- `tools/check_assets.py` — the expected-file tables and the tiling lists are pinned by filename.

Worlds generated before the rename will not survive it. That is acceptable and expected: v0's world
is a test fixture, not a save worth keeping.

---

## 11. Delivery audit — 14 September 2026

Accepted after two revisions. 44 files: the 21 ordered textures, the 6 optional glyphs, the 3 menu
images, `screenshot.png`, and 13 unordered extras that are welcome
(`h11_creep`, `h11_needle`, `h11_lattice`, `h11_pod`, `h11_frond`, `h11_tuft`, `h11_shelf`,
`h11_stem`, `h11_lithic_top`, `h11_lava`, and three `_alt` variants).

Verified programmatically against §5.1 and §4.1, not by eye alone.

| Check | Result |
| --- | --- |
| Filenames and sizes vs §6 | all match, including the optional glyph set |
| Alpha regimes vs §5.1 | exactly as specified — terrain opaque, bloom/scanner/crosshair/glyphs binary, meltwater partial |
| Rule 1, the value ladder | **holds at every step**: hull 86.8 → drift 77.9 → regolith 69.7 → prefab 58.7 → fines 50.4 → lithic 42.0, steps of 8.8 · 8.2 · 11.1 · 8.3 · 8.4 |
| Rule 5, top brighter than side | 3 of 3 — regolith +16.2, spire +4.1, crate +10.0 |
| Rule 2, hue spread | 7 formal collisions, **none blocking** — see below |
| PNG metadata | `caBX` content-credential chunks present; `tools/strip_png_metadata.py` removes them at install, as it did for the v0 pack |

**The seven collisions, each checked rather than counted.** Three are solved by chroma
(`regolith_top`↔`spire_side`/`spire_top` sit at the same lightness but at ΔC 26–30 — pale ground
against vivid crystal; `lithic`↔`bloom` at ΔC 51). One is solved by the engine: `lithic`↔`beacon` is
a real match on paper, but the beacon is a `light_source` and is therefore physically brighter than
anything near it. Two are the two faces of one block. One — `fines`↔`regolith_side` — is required by
the brief itself, since the side face *is* fines with a fringe.

### What the two revisions changed, and what that says

The pack arrived complete and technically perfect the first time, and was still wrong — which is the
argument for §4.1 existing at all.

| | delivered | after revision |
| --- | --- | --- |
| `regolith_top` | warm brown, hue 69, C 27 — soil with grass specks | hue 190, C 6.6 — a pale cool mineral crust |
| `drift` | horizontal wood grain | smooth cream dust, no streaks |
| `melt` | violet, hue 299 — the infection's own family, colliding with `fines` at ΔH 1 | hue 167, green-teal, clear of both violet and H11's cyan |
| `lithic` | dark vertical bands: a plank | then cobblestone with mortar; finally hue 258, C 4.9, cool grey with open angular fractures |
| `lithic_top` | cobblestone | the same fracture language as `lithic` |
| `stem` | brown bark | violet with an internal vein — a stalk, not timber |
| `spire_top` | 8.2 L* *darker* than its own flank | +4.1 brighter |
| `crate_top` | +2.6 over its side — technically passing, visually thin | +10.0 |

**The measurements found the palette problems; only looking found the material ones.** The value
ladder was nearly correct in the first delivery while the ground was still recognisably Minecraft
dirt, because a lightness ladder cannot see what a texture depicts. Both checks are needed, and the
cheap one is not the sufficient one.

**One deviation from the brief was accepted as better than the brief.** §4's sketch spent cyan on the
terrain. The delivery reserves cyan entirely for the crystals and for H11, and gives the planet a
warm-bone-to-violet range instead. That is a stronger reading of the fiction — the colour of the
algorithm should not also be the colour of the ground — and it is now canon.
