# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

**v0 is built and released, not planned.** `VERSION` reads `0.8.0`, `RELEASE.txt` carries the log
newest-first back to `0.1.0`, and `git tag` carries the tags. A session that starts here is joining
a working game: read the tree before planning against it, and never re-run a released phase.

What exists:

- `games/h11v/` — the Luanti game. One mod so far, `h11_world`, whose `init.lua` loads five modules
  with `dofile`: `nodes.lua` (the `NODES` table — **13** registered blocks), `mapgen.lua`,
  `player.lua`, `music.lua`, `turn.lua`. 40 textures installed under `mods/h11_world/textures/`, plus
  the menu art and the screenshot.
- `tools/` — the acceptance gates and the whole device chain: `check_lua.sh`, `test_worldgen.sh` with
  its `worldgen_probe/` test-only mod, `check_assets.py`, `run_local.sh`, `run_on_pi.sh`,
  `deploy_to_term35.sh`, `measure_device.sh`, `gpu_preflight.sh`, `luanti_path.sh`,
  `install_assets.sh`, `downscale_pack.py`, `strip_png_metadata.py`, and `device/` with the confs the
  deploy concatenates.
- `docs/decisions.md` — every decision v0 took, next to the measurement that forced it. The review at
  `0.8.0` found it accurate everywhere it checked, so **when a document and that log disagree, the log
  wins** and the document is the thing to fix.
- `codegen/` — pipeline instrumentation. Subject-independent; see [SDLC.md](specification/SDLC.md).

**No bot and no brain code exists anywhere, and none is carried in.** `h11_bots`, `h11_build` and
`brain/` are written fresh at v2/v3 — that half of the arc is still ahead, and nothing in the tree
pre-empts it.

The specifications are the source of truth and live flat in [specification/](specification/), English
only:

- [VISION.md](specification/VISION.md) — what this is, for whom, the principles, the arc, what is
  deliberately not built, and the three still-open questions.
- [ARCHITECTURE.md](specification/ARCHITECTURE.md) — the engine/data/mods split, the Luanti
  primitives we stand on, three engine strictnesses that fail *silently*, the `Perception → Intent`
  contract, the build catalogue, mutation as an infection, the GPU path, **the five acceptance
  gates**, and the authoritative repository layout.
- [ROADMAP.md](specification/ROADMAP.md) — v0–v4, each phase with Goal / Tasks / DoD / Tests. v0 is
  the device version, phase by phase, and it is the one that has shipped.
- [SDLC.md](specification/SDLC.md) — how a roadmap phase becomes shipped code: the ten skills, the
  gates, issue identity, and the `codegen/` instrumentation.
- [ART-COLONY.md](specification/ART-COLONY.md) — **the current art canon and asset brief**: the colony
  direction, §4.1's binding separation rules, §6's filename contract with the code, and §11's delivery
  audit. It supersedes `ART.md` for everything about the world.
- [ART.md](specification/ART.md) — superseded as world canon, and still authoritative for two things:
  the **UI voice** (dark glass panels, thin light borders, cyan monospace type, the event and
  world-change cards, the bot panel) and the record of the v0 pack, audited in its §9. `ref-02`'s bot
  design language also stands until a v2 bot brief replaces it.
- `specification/art/` — `space/` (the two canonical references), `colony/` (the shipping pack and the
  delivery of record, never edited in place), plus the retired `ref-*.png` and `h11v/` from v0.
- `specification/implementation/` — per-version issues, execution reports and code reviews, written by
  the skills. It also holds `v0.8-code-review.md`, the 71-finding review of tag `0.8.0` that the v0.9
  phase exists to close.

## What H11V is

H11V is fully self-contained — no code, prompts, or assets come in from any other repository or project. It is a Minecraft-like voxel game for a pocket device where a first-person player and three bots share one small world (~128x128, no infinite generation), and the "H11 algorithm" mutates both the terrain and the creatures in slow, visible cycles driven by a data table of deterministic rules. There is no win condition.

Art direction is **the colony**: a lander came down on an unsurveyed, entirely mineral planet — bone regolith, crystal spires instead of forest, green-teal meltwater, and the colony's own white-and-amber hardware. Bright, luminous, uneasy-curious; never dark/horror. Textures are 32x32 and come exclusively from the designed asset pack (`specification/art/colony/`, accepted 14.09.2026 after two revisions); there is no procedural texture generation. [ART-COLONY.md](specification/ART-COLONY.md) is the canon and the brief — including §4.1, the binding colour-separation rules, which exist because this fiction wants four kinds of pale mineral and the device has no shadows to tell them apart. `ART.md` is retired as world canon and kept for the UI voice and the v0 record. The bots are canon: **DRIFT** (BOT 01, cyan, curiosity-driven), **ECHO** (BOT 02, amber, balanced observer), **MOSS** (BOT 03, green, safety/energy-driven), sharing the needs triad energy/curiosity/safety.

