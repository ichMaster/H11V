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
confirmation. Twelve releases are tagged, `0.1.0` through **`0.8.0`** — with `0.2.1` and
`0.7.1`–`0.7.3` as post-release fixes on their phases, which is what the third digit is for. `v0.9`
is the phase in progress.

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

The asset pack is already delivered, so no phase here waits on external work: the pack v0 was
planned around is audited in [ART.md](ART.md) §9, and the colony pack that replaced it in v0.8 — the
delivery of record, and what the code reads — in [ART-COLONY.md](ART-COLONY.md) §11.

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

### v0.8 — The colony retheme

**Goal:** stop the world looking like Minecraft.

Not planned when v0 was written, and added here after the fact because it shipped. The v0 world was
measured, playable and correct, and on the device it still read as Minecraft with a nicer palette —
because grass, soil, bark, leaves and cobble *are* the Minecraft vocabulary, and no recolour escapes
a vocabulary. So the vocabulary changed: a lander on an unsurveyed mineral planet, and the colony's
own hardware to build with.

**Tasks:** the art brief and its binding colour-separation rules
([ART-COLONY.md](ART-COLONY.md)); the asset pack, reviewed and revised twice; the catalogue rename
(`turf`→`regolith`, `dirt`→`fines`, `stone`→`lithic`, `sand`→`drift`, `trunk`→`spire`,
`leaves`→`bloom`, `water`→`meltwater`) with v0 ids kept as aliases; four colony blocks — hull,
prefab, crate, beacon; the scanner as the wield item; the gates and the probe retargeted.

**DoD:** the pack passes §4.1 with every deviation measured and adjudicated in
[ART-COLONY.md](ART-COLONY.md) §11 — which is not the clean sweep this line first claimed: Rule 1's
ladder holds every step but in the inverted order, now accepted and prescribed by §4.1; six of seven
collisions are closed and **`prefab` ↔ `regolith_side` is open for the next re-delivery** with its
2.9 L\* lever measured; Rule 5's fourth pair (`lithic` ↔ `lithic_top`, +2.9) is accepted with its
reason and the obvious fix refused on measurement; and **Rule 6 is unpassable by any six-material
ladder**, because white itself reaches only L\* 32.5 at 30% brightness, so it audits the lighting
and the emitting blocks answer it. The device runs the rethemed world with zero engine errors and no
unknown nodes; every acceptance gate green; the world is legible on the panel — terrain visible
between the growths, terraces and water readable.

**Tests:** `test_worldgen.sh` asserts `surface_top=h11_world:regolith` and `growths >= 20` — the
latter replacing a `trees >= 20` that had been silently demanding sixteen times the DoD, since
`trees` counts sampled columns rather than growths.

**Note for later phases.** Two things here were invisible to every gate and found only by pulling a
screenshot off the device: the growth density that was right for green canopies covered the world in
magenta at the same value, and the gate above was measuring the wrong quantity. The gates prove the
world contains what it should; they have no opinion about whether it can be looked at.

### v0.9 — The review pass

**Goal:** close the findings of the v0.8 full review, so v1 is built on documents that describe the
code and gates that measure what they claim.

Not planned when v0 was written. A 7-dimension adversarial review at tag `0.8.0`
([v0.8-code-review.md](implementation/v0.8-code-review.md), `codegen/` out of scope) raised 71
verified findings — 9 HIGH, 27 MEDIUM, 35 LOW — and their shape is the phase's shape: the code
survived adversarial reading almost untouched, while **six of the nine HIGHs are specification lines
that would misdirect the next contributor**, starting with `CLAUDE.md` still declaring the repository
"specification-only — no code exists yet" and prescribing a video driver the device build refuses to
start on. Fixing those before v1 is generated is the point of doing it now: `generate-issues`
decomposes these documents.

**Tasks**, grouped as they should be executed. Each finding id below refers to the review's summary
table.

