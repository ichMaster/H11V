# Roadmap — H11V

Five versions, built in order: **v0** the device (one player, one island, measured on the panel) →
**v1** the world (H11 mutates it: biomes, rules, cycles, a visible log) → **v2** the inhabitants
(three bots living on rules) → **v3** the brain (a local model on the LAN gives them judgement) →
**v4** the argument (tools for the player to influence, protect and talk).

Versions are numbered from 0; phases inside a version are `vA.B` (A = version, B = phase), e.g.
`v1.2`. Each phase lists a **Goal**, a short description, **Tasks**, a **Definition of Done**, and
the **Tests** that encode that DoD — added to the five acceptance runners in
[ARCHITECTURE.md](ARCHITECTURE.md) §Acceptance and testing, never to a new framework.

**Versioning (`A.B.C`).** `A` = roadmap version, `B` = phase within it (`v1.2` → `1.2.0`), `C` = a
post-release fix on that phase. Releases are cut per phase. Never bump the version without explicit
confirmation. Nothing is released yet; the first tagged release will be **`0.1.0`**.

**The two axes.** *The world* grows one island → biomes → a mutation cycle → a world that edits
itself. *The inhabitants* grow nothing → three rule-driven bodies → bodies with a language model
behind them. They meet at the mutation cycle: v1 makes the world change, v2 puts creatures in it that
notice, v3 makes those creatures able to reason about what they noticed. Complexity is added by
version, never all at once.

**Source of the plan.** The version list is the milestone arc in [VISION.md](VISION.md), decomposed.
v0 is the old M0 specification, phase by phase; v1–v4 are the old M1–M4 with the same content and
sharper boundaries.

---

## v0 — The device: one player, one island, at a measured frame rate

The proof that the whole loop closes on real hardware: a Luanti game of our own generates a world out
of our own blocks, a player walks and digs it on a 3.5″ panel, and the frame rate is measured on the
GPU rather than guessed on a Mac. No bots, no brain, no mutation — anything that does not help answer
"what can this device do" is not in this version. **Depends on:** nothing.

The asset pack is already delivered ([ART.md](ART.md) §9), so no phase here waits on external work.

### v0.1 — Toolchain and skeleton

**Goal:** the game appears in Luanti's menu on both machines and creates a world.

Install Luanti on the Mac and on the PocketTerm35 (Pi OS package; AppImage or Flatpak if the
repository version lags — this is also the first check of the aarch64 touch regression in 5.8). Run
the GPU preflight on the device before anything else. Then `games/h11v/game.conf` and an empty
`h11_world` (`mod.conf`, `init.lua`).

**Tasks:** install both; GPU preflight (`mesa-utils`, renderer must be V3D); `game.conf`; empty mod.

**DoD:** both Luanti versions and the device renderer string are recorded in `docs/decisions.md`; the
game is selectable in the menu and creates a world without errors.

**Tests:** `check_lua.sh` green; the engine's debug log names V3D, not llvmpipe.

### v0.2 — Blocks and terrain

**Goal:** our own blocks, and a horizon with elevation rather than a slab.

`nodes.lua` with the full `NODES` table and the registration loop; `mapgen.lua` with the mapgen
choice and parameters, the three structural aliases, and one `core.register_biome` for the surface
layers. First version of `test_worldgen.sh`.

**Tasks:** `NODES` table (9 nodes, correct tile triples); mapgen parameters; structural aliases;
surface biome; `test_worldgen.sh` asserting elevation range.

**DoD:** a generated world has turf on top and dirt under it — not bare stone — with a surface
elevation range of at least 8 blocks, **and the engine log is clean**: registering the aliases closes
the three `Mapgen alias ... is invalid!` errors that v0.1's empty mod necessarily leaves behind (the
engine demands them before any node exists to satisfy them).

**Tests:** `test_worldgen.sh` asserts elevation range ≥ 8 and that the top node is `h11_world:turf`.

### v0.3 — Water and trees

**Goal:** the island reads as a place: water that flows, trees that stand.

