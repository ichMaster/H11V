# Architecture — H11V

## Overview

Three layers, and the boundary between them is the whole design. **Engine** — Luanti, unmodified —
draws, lights, saves, generates and persists. **Data** — the block catalogue, the mutation rules, the
bot needs profiles — describes what this world is. **Mods** — `h11_world`, `h11_bots`, `h11_hud` —
are the only code we write, and they turn that data into a game inside the engine's own primitives.

Nothing patches or forks the engine, at any version. That is not modesty, it is the schedule: chunks,
lighting, meshing, saving, inventory and touch controls already exist and are already fast on a Pi,
and every hour not spent rewriting them is an hour spent on the thing that makes this game itself.

That data boundary is also why the roadmap's endpoint is reachable. An algorithm that rewrites the
world (v1) only has to rewrite **rows in a table** and let the engine's Active Block Modifiers apply
them; a model that proposes a mutation (v3+) only has to propose such a row. Neither ever authors
Lua.

Two axes grow separately, as in the vision: **the world** (one island → biomes → a mutation cycle →
a world that edits itself) and **the inhabitants** (nothing → three rule-driven bodies → bodies with
a language model behind them). They are bound by the `Perception → Intent` contract, which neither
axis is allowed to change alone.

A model touches this architecture at exactly two seams, and both are data: it answers
`Perception → Intent` to move a bot, and it emits a **plan** over the build catalogue to make
something. It never writes Lua, never writes to the map database, and never emits a coordinate it had
to count out itself.

## Engine primitives we build on

| Need | Luanti primitive |
| --- | --- |
| Block types | `core.register_node` |
| Surface layers under mapgen v7 | `core.register_biome` (**not** the v6 `mapgen_dirt*` aliases) |
| Structural mapgen wiring | aliases `mapgen_stone`, `mapgen_water_source`, `mapgen_river_water_source` |
| Trees | `core.register_decoration` with a Lua-table schematic |
| World mutation | Active Block Modifiers (`core.register_abm`) and LBMs |
| Contact spread | the ABM's own `neighbors` / `without_neighbors` fields — "only next to something already infected" is a field, not a search |
| Catching up while unloaded | `core.register_lbm`, which the engine tracks per world in `env_meta.txt`'s `lbm_introduction_times` |
| Authoring a part | `core.create_schematic` captures a built volume to `.mts` |
| Placing a part | `core.place_schematic` — `rotation` gives four orientations from one file, `replacements` re-materialises the same shape in another block set |
| Bulk edits | VoxelManip: read a region, edit a flat array of content ids, one `write_to_map` |
| Bots | `core.register_entity` with a custom `on_step` |
| Bot pathfinding | `core.find_path` |
| Persistent state | mod storage |
| Brain HTTP calls | `core.request_http_api` (the mod must be listed in `secure.http_mods`) |
| Headless tests | a dedicated server — `luantiserver` on Debian/Pi OS, `luanti --server` from the macOS bundle; `tools/luanti_path.sh` resolves which |

## Components

- **`h11_world`** — the world layer, and in v0 the only mod. Four small modules loaded in a fixed
  order by `init.lua`:
  - `nodes.lua` — one data table, `NODES`, and a loop that registers each entry. Nine registered
    nodes for eight player-visible block types (`dirt`, `turf`, `stone`, `sand`, `water_source`,
    `water_flowing`, `trunk`, `leaves`, `crust`). The table, not the loop, is the point: v1's
    mutation rules are entries over these same ids.
  - `mapgen.lua` — mapgen selection and parameters, the three structural aliases, one
    `core.register_biome` for the surface, and tree decorations.
  - `player.lua` — the hand, the starting inventory, the spawn, the hotbar and crosshair styling,
    and the HUD flags that hide what v0 does not use. Moves into `h11_hud` when that mod appears.
  - `init.lua` — `dofile` calls in order: nodes, mapgen, player.
- **`h11_bots`** (from v2) — the bodies. Split the way the logic is: `body`, `needs`, `intent`,
  `perception`, plus a rule-based StubBrain in Lua so the bots live without a network. Each bot's
  character is its needs weighting, a row in a table.
- **`h11_build`** (from v2) — the catalogue and the builder. `catalogue.lua` is the data table of
  parts; `ops.lua` expands a plan into nodes; `registry.lua` keeps what has been placed; `undo.lua`
  captures each affected region before it is written. It is the only module that writes nodes in bulk,
  and the only one a model ever addresses. See **The build catalogue** below.