Target device: **Waveshare PocketTerm35** — Raspberry Pi 5 / 4 GB, 3.5" 640x480 touchscreen + keyboard, Raspberry Pi OS with Sway (Wayland), **no mouse**. Development happens on a MacBook M1, so every feature needs both a Mac run path and a device run path.

## Engine

**Luanti** (formerly Minetest) — decided, not open. The game is written purely as Lua mods on top of the stock engine; do not build a renderer, chunking, lighting, or saving. Mechanics map onto stock primitives:

| Need | Luanti primitive |
| --- | --- |
| Block types | `core.register_node` |
| World mutation cycle | `core.register_abm` (Active Block Modifiers) + LBM |
| Bots | `core.register_entity` with a custom `on_step` |
| Persistent state | mod storage |
| Brain HTTP calls | `core.request_http_api` (mod must be listed in `secure.http_mods`) |
| Bot pathfinding | `core.find_path` |
| Headless tests | `luantiserver` (Pi) / `luanti --server` (Mac) — `tools/luanti_path.sh` resolves it |

Godot 4 + godot_voxel was considered and rejected for this project; Unity/Unreal are out (no Linux arm64 story on the Pi).

Luanti is installed on both machines and at different versions: **5.17.0 on the Mac** (Homebrew cask, `/Applications/luanti.app`) and **5.10.0 on the device** (Debian trixie's `luanti` and `luanti-server` packages, chosen over a Flatpak or AppImage because a sandboxed runtime would bring its own Mesa and GPU plumbing into the exact measurement v0 exists to take). The seven-version skew is the constraint that follows, and it applies to every feature: **the mod API surface must stay inside what 5.10 supports**, because the device is where the game has to run. Both versions and the reasoning are in `docs/decisions.md`.

## Layout

[ARCHITECTURE.md](specification/ARCHITECTURE.md) §Repository layout is the authoritative tree, with
the rules it encodes. The top level, which is all that is needed to decide where a new file belongs:

```
games/h11v/            the Luanti game — game.conf, menu/, screenshot.png, mods/. h11_world today;
                       h11_bots and h11_build from v2, h11_hud from v1. Textures live inside the mod
                       that uses them, and nothing device-specific goes in here.
brain/                 the Python brain service for the LAN machine (v3). Not written yet.
tools/                 the acceptance gates, the device profiles, deploy, run, asset install — and
                       device/, the confs. Everything device-specific lives here, never in the game.
specification/         VISION, ARCHITECTURE, ROADMAP, SDLC, ART-COLONY, ART, art/, implementation/
codegen/               pipeline instrumentation — tracker, hook, dashboard, tests
docs/                  decisions.md, device/ (fps notes, screenshots)
```

The game is self-contained under `games/h11v` and can be symlinked into any Luanti `games/` directory.
That is the reason for the two rules above rather than a tidiness preference: a mod's textures travel
with the mod, and a game carrying a device profile inside it stops being portable.

## Architecture: three layers

1. **World and rules** (`h11_world`, Lua). Mutations are described as *data* — a `rule → block transformation → condition` table — not as code, so a model can propose them later. Old blocks stay; mutated ones are marked with the H11 stencil. A cycle log and cycle number are player-visible.
2. **Bot bodies** (`h11_bots`, Lua). The body runs inside the entity's `on_step` on fast ticks, no network needed: needs decay, one intent executed over hundreds of ticks, brain woken only by the four conditions below. Modules mirror the logic — `body`, `needs`, `intent`, `perception` — plus a rule-based Lua StubBrain. Each of the three bots gets its own needs profile from a table.
3. **Brain** (`brain/`, Python, v3 only). A small HTTP service: one endpoint `POST /decide` taking the perception payload plus a bot id, returning an `Intent` as JSON. Runs on a machine on the local network with a local model (Ollama or similar); the device only renders and sends requests.

### The load-bearing contract

`Perception → Intent` is the load-bearing contract — the same one StubBrain answers, so swapping brains changes nothing in the body — and **must not change without an entry in `docs/decisions.md`**. Intents are `goto` / `build` / `rest` / `wander` / `idle` (plus an optional `say` later); the body executes one intent for hundreds of ticks alone. The brain wakes only on four conditions — cold start, a substantive intent finishing, a need crossing the urgency threshold while drifting, or the heartbeat interval. Budget: roughly one brain call per 18 ticks per bot; the v2 acceptance test checks it. The request/poll asynchrony is mandatory: the mod fires the request, keeps executing the previous intent, and picks the answer up on a later step. **Never block a bot tick waiting on the network**, and always fall back to the Lua StubBrain when the server is absent (a local model answers in seconds).

Pathfinding uses the stock `core.find_path`; perception reads the real nodes around the entity.

## Milestones

Five versions in [ROADMAP.md](specification/ROADMAP.md), built in order. Phases inside a version are
`vA.B`, and a release is cut per phase (`v1.2` → `1.2.0`).

- **v0 — the device: one player, one island, at a measured frame rate.** **Shipped, through `0.8.0`**:
  Luanti running fullscreen from Sway, touch and the gamepad keys working, terrain, meltwater,
  growths and a day-night cycle built out of our own 13 blocks, the scanner hand and the styled
  hotbar, the colony asset pack installed, and three graphics profiles measured on the device — avg
  fps, min fps and drawtime after 30 s of walking, same seed and start point — recorded in
  `docs/decisions.md` with screenshots in `docs/device/`. No bots, no brain, no mutations: anything
  that did not help answer "what can this device do" was not in it. **v0.9 is the review pass**, and
  it is the phase in progress: the 71 findings of the review at `0.8.0`, closed before v1 is
  generated, because `generate-issues` decomposes these documents and a stale document becomes stale
  code.
- **v1 — the world: H11 mutates it.** Three biomes replacing v0's single technical registration, the
  mutation cycle on ABMs with the rules table behind it, a visible glyph on everything the algorithm
  has touched, the cycle HUD and a saved log, and catch-up for a world that was away.
- **v2 — the inhabitants: three bots on rules.** `h11_bots` — bodies on fast ticks, needs that decay,
  intents executed over hundreds of ticks, perception, and a Lua StubBrain that needs no network —
  the three characters, reacting to what H11 does to the world, and Observe/Follow. `h11_build`, the
  part catalogue and the builder a model's plan is expanded into, belongs with them
  (ARCHITECTURE.md §The build catalogue).
- **v3 — the brain: a model on the local network.** `POST /decide` on the LAN box, the HTTP bridge
  from the mod, the StubBrain fallback whenever the server is absent, and the three characters in
  language.
- **v4 — the argument: the player takes a side.** The H11 anchor from the reference art, a placeable
  device that suppresses mutation in a radius; conversation with the bots through the `say` field;
  and whatever the first three versions prove is missing. Deliberately underspecified until v3 ships.

Catching up missed cycles is **settled** and is not replay: the mutation frontier is a pure function
of position, cycle and seed, so a block loading after a week away computes its current state in one
step (ARCHITECTURE.md §Mutation is an infection).

## Device constraints that affect every feature

Render at native 640x480 — `fullscreen`, `screen_w = 640`, `screen_h = 480`, one render pixel per
panel pixel, because any other size resamples hand-drawn 32x32 art. **Always hardware-accelerated**,
and the driver is `video_driver = opengl`, **not** `ogles2`: Debian trixie's 5.10 is the legacy
Irrlicht X11 build, it contains the strings `ogles2` and `opengl3` so both look valid, and it rejects
both at runtime with *Invalid video_driver* and then dies with *Need running XServer*. The path is
GLX → XWayland → Mesa V3D and it is still hardware (`docs/decisions.md`, "The device renders through
GLX on XWayland, not EGL on Wayland"). A silent llvmpipe fallback voids every fps number, so
`tools/gpu_preflight.sh` probes GLX on the display the game will use *before* a run, and
`tools/deploy_to_term35.sh` reads the engine's own renderer line back out of `h11v-debug.txt`
*after* it — which is why the shared conf sets `debug_log_level = info`: at the engine's default
level the log carries no driver lines at all and that check could not fire.

Touch drives look and block taps: `touch_controls = true` **and** `touch_use_crosshair = true`,
because the default style draws no crosshair at all, and with the crosshair the target is what is
being aimed at rather than where the finger lands. `touch_use_crosshair` is the name 5.10 knows;
`touch_interaction_style` does not exist in this build and is deliberately absent from the conf — a
setting that does nothing reads like a setting that does something, and the next person debugging
touch would start with the one line that cannot be the cause. The device's buttons are ordinary
keyboard keys rather than a joystick, so they are a keymap: `tools/device/gamepad.conf`, appended by
the deploy and never by `run_local.sh`, takes movement off WASD and onto the D-pad, puts jump on A,
sneak on B, place on X, dig on Y, yaw on L and R (through `turn.lua`, because the engine has no
keybinding for the camera) and cycles the hotbar on Select. The digits 1-8 still pick a slot, and on
the Mac WASD still moves — which is why that file is device-only.

Readable at arm's length, and **`hud_scaling` and `gui_scaling` are two settings solving two
problems**: `hud_scaling = 1.4`, because the hotbar is a touch target and the minimum UI element is
48 px; `gui_scaling = 1.0`, because at 1.4 the engine's own desktop-laid-out dialogs are simply
*wider than 640 px* and the pause menu's controls column ran off the right edge with no way to reach
it. `font_size = 14` (and `chat_font_size = 14`) is the other half of that defect and a different
fix: at 20 the Change Keys labels overflowed their own cells and ran together. Both are recorded in
`docs/decisions.md`, "The engine's dialogs needed two different fixes, not one" — raising either one
back up reintroduces a measured defect. `viewing_range` is 40 / 60 / 100 nodes by profile
(low / mid / high) and `enable_dynamic_shadows = false` in all three; shadows are measured as a
separate fourth run because they are the single most likely thing to be unaffordable.

Hotbar **width** is the binding constraint, not height: 8 slots at the engine's 48 px base times
`hud_scaling` 1.4 plus padding span roughly 627 of the 640 available pixels, which is also why there
is no ninth slot. `h11_hotbar.png` is eight identical cells precisely so a 6-slot crop stays lossless
if the panel ever says otherwise, and `check_assets.py` asserts that.

The shared settings live in `tools/device/minetest.conf`; the three `device-{low,mid,high}.conf` files
hold only the deltas that define a profile, and `deploy_to_term35.sh` concatenates base plus profile
into the single config the device runs, so switching profiles is a redeploy rather than an edit on the
device. Two shared values are worth knowing before adding anything that runs per tick or claims a
number: `dedicated_server_step = 0.02`, because the camera is turned by a mod and the server step is
how often the view moves, and `fixed_map_seed = 20260913`, because three profiles compared on three
different worlds are not a comparison.

## Working rules

- **Work runs through the pipeline in [SDLC.md](specification/SDLC.md).** `/ship-phase v0.2` drives a
  roadmap phase end to end; the ten skills in `.claude/skills/` are also usable singly. One issue,
  one commit. Issue ids are `H11V-###`, globally sequential, never reset.
- **The five gates** ([ARCHITECTURE.md](specification/ARCHITECTURE.md) §Acceptance and testing):
  `tools/check_lua.sh`, `tools/test_worldgen.sh` and `tools/check_assets.py` run for *every* issue —
  the third because it carries the node-catalogue contract as well as the art one, and it costs a
  second; `tools/run_local.sh` whenever anything visible changed; and a device run whenever a
  frame-rate budget is claimed. Never commit on a red gate.
- **Commit messages in English**; README and the player guide in **Ukrainian**.
- **Credentials never enter the repository.** The device's details live in `.term35-connect.txt` and
  the v3 brain host's in `.brain-connect.txt` — both gitignored, read at run time, never echoed. The
  brain runs on the LAN box `ich-picobox`, never on the Mac: the Mac's firewall kills inbound LAN
  connections before the first read. The `codegen/` hook is forbidden from recording raw command strings for the same reason.
- Do not add mechanics from the out-of-scope list ([VISION.md](specification/VISION.md) §Not this): infinite world, crafting recipes, hostile mobs, combat, multiplayer, custom renderer.
- The project stands alone: do not pull code, prompts, or assets in from other repositories.
- Media assets must be self-made or CC0. Luanti is LGPL; the game mods carry their own license.
- The 5.8 aarch64 touch regression is **closed**: it was a 5.8 bug and the device runs 5.10.0
  (`docs/decisions.md`). Touch on the panel is still confirmed by looking at it, not by the
  version number.

## Open questions

Three remain, none blocking the game, and [VISION.md](specification/VISION.md) §Still open is their home: how long one mutation cycle lasts in real time; which local model runs on the brain server — the host is settled and probed (`ich-picobox`, four cores, no discrete GPU, so inference is CPU-bound and the 1-3 s budget points at a small quantized model), the model itself is not; and whether the README and player guide stay Ukrainian while code and specs are English. The music's licence was the fourth and is now answered: the track is the author's own Suno generation (`docs/decisions.md`, 14 Sep 2026). Art direction, texture resolution (32x32, after the 16x16 trial was built and reverted on the device), asset sourcing and the bots' names/needs are settled — see [ART-COLONY.md](specification/ART-COLONY.md) and `docs/decisions.md`. Ask rather than assume when work touches the open three; record answers in `docs/decisions.md`.
