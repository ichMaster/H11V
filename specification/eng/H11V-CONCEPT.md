# H11V — concept brief for Claude Code

> H11V is a Minecraft-like game for a pocket device: a first-person player and three bots share one voxel world, and above them all runs the H11 algorithm, which slowly mutates both the land and its inhabitants.

This document is a briefing for Claude Code. It records the idea, the constraints, the decisions taken, and the questions still open. Section 10 holds the decisions taken so far; section 11 holds what still has to be settled with Vitalii before M2 begins; section 12 fixes the art direction.

H11V is a self-contained project. It does not depend on, import from, or share a codebase with anything else; everything it needs is described here.

Tagline (canon, from the reference art): **Build. Explore. Compute. Together.**

## 1. The idea

A Minecraft-like world where the player builds, digs and explores, but the point of the game is not crafting — it is cohabitation. Three bots live in the world, and everything, world and bots alike, is subject to Hypothesis 11: there exists an algorithm that mutates the environment and the creatures inside it. The player watches biomes, blocks and bot behaviour change from cycle to cycle, and can influence that: protect patches of land, feed the mutation, build. The mood is not horror but uneasy curiosity — the world is alive, luminous, and not entirely yours.

## 2. Development setup

The target device is the Waveshare PocketTerm35: a Raspberry Pi 5 with 4 GB, a 3.5-inch 640x480 touchscreen, a keyboard, Raspberry Pi OS with Sway (Wayland), no mouse. Development happens on a MacBook M1, so every feature needs a way to run on the Mac and a way to run on the device.

The LLM brain service (M3) runs on a separate machine on the local network, not on the device itself; the device only renders and sends requests.

## 3. The game concept

The world is small and pocket-sized: a single map on the order of 128x128 blocks, a few biomes, no infinite generation. The player is first-person, steers with touch (look) and keyboard (movement), and can dig, place blocks and gather resources.

Three bots live in the world — entities with a body and a brain. They explore, build and rest on their own; the brain is consulted only at moments that matter. Three rather than one, so that visible differences emerge between them after mutations. All three share one needs model — **energy**, **curiosity**, **safety** — but each weights it differently, and that weighting is the character:

- **DRIFT — BOT 01, cyan.** Curiosity-dominant: roams the far edge of the map, first to walk into freshly mutated ground.
- **ECHO — BOT 02, amber.** The balanced observer: wanders, watches the player and the other bots, lingers where things change.
- **MOSS — BOT 03, green.** Safety- and energy-dominant: builds shelters, rests often, tends one home patch and defends its routine.