The water source/flowing pair, cross-referenced. Tree decoration with a Lua-table schematic (trunk
column plus leaf blob), which keeps trees out of the walking-and-digging hot path entirely.

**Tasks:** water pair; tree schematic and decoration; extend `test_worldgen.sh` to the full
assertions.

**DoD:** water is present and flows when the shoreline is dug — no unknown-node checkerboards; at
least 20 trees in a 128×128 area.

**Tests:** `test_worldgen.sh` asserts water present and tree count ≥ 20.

### v0.4 — The asset pack

**Goal:** the world looks like the art direction instead of like placeholder checkerboards.

Install the delivered pack per [ARCHITECTURE.md](ARCHITECTURE.md) §Assets and strip the content
credentials metadata on the way in. Wire `tools/check_assets.py` as a gate.

**Tasks:** rsync the pack into `games/h11v/`; strip `caBX` chunks; `check_assets.py`; verify every
`NODES` entry resolves.

**DoD:** no missing-texture checkerboards anywhere in a Mac run; water reads translucent over its
bed; leaves show their holes; the H11 glyph is legible on the crust block.

**Tests:** `check_assets.py` green; `run_local.sh` by eye.

### v0.5 — The player layer

**Goal:** walk, dig, place, and a HUD that fits the panel.

`player.lua`: the hand overridden with `tool_capabilities` for the four dig groups and the gauntlet
wield image; the starting inventory; a surface spawn; the 8-slot hotbar with the designed bar and
selection frame; the crosshair; and `hud_set_flags` hiding health and breath, which v0 does not use.

**Tasks:** hand; inventory; spawn; hotbar; crosshair; HUD flags.

**DoD:** on the Mac at 640×480 the player walks, jumps, digs every block type, places every block
type, and passes a full day-night cycle; the hotbar fits the width with margin.

**Tests:** `run_local.sh`; hotbar width checked against the 640 px budget (8 slots ≈ 627 px at
`hud_scaling` 1.4 — cut to 6 or lower the scaling if it overflows).

### v0.6 — Device profiles and scripts

**Goal:** one command puts the game on the device and one command runs it the same way on the Mac.

`tools/device/minetest.conf` plus the three profile deltas; `run_local.sh`, `run_on_pi.sh`,
`deploy_to_term35.sh`. The Sway scale dance (drop the panel to scale 1 for the game, restore it
after, survive a SIGKILL) lives in `run_on_pi.sh`.

**Tasks:** base config; three profiles; the three scripts; credentials file documented.

**DoD:** `deploy_to_term35.sh` copies the game and a assembled profile config, starts the game, and
the game outlives the ssh session that started it; `--stop`, `--log` and `--profile=` all work;
`run_local.sh` reproduces device settings in a 640×480 window.

**Tests:** a deploy round-trip; `bash -n` on every script.

### v0.7 — The measurement session

**Goal:** answer the question v0 exists to ask, in numbers, on the device.

Run the three profiles plus the dynamic-shadows run, same seed and same spot, 30 seconds of walking
each, average and minimum fps from the F5 debug overlay. Judge and write down in words: the
legibility of 32×32 textures at 3.5 inches, graininess and shimmer at distance, how the
bright-luminous palette holds up at night, whether the glyph reads at typical viewing distance.

**Tasks:** the four measurement runs; screenshots per profile into `docs/device/`; write
`docs/decisions.md`.

**DoD:** `docs/decisions.md` records fps per profile, the chosen default profile, the Luanti version
and the renderer string; screenshots exist for each profile; the GPU preflight was green for all of
it.

**Tests:** the preflight; measurements on a software rasterizer are void and must be re-run.

---

## v1 — The world: H11 mutates it

The world grows a pulse. A cycle counter, a table of deterministic mutation rules applied by Active
Block Modifiers, a visible glyph on everything the algorithm has touched, and a HUD that tells the
player what just changed. **Depends on:** v0.

### v1.1 — Biomes

