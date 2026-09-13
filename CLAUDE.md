# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This repo is **specification-only** — no code exists yet. Tracked files are `LICENSE` and a stock Python `.gitignore` (note: the game itself is Lua, not Python); everything else lives in [specification/](specification/). Single commit on `main`; no bot or brain code exists anywhere and none is carried in — it gets written fresh at M2/M3.

The specs are the source of truth and are kept in English under `specification/eng/`; `specification/ukr/` is a maintained Ukrainian mirror of them (re-translate it whenever the English changes — English wins on any disagreement), canonical art references in `specification/art/`:

- [specification/eng/H11V-CONCEPT.md](specification/eng/H11V-CONCEPT.md) — the full brief: concept, engine decision, architecture, milestones, out-of-scope list, decisions taken (§10), still-open questions (§11), art direction (§12), and working rules for Claude Code (§13).
- [specification/eng/H11V-M0-SPEC.md](specification/eng/H11V-M0-SPEC.md) — the concrete M0 milestone spec: scope, components, graphics-profile protocol, project structure (§7), architecture (§8), implementation plan (§9).
- [specification/eng/H11V-M0-DESIGN-BRIEF.md](specification/eng/H11V-M0-DESIGN-BRIEF.md) — the asset order for Claude Design: exact filenames/sizes are a contract with the code.
- `specification/art/ref-01-h11-event.png`, `ref-02-bot-echo.png`, `ref-03-anchor-biomes.png` — canonical art (concept §12 says what each canonizes).
- `specification/art/h11v/` — **the delivered M0 asset pack** (22 textures, 3 menu images, screenshot), audited and accepted. It mirrors `games/h11v/` exactly, so installing is `rsync -a specification/art/h11v/ games/h11v/` followed by a metadata strip (M0 spec §8). Treat it as the delivery of record: edit the game's copy, never this one.

Re-read both, plus `docs/decisions.md` once it exists, before starting a milestone.

## What H11V is

H11V is fully self-contained — no code, prompts, or assets come in from any other repository or project. It is a Minecraft-like voxel game for a pocket device where a first-person player and three bots share one small world (~128x128, no infinite generation), and the "H11 algorithm" mutates both the terrain and the creatures in slow, visible cycles driven by a data table of deterministic rules. There is no win condition.

Art direction is **bright-luminous** (concept §12): vivid greens, ivory stone, lilac mutation crystal, cyan sci-fi HUD — never dark/horror. Textures are 32x32 and come exclusively from the designed asset pack (delivered 13.09.2026, in `specification/art/h11v/`); there is no procedural texture generation. The bots are canon: **DRIFT** (BOT 01, cyan, curiosity-driven), **ECHO** (BOT 02, amber, balanced observer), **MOSS** (BOT 03, green, safety/energy-driven), sharing the needs triad energy/curiosity/safety.

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
| Headless tests | `luantiserver` |

Godot 4 + godot_voxel was considered and rejected for this project; Unity/Unreal are out (no Linux arm64 story on the Pi).

Luanti is **not currently installed on the Mac** — installing it (and on the Pi: Debian package, falling back to AppImage/Flatpak if the repo version lags) is part of M0.

## Planned layout

```
games/h11v/            Luanti game (game.conf, menu/ art, mods/)
  mods/h11_world/      blocks (NODES data table), mapgen aliases, player layer (M0);
                       biomes + mutation cycle + log (M1); textures/ = designed pack
  mods/h11_bots/       bot bodies + Lua StubBrain (M2)
  mods/h11_hud/        cycle HUD, bot panels (M1-M2)
brain/                 Python HTTP brain service for the LAN server (M3)
specification/         eng/ (specs, source of truth), ukr/ (Ukrainian mirror), art/
tools/                 run_local.sh, run_on_pi.sh, deploy_to_pi.sh, test_worldgen.sh,
                       device/minetest.conf + device-{low,mid,high}.conf
docs/                  decisions.md, device/ (fps notes, screenshots)
```

M0 spec §7 has the authoritative file-by-file M0 tree; §8 explains the module split (nodes/mapgen/player as data-driven Lua modules inside h11_world).

## Architecture: three layers