The player can stand nearby and watch, build the bots shelter, hinder them or help them. From M2 the HUD offers per-bot interactions — **E Observe** (open the bot's panel: state, needs bars, current intent) and **R Follow** — and later, talking (the `say` field in an intent). In the first version the bots live on rules (a StubBrain in Lua); the LLM brain arrives at M3.

The H11 algorithm is the game's mutation loop. Once every N minutes (one cycle) it changes the rules of the world in small steps: one block type starts behaving differently (grass grows as stone, water freezes, ore migrates), a biome shifts, and one of the bots has a needs parameter changed or gains a new intent type. Mutations are visible: old blocks stay, new ones appear marked with the H11 glyph. The player sees the cycle number and a log of changes. This is Hypothesis 11 embodied as a mechanic — environment and creature evolve together, and the player is a witness and a part-time gardener.

There is no winning. There is a session a few cycles long, after which the world is saved and keeps mutating even while the device is off (the next launch catches the missed cycles up in a simplified way).

## 4. Engine: the decision

**Luanti** (formerly Minetest) is the choice. Why: an open-source voxel engine in C++ with chunks, lighting, generation, saving, inventory and multiplayer already in place; it is in the Debian repositories, so it installs on a Pi 5 as a single package and runs on OpenGL ES; it has touch controls; a game is written as a set of Lua mods, so we write content rather than an engine; and it ships a headless server, `luantiserver`, for automated tests without a screen.

The H11 mechanics map onto stock Luanti primitives with almost nothing invented: block types are `core.register_node`; world mutations are Active Block Modifiers (`core.register_abm`) and LBMs; a creature is `core.register_entity` with its own `on_step`; state persistence is mod storage; HTTP to the brain is `core.request_http_api` (the mod must be listed in `secure.http_mods`).

The alternative is Godot 4 with the godot_voxel module. Choose it only if a custom renderer becomes genuinely necessary. The price is building the module yourself for Linux arm64 plus your own chunks, lighting and saving; for this concept that is dead weight.

Unity and Unreal were rejected earlier: Unity does not offer Linux arm64 without an Industry licence, and Unreal on a Pi requires a patched engine build with no guarantees.

## 5. Architecture

Three layers.

**World and rules (Lua, mod `h11_world`).** Blocks, biomes, the mutation cycle and the cycle log. (The HUD that displays the cycle is a separate concern and lives in `h11_hud` from M1 — see the layout below.) The block catalogue is a data table from M0 on (see the M0 spec, section 8), and mutations are described as data over that same catalogue — a table of "rule → block transformation → condition" — rather than as code, so that a model can propose them in the future. In M0 `h11_world` is the only mod and also carries the player layer; the split below begins when there is a second concern to separate.

**Bot bodies (Lua, mod `h11_bots`, from M2).** The body runs inside the entity's `on_step` on fast ticks and needs no network: needs decay over time, one intent is executed over hundreds of ticks, and the brain is woken only by four conditions (cold start, a substantive intent finishing, a need above the urgency threshold while merely drifting, and a heartbeat interval). Pathfinding uses the stock `core.find_path`; perception reads the real nodes around the entity. The mod is split the way the logic is: `body`, `needs`, `intent`, `perception`, plus a rule-based StubBrain in Lua so the bots live without a server. Each bot's character is its needs weighting from section 3, a table in the mod.

**Brain (Python, service `h11_brain`, not in the first version).** A small HTTP service with one endpoint, `POST /decide`, which takes the perception payload plus a bot identifier and returns an `Intent` as JSON. It runs on a machine on the local network with a local model (Ollama or similar). The `Perception → Intent` contract is the same one the StubBrain answers, so swapping brains changes nothing in the body. Asynchrony is mandatory: the mod sends the request, carries on executing the previous intent, and picks the answer up on a later step. With no server, the bots fall back to the StubBrain.

Repository layout:

```
games/h11v/           the Luanti game (game.conf, menu/, mods/)
  mods/h11_world/     world, rules, and (in M0) the player layer
  mods/h11_bots/      bot bodies + StubBrain (from M2)
  mods/h11_hud/       cycle HUD, bot panels (from M1-M2)
brain/                Python brain service for the LAN machine (from M3)
tools/                scripts: headless test runs, device profiles, deployment to the Pi
specification/        eng/ (source of truth), ukr/ (Ukrainian mirror), art/ (canonical references)
docs/                 the decisions log and device measurements
```

The M0 spec, section 7, expands the M0 slice of this tree file by file.

## 6. Device and controls

Rendering at the native 640x480, always on the GPU: the Pi 5's V3D hardware driver via GL ES, verified at M0 — a silent llvmpipe software fallback voids every measurement (M0 spec, sections 5 and 8). Touch for looking and tapping blocks, keyboard for movement (WASD), jumping and inventory: the standard Minecraft scheme on phones with a keyboard, which Luanti already has. Minimum UI element 48 pixels, HUD font twice the usual size, `viewing_range` 40-100 nodes depending on the graphics profile (M0 spec section 5), shadows off. The device profile is a separate `minetest.conf` under `tools/`, which the deploy script copies to the Pi.

## 7. Milestones

**M0 — groundwork (1-2 evenings).** Luanti on the PocketTerm35: package, Wayland, touch, fps in an empty world. This tests the hypothesis about the device, and no line of game code is written before it. The M0 specification widens this into the first playable slice — terrain, blocks, trees, a day-night cycle, the designed asset pack, and measured graphics profiles; see [H11V-M0-SPEC.md](H11V-M0-SPEC.md).

**M1 — the H11 world (a week).** Mod `h11_world` grows up: three biomes, the first mutation cycle on ABMs, a saved log. The new mod `h11_hud` arrives alongside it with the cycle number, the H11 event card and the world-change card from the reference art (bot panels follow at M2). (Block types and terrain arrive in M0.) Headless test: start `luantiserver`, wind N cycles forward, check that the mutations were applied.

**M2 — bots (a week).** The body and the StubBrain in Lua. DRIFT, ECHO and MOSS visible, walking, building, resting, reacting to world mutations through the safety need; the Observe/Follow interactions and the bot panel from the reference art. Test: a headless run of 4000 steps without crashes, with brain calls staying within budget — about one per 18 ticks per bot.

**M3 — the brain on the server (after the first version).** The `h11_brain` service on a machine on the local network with a local model, an HTTP bridge from the mod, and a fallback to the StubBrain when the server is absent. Three bots with different character prompts derived from section 3.

**M4 — player and cycle (open).** Tools for influencing mutations — the reference art sketches one, the **H11 anchor**, a placeable device that suppresses mutation in a radius; conversation with bots; catching cycles up after a shutdown.

## 8. Out of scope

No infinite world, no crafting with recipes, no hostile mobs or combat, no multiplayer in the first year, no custom renderer. All of it exists in Luanti and can be switched on later, but none of it is part of this concept.

## 9. Risks

Touch in Luanti on Linux had a regression in 5.8 on aarch64 — verify at M0. The Luanti version in the Pi OS repository may lag; the fallback is an AppImage or a Flatpak. A local model on the server answers in seconds, so keep the heartbeat high and the intents broad, and never block a bot tick waiting for an answer. Licensing: Luanti is LGPL and the game as a set of mods carries its own licence; media assets are to be made in-house or taken as CC0.

## 10. Decisions taken

**12 September 2026.** The project is called **H11V**. The player plays first-person in the same world. Three bots live in the world with brains of their own; in the first version they run on rules, and the LLM brain is added later and runs on a machine on the local network with a local model. H11 mutations are deterministic rules from a table.

**13 September 2026.** The specifications are kept in English under `specification/eng/`; they are the source of truth. `specification/ukr/` holds a Ukrainian translation of the same documents, re-translated whenever the English changes — when the two disagree, English wins. H11V is a standalone project: no code, prompts or assets are carried in from anywhere else.

**13 September 2026, art and design.** The art direction is the bright-luminous canon of section 12, per the reference images in `specification/art/` — not a dark palette. Textures are 32x32. All assets come from a designed pack ordered through [H11V-M0-DESIGN-BRIEF.md](H11V-M0-DESIGN-BRIEF.md); there is no procedural texture generation. The bots are canon from the art: DRIFT (BOT 01, cyan), ECHO (BOT 02, amber), MOSS (BOT 03, green), sharing the needs triad energy / curiosity / safety with per-bot weightings (section 3).

## 11. Open questions

1. Time: how long does one mutation cycle last in real time on the device — minutes (a game for a single session) or hours and days (a world that lives in the background)?
2. Which local model runs on the brain server — sized to answer in 1-3 seconds for three bots — and does that machine have a GPU?
3. Language of the code and of the player-facing documentation: Lua code in English with Ukrainian READMEs? (The specifications are English as of 13 September 2026; the README and the player guide are still open.)

## 12. Art direction

Canonical references, in `specification/art/`:

- `ref-01-h11-event.png` — a mutation cycle rollover. Canonizes two distinct cards: the centred **H11 event card** (hex glyph, title, cycle N → N+1, "mutation detected") and a separate **world-change card** at mid-right (a before → after block pair plus a one-sentence note). Also: the H11 hex-cluster glyph, glowing glyph stencils on mutated blocks, H11V banner posts in the world, the top-right cycle counter and clock, the three bot status bars, the bottom-left state line (`H11 // MUTATION ACTIVE`), and the 8-slot hotbar with counts.
- `ref-02-bot-echo.png` — the bot panel. Canonizes: ECHO's look (ivory rounded quadruped, black face screen with cyan eyes, amber accents, unit number on the chest), the panel layout (name, BOT NN, state, three needs bars, intent line), the E Observe / R Follow interactions, and `H11 // STABLE`.
- `ref-03-anchor-biomes.png` — the H11 anchor and the mutated biome. Canonizes: the anchor device and its suppression-dome rendering, the anchor card (suppression %, radius), and the mutated-biome look — pale lithic structures and lilac crystal growth replacing the green biome.

**Palette.** Bright and luminous, never grim: vivid greens and warm browns for the living biome; ivory and warm pale grey for stone and lithic growth; pale warm sand; teal-cyan luminous water; a lilac-lavender family for everything mutation has touched; bright sky with soft clouds. Accents: cyan (BOT 01, HUD primary), amber (BOT 02, highlights), green (BOT 03, positive state). HUD panels are dark translucent glass with thin light borders, so the bright world shows through.

**Type and HUD.** Monospaced, all-caps, generously tracked HUD text, as in the references. Screen-relevant sizes only: everything must survive 640x480 at 3.5 inches — minimum UI element 48 px, no hairline strokes.

**The H11 glyph language.** H11 marks everything it has touched: a hex-cluster logo glyph, and small circuit-like stencil glyphs etched into mutated blocks with a faint cyan-to-lilac glow. Glyphs are decoration with meaning — they signal "changed by H11", never mere noise.

**The player.** Present in the world as an ivory gauntlet with medium-blue accents and a dark grey band (first-person hand), kin to the bots' design language — the player is a unit in the same ecosystem, not an outsider. The blue is the references' own hand colour (around `#6E8AB8`) and is deliberately *not* the HUD cyan: the interface glows cyan, the player's body does not.

**Aspirational vs literal.** The references show floating islands, waterfall cliffs and spiral megastructures; on the device those read as skybox mood and distant vista, not literal terrain — the playable map stays the 128x128 pocket world. UI cards, palette, bot design and glyphs are literal canon.

## 13. Working rules for Claude Code

Before coding a milestone, re-read this document and `docs/decisions.md`, into which sections 10 and 11 migrate as they are settled. Every milestone ends with a headless test that runs with a single command from `tools/`. The `Perception → Intent` contract is not to be changed without an entry in the decisions log. Do not add mechanics from section 8. Do not pull code, prompts or assets in from other repositories — this project stands alone. Commits small, commit messages in English; the README and the player guide in Ukrainian.