- **`h11_hud`** (from v1) — the cycle number, the H11 event card, the world-change card, and from v2
  the bot panels and the Observe/Follow interactions.
- **`brain/`** (from v3) — a small Python HTTP service, one endpoint `POST /decide`, running on a
  machine on the local network with a local model. Not on the device, and **not on the Mac**: the
  Mac's firewall accepts an inbound LAN connection and tears the socket down before the first read,
  so it cannot host a service the device talks to. The host is the LAN box `ich-picobox`; its
  connection details live in the gitignored `.brain-connect.txt`, alongside the device's. It has no
  discrete GPU (4 cores, 15 GB RAM, Intel integrated graphics), so the model must fit CPU inference
  inside the 1-3 s budget — which is one more reason the body never waits on an answer.

## Three details the engine is strict about

Each of these silently produces a wrong-looking world rather than an error, so they are written down:

- **Tile order is `{top, bottom, right, left, back, front}`** with shorthand fill-in. Turf therefore
  needs a *triple* — `{turf_top, dirt, turf_side}` — or the green-fringed side texture lands on the
  block's underside. Trunk takes a pair.
- **Water is a pair.** `water_source` (`drawtype = "liquid"`) and `water_flowing` (`drawtype =
  "flowingliquid"`, flow animation on `special_tiles`), cross-referenced via
  `liquid_alternative_source` / `liquid_alternative_flowing`. Without the flowing partner the first
  shoreline the player digs spawns unknown-node checkerboards. A still pond is possible with a
  source-only node at `liquid_range = 0`, but then water never flows.
- **Surface layers come from biomes, not aliases.** Under v7 (and every mapgen except v6) the engine
  reads only the three structural aliases above; `mapgen_dirt`, `mapgen_dirt_with_grass` and
  `mapgen_sand` are v6-only and registering them instead yields a world of bare stone and water.

## The `Perception → Intent` contract

The seam between a bot's body and its brain, and the one thing in this architecture that may not
change without a line in the decisions log.

```
body (fast ticks)  ──Perception──>  brain  ──Intent──>  body
 decay needs, move,   "what next?"        executes the intent
 execute last intent                      for hundreds of ticks alone
```

- **Intents** are `goto` / `build` / `rest` / `wander` / `idle`, plus an optional `say` from v4.
- **The brain wakes on four conditions only**: cold start, a substantive intent finishing, a need
  crossing the urgency threshold while merely drifting, and a heartbeat interval. Budget: about one
  brain call per 18 ticks per bot, asserted by the v2 acceptance test.
- **Asynchrony is mandatory.** The mod sends the request, keeps executing the previous intent, and
  picks the answer up on a later step. A bot tick never blocks on the network, and with no server
  the bots fall back to the StubBrain. This is what makes the v3 swap free: the same contract is
  answered by a Lua table and by a language model.

## The build catalogue

The second contract a model answers, and the reason a model can build at all.

**A model does not emit blocks.** Asked for a station it would have to produce tens of thousands of
coordinates, which it cannot do reliably — it loses count and drifts, and the answer is enormous. So
it emits a **plan**: thirty lines in a small vocabulary, which deterministic Lua expands into nodes.
This is the same split as everywhere else here — description is data, execution is code — and it puts
the model where it is strong (composition, proportion, intent) and keeps it away from arithmetic.

The vocabulary has two levels, and both are needed:

- **Primitives** — `box`, `dome`, `wall`, `stairs`, `lamps`. Flexible, plain, for terrain and filler.
- **Parts** — authored `.mts` schematics, built by hand in-game and captured with
  `core.create_schematic`. Quality is guaranteed by whoever authored them, not by the model.

A part carries **sockets**: `{at, dir, type}`. With sockets a plan contains no coordinates at all —
`attach habitat_a to hub_core.socket[1]` — so stacking, rotation and offset are computed by Lua and
cannot drift. Ten good parts give thousands of stations; three give three.

### The part registry

One structure in mod storage, and the thing that makes the rest of this document possible:

```
{ id, part, pos, rot, material, sockets_used, born_cycle, last_mutated_cycle }
```

It is cheap — hundreds of rows, not millions — and it buys four things that are otherwise out of
reach: **undo** (without which an experimenting agent cannot be given any freedom), **a world the
model can be told about** ("one hub, three habitats, two free sockets"), **an event card that names
what changed**, and, above all, **something with an identity for H11 to act on**.

### Validation is mandatory