1. **World and rules** (`h11_world`, Lua). Mutations are described as *data* — a `rule → block transformation → condition` table — not as code, so a model can propose them later. Old blocks stay; mutated ones are marked with the H11 stencil. A cycle log and cycle number are player-visible.
2. **Bot bodies** (`h11_bots`, Lua). The body runs inside the entity's `on_step` on fast ticks, no network needed: needs decay, one intent executed over hundreds of ticks, brain woken only by the four conditions below. Modules mirror the logic — `body`, `needs`, `intent`, `perception` — plus a rule-based Lua StubBrain. Each of the three bots gets its own needs profile from a table.
3. **Brain** (`brain/`, Python, M3 only). A small HTTP service: one endpoint `POST /decide` taking the perception payload plus a bot id, returning an `Intent` as JSON. Runs on a machine on the local network with a local model (Ollama or similar); the device only renders and sends requests.

### The load-bearing contract

`Perception → Intent` is the load-bearing contract — the same one StubBrain answers, so swapping brains changes nothing in the body — and **must not change without an entry in `docs/decisions.md`**. Intents are `goto` / `build` / `rest` / `wander` / `idle` (plus an optional `say` later); the body executes one intent for hundreds of ticks alone. The brain wakes only on four conditions — cold start, a substantive intent finishing, a need crossing the urgency threshold while drifting, or the heartbeat interval. Budget: roughly one brain call per 18 ticks per bot; the M2 acceptance test checks it. The request/poll asynchrony is mandatory: the mod fires the request, keeps executing the previous intent, and picks the answer up on a later step. **Never block a bot tick waiting on the network**, and always fall back to the Lua StubBrain when the server is absent (a local model answers in seconds).

Pathfinding uses the stock `core.find_path`; perception reads the real nodes around the entity.

## Milestones

- **M0** — ground truth on the device: Luanti running fullscreen from Sway, touch + keyboard working, terrain/water/trees/day-night cycle, gauntlet hand + styled hotbar, designed asset pack integrated, three graphics profiles measured (low/mid/high, avg and min fps after 30 s of walking, same seed and start point) and written into `docs/decisions.md` with screenshots in `docs/device/`. No bots, no brain, no mutations. The asset pack is already delivered, so no M0 step blocks on external work (M0 spec §9).
- **M1** — `h11_world` grows up: three biomes, first mutation cycle on ABMs, cycle HUD, saved log (the 8 block types and the terrain already land in M0).
- **M2** — bots: body + StubBrain ported to Lua, three visible bots reacting to world mutations.
- **M3** — `brain/` service on the LAN with per-bot character prompts, HTTP bridge, StubBrain fallback.
- **M4** — player tools for influencing mutations, conversation with bots, catching up missed cycles after shutdown (open).

## Device constraints that affect every feature

Render at native 640x480, **always hardware-accelerated**: Mesa V3D via GL ES (`video_driver = ogles2`), verified by the M0 GPU preflight — a silent llvmpipe fallback voids all fps numbers; `run_on_pi.sh` greps Luanti's debug.txt for it and aborts. Touch drives look and block taps; the keyboard drives WASD, jump, and slot selection (`touch_controls` on). Minimum UI element 48 px, `hud_scaling`/`gui_scaling` ≈ 1.4, font 20, `viewing_range` 40–100 nodes by profile, shadows off. Hotbar width is the binding constraint, not height: 8 slots span ~627 of 640 px at `hud_scaling` 1.4 — drop to 6 slots or lower the scaling if it overflows. Touch needs the crosshair interaction style set explicitly; the default tap style draws no crosshair. The device profile lives in `tools/device/minetest.conf` and is copied to the Pi by the deploy script.

## Working rules

- Each milestone ends with a **headless acceptance test runnable by one command from `tools/`**. For M0 that is `tools/test_worldgen.sh`: start `luantiserver` with the game, emerge a 128x128 area, assert height variation ≥ 8 blocks, water present, ≥ 20 trees, exit 0.
- Small commits, one per step of the spec's work order. **Commit messages in English**; README and the player guide in **Ukrainian**.
- Do not add mechanics from the out-of-scope list (concept §8): infinite world, crafting recipes, hostile mobs, combat, multiplayer, custom renderer.
- The project stands alone: do not pull code, prompts, or assets in from other repositories.
- Media assets must be self-made or CC0. Luanti is LGPL; the game mods carry their own license.
- Known risk to verify early: Luanti touch input had a regression in 5.8 on aarch64.

## Open questions (concept §11)

Three remain, none blocking M0: how long one mutation cycle lasts in real time (minutes vs hours/days); which local model runs on the brain server and whether it has a GPU; and whether Lua code is English with Ukrainian READMEs (the specs are English with a Ukrainian mirror in `specification/ukr/`; the README and player guide are still open). Art direction, texture resolution, asset sourcing and the bots' names/needs were settled on 13.09.2026 — see concept §10 and §12. Ask rather than assume when work touches the open three; record answers in `docs/decisions.md`.
