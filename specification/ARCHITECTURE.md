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

## Engine primitives we build on

| Need | Luanti primitive |
| --- | --- |
| Block types | `core.register_node` |
| Surface layers under mapgen v7 | `core.register_biome` (**not** the v6 `mapgen_dirt*` aliases) |
| Structural mapgen wiring | aliases `mapgen_stone`, `mapgen_water_source`, `mapgen_river_water_source` |
| Trees | `core.register_decoration` with a Lua-table schematic |
| World mutation | Active Block Modifiers (`core.register_abm`) and LBMs |
| Bots | `core.register_entity` with a custom `on_step` |
| Bot pathfinding | `core.find_path` |
| Persistent state | mod storage |
| Brain HTTP calls | `core.request_http_api` (the mod must be listed in `secure.http_mods`) |
| Headless tests | `luantiserver` |

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
- **`h11_hud`** (from v1) — the cycle number, the H11 event card, the world-change card, and from v2
  the bot panels and the Observe/Follow interactions.
- **`brain/`** (from v3) — a small Python HTTP service, one endpoint `POST /decide`, running on a
  machine on the local network with a local model. Not on the device.

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

## The GPU path

Rendering on the device is hardware or the milestone is void. SDL video on Wayland
(`SDL_VIDEODRIVER=wayland`, set by `tools/run_on_pi.sh`), EGL + GL ES 2 through Mesa's V3D driver on
the Pi 5's VideoCore VII, selected in the config as `video_driver = ogles2`.

The failure mode this guards against is silent: with a broken EGL setup Mesa falls back to
`llvmpipe`, everything still draws, and every frame-rate number becomes fiction. So:
`glxinfo -B` / `eglinfo` must name **V3D**, `LIBGL_ALWAYS_SOFTWARE` must not be set, the renderer
line in the engine's debug log must not contain `llvmpipe`, and `tools/deploy_to_term35.sh` reads
that line back after every launch and says so loudly. The renderer string goes into
`docs/decisions.md` beside the numbers it justifies.

On the Mac no such guard is needed — Apple's GL is always hardware — which is exactly why
measurements only count on the device.

## Assets

Assets are content, not code. The designed pack lives in `specification/art/h11v/`, laid out as an
exact mirror of `games/h11v/`, so installing it is one command and no renaming:

```bash
rsync -a --exclude .DS_Store specification/art/h11v/  games/h11v/
```

Then strip the content-credential metadata every delivered PNG carries — 146 KiB across the pack,
up to 97% of a single 32x32 file, and it crosses the network on every deploy:

```bash
tools/strip_png_metadata.py games/h11v
```

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
tools/test_worldgen.sh                    # world: luantiserver emerges 128x128, asserts, exits 0
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

It builds a throwaway world directory and enables a tiny test-only world mod — living under `tools/`,
never shipped inside the game — which on server start force-emerges the area, scans it with a
VoxelManip, prints one parseable result line, and calls `core.request_shutdown()`. The script greps
that line, applies the phase's thresholds and exits 0 or 1. The game itself contains no test code.

## Repository layout

```
games/h11v/            the Luanti game — game.conf, menu/, screenshot.png, mods/
  mods/h11_world/      nodes, mapgen, player (v0); biomes and the mutation cycle (v1)
  mods/h11_bots/       bodies + StubBrain (v2)
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