A plan is untrusted input, exactly like an `Intent`. Before anything is written: every node name must
exist in `core.registered_nodes`, the bounding volume must lie inside the world, and the node count
must be computed and capped. A model that is wrong by an order of magnitude asks for ten million
blocks, and the engine will honestly try.

## Mutation is an infection

H11 is not a per-block dice roll. It is an **infection spreading from a focus**, and that framing is
what gives several loose pieces a mechanic:

| | |
| --- | --- |
| **susceptibility** | a per-material rate — crystal spreads fast, colony hull resists — so what the player builds with is a decision |
| **incubation** | the H11 stencil appears before the material changes: a warning, and something for the event card to carry |
| **quarantine** | the v4 anchor is a boundary contact cannot cross, not merely a suppression percentage |
| **a visible frontier** | the player can watch it approach, build away from it, or build against it |

### The frontier is maths; the detail is ABMs

The one structural conflict, and its resolution. **ABMs run only on loaded blocks.** Contact spread
alone would therefore advance the infection only where the player is standing — run away and it
freezes, come back and it resumes. That breaks the fiction and determinism together.

So the two levels are separated:

- **The frontier is a pure function**: `infected(pos, cycle) = dist(pos, focus) < r(cycle) + noise(pos)`.
  It needs no loaded map, answers for any point at any time, and does not care where the player has
  been.
- **The detail is ABMs**, working *inside* a boundary that has already been decided. Contact spread
  survives as local drawing — which block, which glyph, which crack — never as the thing that computes
  the boundary.

### Determinism is the invariant

Because evaluation is lazy, a result must not depend on when the player walked past. Every rule is a
pure function of `(state, cycle, seed)` — `hash(part_id, cycle, seed) < threshold`, never a per-tick
dice roll. Otherwise two players with the same seed get different worlds, and the cycle log describes
something that never happened.

This also answers what the vision listed as open: **missed cycles are not replayed**. A block loading
after a week away computes its current state from the frontier function in one step.

### Two rules of restraint

**Mutate few things per cycle.** Forty changes read as noise; one reads as an event — which is why the
reference art's `WORLD CHANGE` card shows a single change, and why the HUD can afford to name it.

**Never re-place a schematic over a part.** Players extend what they build by hand, and overwriting
that reads as a bug, not as an event. Mutation edits nodes **in place**, touching only those that
still match the part's original schematic. Old blocks stay; changed ones carry the H11 stencil.

## The GPU path

Rendering on the device is hardware or the milestone is void.

**The path is GLX on XWayland, not EGL on Wayland** — established by measurement in v0.6, not by
design. Debian trixie's `luanti` 5.10 is the legacy Irrlicht X11 build: linked against `libX11`, with
no SDL, no EGL and no GLESv2. It rejects both `ogles2` and `opengl3` at runtime despite containing
those strings, so the config says `video_driver = opengl`, and `tools/run_on_pi.sh` sets `DISPLAY=:0`
because over ssh there is none. It still reaches the hardware: `direct rendering: Yes`,
`OpenGL renderer string: V3D 7.1.7.0`.

A future device build linked against SDL would render natively on Wayland through EGL; nothing here
depends on which, only on the renderer being V3D rather than a software rasterizer.

The failure mode this guards against is silent: with a broken EGL setup Mesa falls back to
`llvmpipe`, everything still draws, and every frame-rate number becomes fiction. So:
`glxinfo -B` must name **V3D** *on the display the game will use* — `tools/gpu_preflight.sh` probes
GLX first for exactly this reason, after an earlier version asked EGL and got a correct answer about
a path the game never takes. `LIBGL_ALWAYS_SOFTWARE` must not be set, the renderer line in the
engine's debug log must not contain `llvmpipe`, and `tools/deploy_to_term35.sh` reads that line back
after every launch and says so loudly. The renderer string goes into
`docs/decisions.md` beside the numbers it justifies.

On the Mac no such guard is needed — Apple's GL is always hardware — which is exactly why
measurements only count on the device.

## Assets

Assets are content, not code. The designed pack lives in `specification/art/h11v/`, laid out as an
exact mirror of `games/h11v/`, so installing it is one command and no renaming:

```bash
tools/install_assets.sh              # 16x16, the shipping resolution
tools/install_assets.sh --res=32     # 32x32, the authored size
```

That is the whole install and the whole rollback: it rsyncs the pack in, halves the node textures
unless `--res=32`, and strips the content-credential metadata every delivered PNG carries — 146 KiB
across the pack, up to 97% of a single file, crossing the network on every deploy.