1. **Credentials and the deploy** (H1, M4, M7, L13, L17). The device password reaches `ps`-visible
   argv through `rsync`'s `-e`, which rsync never masks — move every `sshpass -p` to `-e`. Make the
   post-launch renderer confirmation real rather than dead code (`debug_log_level = info`, grep the
   engine's own log, warn loudly when there is no evidence). Wait for the engine to be *gone* after
   the SIGKILL escalation before swapping the config, mirroring what `--stop` already does.
2. **The documentation pass** (H4, H5, H6, H7, H8, M21). Rewrite `CLAUDE.md`'s Current state,
   Device constraints and layout/milestones sections from `tools/device/minetest.conf` and
   `ARCHITECTURE.md`; bring `ARCHITECTURE` §Components (13 nodes, six modules) and §Assets (32×32,
   the colony pack) in line with the code; correct SDLC's `/ship-solution` row.
3. **Gate repairs** (H2, H3, M10, M11, M12, M13, M14, M16). Every one is a gate that lies or dies:
   `run_local.sh` forwards its own parsed flags to the engine and crashes on all documented usage;
   `check_assets.py --pack` audits the retired v0 pack; `check_lua.sh` parses with a Lua dialect the
   engine rejects; `mktemp -t` is a BSD-ism in a gate meant to run on the Pi; `MIN_TREES=4` silently
   demands 3.2× the DoD.
4. **Game code** (M1, M2, M3, M25, and the Lua LOWs). Pin `mgv7_spflags` so the "one dial" terrain
   claim is true outside the measured window; drop the inert `min_luanti_version`; stop `settle()`
   spawning the player on top of bloom crowns; set `zoom_fov = 0` so the engine stops drawing a zoom
   magnifier over the playfield that turns the camera when tapped.
5. **The art audit** (H9, M22, M23). The delivery inverted §4.1 Rule 1's ladder *order* while three
   documents certify compliance; two Rule-2 collisions and a fourth Rule-5 pair were never audited.
   Correct the audit, not the art.
6. **Design reconciliation** (M17, M18, M19, M20, M27). ROADMAP v1 still replays missed cycles that
   the architecture settles are never replayed; `h11_build` is scheduled in no phase; the plan seam has
   no transport; the v4 anchor contradicts the frontier function's stated purity; and the world-size
   debt `docs/decisions.md` owes to v1 is in no phase either. The world size landed here rather than in
   the documentation pass because it is not a wording fix: the bound is what v1.1's biomes are
   distributed across and what v1.2's frontier radius is measured against.
7. **Housekeeping** (L30, L32, L34, and the remaining LOWs). A `mod.conf` for the worldgen probe
   before an engine upgrade turns the per-issue gate red for an unrelated reason; five stray venvs at
   the repository root; the `docs/device/` screenshots marked as the pre-retheme record they are.

**DoD:** every HIGH and MEDIUM in the review's table is either fixed or explicitly re-classified as
deferred **in that document**, with the reason; the review document carries a Status per finding; all
five acceptance gates green; `tools/check_assets.py --pack` audits the colony delivery; no
specification document contradicts the shipped code on a load-bearing detail.

**Tests:** the existing gates, plus what this phase adds to them — `check_assets.py` must reject a
flattened RGB re-export of a binary-alpha texture and an out-of-band node resolution; `check_lua.sh`
must report which checker it used; `test_worldgen.sh` keeps passing after the `mgv7_spflags` change
(the terrain moves, so the numbers are re-recorded rather than the thresholds re-tuned).

**Note on scope.** `codegen/` findings are deliberately excluded from this phase. M15 (the
alpha-blind seam metric) is deferred to the next art re-delivery; M19 and M20 are recorded as design
constraints rather than implemented, since the code they constrain does not exist until v2 and v4.

---

## v1 — The world: H11 mutates it

The world grows a pulse. A cycle counter; a **frontier** that decides where the infection has
reached, as a pure function of position, cycle and seed; a table of mutation rules that decides what
a block inside it becomes, applied by Active Block Modifiers; a visible glyph on everything the
algorithm has touched; and a HUD that tells the player what just changed. **Depends on:** v0.

**The frontier selects, the rules transform**, and that division of labour is planned in
[ARCHITECTURE.md](ARCHITECTURE.md) §Mutation is an infection. It is not a detail of one phase —
every phase below is written against it, because the alternative fails in a way no gate would catch:
ABMs run only on loaded blocks, so selection by contact advances the infection only where the player
is standing, freezes when they walk away, and gives two players on one seed different worlds.
Nothing in this version replays a missed cycle; a block computes what it is now, once.

### v1.1 — The world's edges, and three biomes

**Goal:** three biomes instead of one technical registration — inside a world that ends.

Two tasks that are one conversation, and the reason they are here rather than in v0 is that both are
design questions rather than settings. Three biomes need an area to be distributed across, and
v1.2's frontier radius needs an area to be measured against; both are answers to "how big is this
world", which v0 deliberately left open (`docs/decisions.md`, "The world is still unbounded, and
'exactly 128×128' is not available"). The engine's `mapgen_limit` generates only mapchunks lying
**wholly** inside it and a mapchunk is 80 nodes, so the sizes on offer are quantised — 80×80,
240×240 — and the 128×128 VISION asks for is not among them. Pick one, or a soft barrier at 128
inside a larger generated region, and make VISION state the number that shipped instead of the
intention.

This is also the phase that pays for v0.9's `mgv7_spflags` pin. That pin made the terrain outside
the measured window honest — v7's mountain pass reached y = 179 at radius 2393 before it, y = 31
after — but honest terrain stretching to the horizon is still terrain the specification says does
not exist.

**Tasks:** choose the bound and set it; update [VISION.md](VISION.md) to the chosen number;
re-derive the worldgen thresholds from the sampled area the bound implies; three
`core.register_biome` registrations replacing v0's single technical one, each with its own surface
layers, growth and band on [ART-COLONY.md](ART-COLONY.md) §4.1's ladder — a new material takes a
rung, it does not open one between two existing rungs.

**DoD:** the world ends — a generated region that stops, or a barrier at 128 the player cannot walk
through — and VISION's "no infinite generation" pillar names the size that shipped; three
distinguishable biomes generate, each with its own surface and character; the v0 acceptance
assertions still pass against thresholds **re-derived** from the bounded area rather than re-tuned
until they go green again.

**Tests:** `test_worldgen.sh` asserts the sampled-column count the chosen bound implies, that
nothing generates beyond it, and each biome's surface node; the density thresholds and the area they
were derived from are recorded in the same commit that changes either.

### v1.2 — The mutation cycle

**Goal:** the world changes on a clock, by rule, and remembers that it did.

Two pieces, and confusing them is the failure this phase exists to avoid. **The frontier** is
`infected(pos, cycle) = dist(pos, focus) < r(cycle) + noise(pos)` — a pure function of position,
cycle and seed, answerable for any point in the world with no map loaded and no memory of where the
player has been. It decides *which* blocks the infection has reached. **The rules table**
(`rule → block transformation → condition`) decides what a reached block becomes, and the ABMs apply
it *inside* a boundary that has already been decided: contact spread survives as local drawing —
which block, which glyph, which crack — never as the thing that computes the boundary. Plus the
cycle counter in mod storage and the cycle log. Old blocks stay; mutated ones carry the H11 glyph.

Every rule is a pure function of `(state, cycle, seed)` — `hash(id, cycle, seed) < threshold` — and
never a per-tick dice roll. That is not a style preference. Evaluation is lazy, so the answer must
not depend on when the player walked past; a dice roll makes the cycle log a description of
something that never happened.

**Tasks:** the frontier function and its focus; the rules table; the ABMs that apply it inside the
frontier; susceptibility per material, so hull resists what crystal spreads; incubation — the glyph
appears a cycle before the material changes, which is the warning and the event card's content; the
cycle counter and the log, both in mod storage.

**DoD:** winding N cycles forward on a headless server applies the expected transformations and
writes a log that survives a restart; the result is **path-independent** — a region walked through
at every cycle and the same region first loaded at cycle N hold the same nodes; and few blocks
change per cycle, because one change reads as an event and forty read as noise.

**Tests:** `test_worldgen.sh` grows a cycle-advance mode: run N cycles, assert the transformations
and the persisted log; assert the path-independence pair on one seed; assert the per-cycle change
count against the restraint bound; and assert that `infected(pos, cycle)` evaluated with no map
loaded agrees with what a VoxelManip scan finds after the same region is emerged.

### v1.3 — The cycle HUD

**Goal:** the player can see the algorithm working.

The new mod `h11_hud`: the cycle number and clock, the H11 event card at a rollover, the separate
world-change card (before → after block pair plus a one-line note), and the bottom-left state line.

What each card may honestly say follows from v1.2's split. The cycle number and the frontier's
advance are **global** — the function answers for the whole world whether any of it is loaded or
not. The world-change card is **not**: it names a change the engine actually applied, which means a
change inside a loaded block. A card that claimed to report every change in the world would be
inventing most of them, and the player would have no way to catch it doing so.

**DoD:** a cycle rollover is legible at 640×480 on the device without covering the play area; the
world-change card reports only changes that were applied, and claims nothing about the unloaded
world.

**Tests:** `check_assets.py` for any new UI art; the device by eye.

### v1.4 — Catch-up, which is not catching up

**Goal:** the world keeps mutating while the device is off, and costs nothing to come back to.

There is nothing to replay. A block's state at cycle N is whatever the frontier and the rules say it
is at cycle N, so a block loading after a week is evaluated **once**, not two hundred times — and
this phase is the one that has to resist implementing the loop, because a loop is the obvious
reading of "catch up" and it produces a world that depends on when it was opened. The engine is
already shaped for the right version: `core.register_lbm` runs on blocks as they load, and the
engine tracks `lbm_introduction_times` per world in `env_meta.txt`, which is exactly the bookkeeping
a hand-rolled catch-up would have to invent.

**Tasks:** the LBM that evaluates a loading block against the current cycle; the missed-cycle span
folded into the frontier and the rules as a number rather than iterated; the returning player's
event derived from the cycle delta and the log, not from a replay.

**DoD:** a world whose cycle counter advanced 200 while it was closed holds exactly the nodes a
world open for all 200 holds, and reaches them in **one evaluation per block** — the cost of loading
it does not grow with the number of cycles missed, and no code path iterates them.

**Tests:** `test_worldgen.sh` asserts the two worlds are node-identical **and** that emerging the
long-absent one costs the same order of work as emerging the fresh one. The replay implementation
this phase forbids would pass the first assertion and fail the second, which is why both are needed.

---

## v2 — The inhabitants: three bots on rules

DRIFT, ECHO and MOSS: bodies on fast ticks, needs that decay, intents executed over hundreds of
ticks, and a Lua StubBrain that needs no network. They react to what H11 does to the world.
**Depends on:** v1.

This version also builds `h11_build`, the part catalogue (v2.5). Both of the seams a model answers —
`Perception → Intent` and a plan over the catalogue — are finished and exercised by Lua here, so v3
is a swap rather than a construction site.

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

### v2.5 — The build catalogue

**Goal:** something can be built from a plan, and unbuilt — the second seam, standing before there
is a model to plug into it.

`h11_build`, specified in [ARCHITECTURE.md](ARCHITECTURE.md) §The build catalogue: `catalogue.lua`,
the data table of parts and primitives; `ops.lua`, which expands a plan into nodes; `registry.lua`,
the mod-storage record of what has been placed; `undo.lua`, which captures each affected region
before it is written. It is the only module in the game that writes nodes in bulk. Here the plans
come from Lua — a fixture file, a chat command, and the StubBrain's `build` intent — because the
transport from a model is v3's problem and the receiving end is worth having proven before anything
unpredictable is wired to it.

Parts carry **sockets** (`{at, dir, type}`), which is what keeps coordinates out of a plan entirely:
`attach habitat_a to hub_core.socket[1]`, and Lua computes the stacking, rotation and offset that a
model would drift on. `place_schematic`'s `rotation` turns one file into four orientations and its
`replacements` re-materialises one shape in another block set, so ten authored parts are worth
thousands of stations and three are worth three.

**Tasks:** the catalogue table; the primitives (`box`, `dome`, `wall`, `stairs`, `lamps`); sockets
and the plan vocabulary; the first authored `.mts` parts — built by hand in-game, captured with
`core.create_schematic` into `mods/h11_build/schematics/`; the placed-part registry
(`{id, part, pos, rot, material, sockets_used, born_cycle, last_mutated_cycle}`) in mod storage;
undo; and the validation caps, all three of which run **before any write**: every node name exists
in `core.registered_nodes`, the bounding volume lies inside the world, and the node count is
computed and capped.

**DoD:** a plan of a few dozen lines places a multi-part structure and contains no coordinate; the
registry can describe what stands ("one hub, three habitats, two free sockets"), which is what
v1.3's change card and v3's prompts both read; undo restores the affected region node for node; and
an invalid plan — an unknown node name, a volume off the edge of the world, ten million nodes — is
rejected with **not one node written**. That last one is not hypothetical: a model wrong by an order
of magnitude asks for ten million blocks, and the engine will honestly try.

**Tests:** `test_worldgen.sh` grows a plan mode — expand a fixture plan headlessly, assert the node
counts and the registry rows, undo it and assert the region matches the pre-write scan exactly; and
assert each of the three rejection cases leaves the world unmodified. `check_assets.py` covers any
textures the parts introduce.

---

## v3 — The brain: a model on the local network

The `brain/` service on a LAN machine with a local model, an HTTP bridge from the mod, and a
fallback to the StubBrain whenever the server is absent. It is a Python service in its own top-level
directory, not a Luanti mod — the mods only ever talk to it over HTTP. The bots gain judgement and
character prompts. **Depends on:** v2.

### v3.1 — The service

**Goal:** `POST /decide` answers with an `Intent` — and the second seam gets a transport.

This is the phase that defines what a model may say to this game, so it is the phase that owes an
answer for plans as well as intents. `h11_build` has existed since v2.5 and a plan is the second
thing a model emits, but the only defined channel returns an `Intent`. Leaving it to v3.3 is how the
`Intent` schema grows a plan-shaped field by accident — and that schema is answered by the Lua
StubBrain with no network at all, so the moment a plan can only arrive inside an intent, the
fallback stops being a fallback.

**Tasks:** the service, the `POST /decide` endpoint, the per-bot payload — **and the plan transport,
chosen here.** Two shapes are on the table: a `build` intent that carries a plan *reference* the mod
then fetches, or a second endpoint with its own wake condition and its own call budget. The
constraint on both is the same, and it is not negotiable: the `Intent` schema may not quietly grow.

**DoD:** the service takes a perception payload plus a bot id and returns a valid intent in 1–3
seconds for three bots; the plan transport is decided and recorded in `docs/decisions.md` — like any
change to a protected seam — with its wake condition and its call budget named, and the `Intent`
schema is provably unchanged by it (the v2 StubBrain still answers the contract unmodified).

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

**One thing here is already constrained, and it is the anchor.** The anchor is promised as a
boundary the infection cannot cross, and the infection's boundary is computed by v1.2's frontier
function — not by contact, and not by the ABMs an anchor would most naturally veto. An anchor built
as a live suppression check therefore stops nothing behind the player's back: a block loading behind
it computes `infected = true` from a function that never heard of the anchor, and the quarantine
comes out holey exactly where nobody was watching. Which is the failure the frontier exists to
prevent, reintroduced from the other side.

So the anchor is designed as **frontier data**, not as a veto. Placements and removals are appended
to a persistent ordered log, that log is an input to the function —
`infected(pos, cycle, seed, anchors)` — and the wall therefore stands while the device is off. It
stays pure, because the log is an input rather than a side effect, and it stays a wall rather than
an undo, because the shield is evaluated per cycle: an anchor planted at cycle 12 does not un-infect
what cycle 5 took. See [ARCHITECTURE.md](ARCHITECTURE.md) §The anchor is an input to the frontier
and the `docs/decisions.md` entry that dates it.