**Goal:** three biomes instead of one technical registration.

**DoD:** three distinguishable biomes generate, each with its own surface and character; the v0
acceptance assertions still pass.

### v1.2 — The mutation cycle

**Goal:** the world changes on a clock, by rule, and remembers that it did.

The rules table (`rule → block transformation → condition`), the ABMs that apply it, the cycle
counter in mod storage, and the cycle log. Old blocks stay; mutated ones carry the H11 glyph.

**DoD:** winding N cycles forward on a headless server applies the expected transformations and
writes a log that survives a restart.

**Tests:** `test_worldgen.sh` grows a cycle-advance mode: run N cycles, assert the transformations
and the persisted log.

### v1.3 — The cycle HUD

**Goal:** the player can see the algorithm working.

The new mod `h11_hud`: the cycle number and clock, the H11 event card at a rollover, the separate
world-change card (before → after block pair plus a one-line note), and the bottom-left state line.

**DoD:** a cycle rollover is legible at 640×480 on the device without covering the play area.

**Tests:** `check_assets.py` for any new UI art; the device by eye.

### v1.4 — Catch-up

**Goal:** the world keeps mutating while the device is off.

**DoD:** a world loaded after a simulated week advances its cycles in a bounded, simplified way
rather than running them all.

---

## v2 — The inhabitants: three bots on rules

DRIFT, ECHO and MOSS: bodies on fast ticks, needs that decay, intents executed over hundreds of
ticks, and a Lua StubBrain that needs no network. They react to what H11 does to the world.
**Depends on:** v1.

### v2.1 — The body

**Goal:** one bot walks, and its body never blocks.

`h11_bots` with `body`, `needs`, `intent`, `perception` and the StubBrain; `core.find_path` for
movement; perception reading the real nodes around the entity.

**DoD:** a headless run of 4000 steps without crashes, with brain calls staying within budget —
about one per 18 ticks per bot.

**Tests:** a headless bot-run mode asserting step count, no errors, and the call budget.

### v2.2 — Three characters

**Goal:** the three read as different creatures, not three copies.

The needs weightings from [VISION.md](VISION.md): DRIFT curiosity-dominant, ECHO balanced, MOSS
safety- and energy-dominant.

**DoD:** over a long headless run the three produce measurably different intent distributions.

### v2.3 — Reacting to mutation

**Goal:** the bots notice what the algorithm does.

**DoD:** a mutation inside a bot's perception radius changes its next intent through the safety need.

### v2.4 — Observe and Follow

**Goal:** the player can watch a bot think.

The bot panel from the reference art — name, state, three needs bars, current intent — on **E
Observe**, and **R Follow**.

**DoD:** the panel opens on the device, is legible at 640×480, and closes cleanly.

---

## v3 — The brain: a model on the local network

The `h11_brain` service on a LAN machine with a local model, an HTTP bridge from the mod, and a
fallback to the StubBrain whenever the server is absent. The bots gain judgement and character
prompts. **Depends on:** v2.

### v3.1 — The service

**Goal:** `POST /decide` answers with an `Intent`.

**DoD:** the service takes a perception payload plus a bot id and returns a valid intent in 1–3
seconds for three bots.

### v3.2 — The bridge

**Goal:** the mod asks, and never waits.

`core.request_http_api`, the mod in `secure.http_mods`, request/poll asynchrony, StubBrain fallback.

**DoD:** with the server unplugged mid-session the bots keep living with no frame-rate change; with
it plugged back in they resume asking.

**Tests:** a headless run with the server absent must match the v2 budget and crash count exactly.

### v3.3 — Characters in language

**Goal:** three prompts, three voices, derived from the same needs weightings.

---

## v4 — The argument: the player takes a side

Tools to influence mutation — the **H11 anchor** from the reference art, a placeable device that
suppresses mutation in a radius — conversation with the bots through the `say` field, and whatever
the first three versions prove is missing. **Depends on:** v3. Deliberately underspecified: what
belongs here is a decision for the day v3 ships.