**Node textures are authored at 32x32 and ship at 16x16** — an aesthetic choice, not a technical one.
Halving does discard real detail (only 44% of the pack's 2x2 blocks are uniform), and it does **not**
reduce shimmer at distance (measured: the difference is inside the noise, because nearest-neighbour
halving moves the same hard edges onto a smaller grid rather than smoothing them). Performance is
identical: 2-3 ms of a 33 ms budget either way. What remains is that 16x16 is the resolution the
voxel idiom is written in, and whether 32x32's extra detail reads as texture or as noise at 3.5
inches is a question for the panel. Keeping the 32x32 set as the master means the decision stays
reversible. UI art and the first-person hand are **not** scaled — they are sized in screen pixels or
extruded into a mesh.

`tools/check_assets.py` detects the installed resolution rather than being told it, so the gate
follows the choice automatically and a half-finished install (node textures disagreeing with each
other) is reported as such.

Code references the filenames in [ART.md](ART.md) §5 and nothing else. The pack under
`specification/` is the delivery of record and is never edited in place: a re-delivery is a drop-in
replacement, and the game tree stays reproducible from the specification plus those two commands.
`tools/check_assets.py` enforces the whole contract and treats leftover metadata as a hard failure in
the game tree and a tolerated note in the pack.

## Configuration layering

`tools/device/minetest.conf` holds everything shared — fullscreen 640×480, `video_driver`,
`touch_controls` with the crosshair interaction style, scaling, font. The three `device-*.conf` files
hold only the deltas that define a graphics profile. `deploy_to_term35.sh` concatenates base + chosen
profile into the single config the device runs with, and `run_local.sh` does the same on the Mac with
fullscreen swapped for a window. One source of truth for shared settings, no drift between profiles,
and switching profiles is a redeploy rather than an edit on the device.

## Acceptance and testing

There is no unit-test framework for the game. A change is validated by five commands, and
`execute-issues`, `review-and-fix-issues` and `harden-findings` all run them:

```bash
tools/check_lua.sh                        # parse: luac -p over every .lua, no syntax errors
tools/test_worldgen.sh                    # world: a headless server emerges 128x128, asserts, exits 0
tools/check_assets.py                     # art: names, sizes, alpha regimes, tiling, no metadata
tools/run_local.sh                        # Mac: a 640x480 window, walk, dig, place
tools/deploy_to_term35.sh --profile=mid   # device: it runs, on the GPU, at a measured frame rate
```

The first two run for **every** issue. The third is required whenever `games/h11v/**/textures/`,
`menu/` or the asset pack changed. The fourth whenever anything visible changed. The fifth whenever
the phase's Definition of Done names a frame-rate budget, or the change adds per-tick or per-frame
work — and its numbers only count with the GPU preflight green.

A phase's DoD names the assertions it adds; they go into `test_worldgen.sh` or `check_assets.py`,
never into a new framework.

### What `test_worldgen.sh` actually does

It resolves the platform's server invocation with `tools/luanti_path.sh`, builds a throwaway world
directory and enables a tiny test-only world mod — living under `tools/`,
never shipped inside the game — which on server start force-emerges the area, scans it with a
VoxelManip, prints one parseable result line, and calls `core.request_shutdown()`. The script greps
that line, applies the phase's thresholds and exits 0 or 1. The game itself contains no test code.

## Repository layout

```
games/h11v/            the Luanti game — game.conf, menu/, screenshot.png, mods/
  mods/h11_world/      nodes, mapgen, player (v0); biomes and the mutation cycle (v1)
  mods/h11_bots/       bodies + StubBrain (v2)
  mods/h11_build/      part catalogue, plan ops, placed-part registry, undo (v2)
    schematics/        the authored .mts parts — the catalogue's content
  mods/h11_hud/        cycle HUD, event cards, bot panels (v1-v2)
brain/                 Python brain service for the LAN machine (v3)
tools/                 device profiles, deploy, run, and the acceptance runners
  device/              minetest.conf + device-{low,mid,high}.conf
specification/         VISION, ARCHITECTURE, ROADMAP, SDLC, ART, implementation/
  art/                 canonical references (ref-*.png) and the delivered pack (h11v/)
codegen/               pipeline instrumentation — subject-independent, see SDLC.md
docs/                  decisions.md and device measurements
```

Rules the layout encodes: the game is self-contained under `games/h11v` and can be symlinked into any
Luanti `games/` directory; everything device-specific lives under `tools/` and never inside the game;
textures ship inside the mod that uses them, because a Luanti mod's textures travel with the mod,
while menu art lives at the game level.
