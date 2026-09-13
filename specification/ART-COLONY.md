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

## 4. Palette

Sampled from the two canon references. Keep the families; tune freely inside them.

| Role | Hex | Notes |
| --- | --- | --- |
| Regolith bone | `#E8E2D4` | the ground truth of the world; shadow `#C4BCA9` |
| Biofilm cyan | `#7FD9D0` | the thin living film on the regolith cap — sparse, never a lawn |
| Fines violet-grey | `#A79CB0` | subsoil; shadow `#7E738C` |
| Lithic ivory | `#F1EDE4` | bedrock plates, brighter than regolith; shadow `#CBC3B4` |
| Drift pale | `#EFE6CF` | wind dust, warm-neutral |
| Crystal lilac | `#B98FE0` | spire body; deep `#7C4FB0` |
| Bloom violet | `#C05BD0` | hanging filaments; rose accent `#E86FA8` |
| Meltwater cyan | `#57D8E8` | luminous; depth `#2E8FB0` |
| H11 glow | `#64E0EC` | the crust's light, and the HUD's primary accent |
| Hull white | `#F3F2EE` | lander plating; panel grey `#9AA2A8`, dark grey `#3A4248` |
| Safety orange | `#E2622A` | stencils, stripes, hazard marks — used sparingly, always as *marking* |
| Crate amber | `#E8A33C` | cargo, banding `#2F2A24` |
| Panel glass | `#14202B` @ ~80% | HUD panels, thin `#A8D8E0` borders |

The world's warm notes come only from the colony. The planet itself has no warm hue above `#E8E2D4`.

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
