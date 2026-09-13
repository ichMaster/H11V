# Decisions

Closed decisions and the measurements that justify them. Not a changelog: a decision goes here so a
later phase does not silently reopen it, and so a number can be read back against the conditions it
was taken under.

**Format.** Newest last. Each entry: a date, what was decided, and *why* — the why is the part that
stops the decision being re-litigated from memory. A decision that is later reversed is not deleted;
a new entry supersedes it and says so.

**One rule this file enforces.** The `Perception → Intent` contract
([ARCHITECTURE.md](../specification/ARCHITECTURE.md)) may not change without an entry here. From v2
that is the seam the whole bot design rests on.

---

## Before v0 — decisions taken during specification

### 2026-09-12 — The engine is Luanti

Luanti (formerly Minetest), not Godot 4 + godot_voxel, not Unity, not Unreal.

**Why:** an open-source C++ voxel engine with chunks, lighting, generation, saving, inventory and
touch controls already working on a Pi, packaged in Debian, and extended purely in Lua. Godot would
have cost a custom arm64 module build plus our own chunking, lighting and saving. Unity has no Linux
arm64 without an Industry licence; Unreal on a Pi needs a patched engine build with no guarantees.
The project writes content, not an engine.

### 2026-09-12 — Three bots, rules first, model later

Three bots rather than one, living on Lua rules in v2, with a language model added in v3 behind an
unchanged contract.

**Why:** three is the smallest number that makes per-bot differences visible after a mutation. Rules
first keeps the body's tick free of the network from the start, so the v3 swap changes nothing in the
body.

### 2026-09-13 — Bright-luminous art canon, 32×32, designed pack only

The art direction is bright and luminous, not a dark palette. Textures are 32×32. All assets come
from the designed pack in `specification/art/h11v/`; there is no procedural texture generation.

**Why:** the three reference images in `specification/art/` are the canon and they are luminous; the
"dark H11 palette" in the early drafts contradicted the art that had already been made. 32×32 over
16×16 for legibility on a 3.5-inch panel — to be confirmed by eye in v0.7. Bots are canon from the
same art: DRIFT (BOT 01, cyan, curiosity), ECHO (BOT 02, amber, balanced), MOSS (BOT 03, green,
safety/energy), sharing the needs triad energy / curiosity / safety.

### 2026-09-13 — H11V is standalone

No code, prompts or assets are carried in from any other repository. The SDLC kit in
`.claude/skills/` and `codegen/` is shared machinery; the game is not.

---

## v0.1 — Toolchain and skeleton

### 2026-09-13 — Luanti versions: Mac 5.17.0, device 5.10.0

| | version | source |
|---|---|---|
| MacBook M1 (development) | **Luanti 5.17.0 (OSX)**, LuaJIT 2.1.1764270282 | Homebrew cask → `/Applications/luanti.app` |
| PocketTerm35 (the target) | **Luanti 5.10.0 (Linux)**, LuaJIT 2.1.1737090214 | Debian trixie `luanti` + `luanti-server` |

The device's package was chosen over a Flatpak or AppImage even though it lags the Mac by seven minor
versions.

**Why:** a sandboxed runtime would introduce its own Wayland, Mesa and GPU plumbing into the exact
measurement v0 exists to take. The distro package uses the system Mesa the device actually ships. The
cost is a constraint, recorded here so it is not discovered later: **the mod API surface must stay
within what 5.10 supports**, because the device is where the game has to run.

### 2026-09-13 — The v0.7 profile ladder keeps its shaders axis, because the device is 5.10

Basic shaders became mandatory in Luanti 5.11 and `enable_shaders` was removed — so on the Mac
(5.17.0) a shaders on/off comparison is impossible. On the device (5.10.0) it is still available.

**Why it is recorded:** `ARCHITECTURE.md` §Acceptance had flagged that the ladder could only use the
shaders axis "if the whole protocol is pinned to the Debian 5.10 package". That is what the device
ships, so the v0.7 ladder may use it — and the numbers count on the device only, which is where the
axis exists. The Mac cannot reproduce that particular comparison, and should not be asked to.

### 2026-09-13 — There is no `luantiserver` on macOS; the invocation is resolved, not assumed

Debian ships a separate `luantiserver` binary (`/usr/games/luantiserver`). The macOS cask ships one
binary inside an `.app` bundle, not on `PATH` at all, whose dedicated-server mode is the `--server`
flag. `tools/luanti_path.sh` resolves both and exposes a `luanti_server()` **function**.

**Why a function and not a variable:** `"$LUANTI --server"` is two words, and zsh does not word-split
an unquoted parameter the way bash does — callers got a single nonsensical filename. A function
behaves identically in both shells. `ARCHITECTURE.md`, `SDLC.md` and `CLAUDE.md` were corrected; all
three had claimed the Debian name unconditionally.

### 2026-09-13 — GPU preflight: PASS, V3D 7.1.7.0

```
LIBGL_ALWAYS_SOFTWARE=[unset]
OpenGL ES profile renderer: V3D 7.1.7.0
```

The device renders on the Pi 5's V3D hardware driver, not on Mesa's `llvmpipe` software rasterizer.
Probed with `eglinfo`, not `glxinfo`: Luanti renders through EGL on Wayland, and `glxinfo` reports
nothing over a session with no X display. `tools/gpu_preflight.sh` makes the check repeatable.

**Why it gates everything:** an llvmpipe fallback draws the world correctly and makes every
frame-rate number fiction. **Any measurement taken without this line green is void.** This string is
recorded again in v0.7 beside the numbers it justifies.

### 2026-09-13 — The packaged `luanti-server.service` is disabled

Installing `luanti-server` enabled a systemd unit that starts a dedicated server at boot.

**Why:** it would have run a server across all four of the device's cores in the background, quietly
taxing every frame-rate figure in v0.7. Disabled and stopped. If a future version wants a persistent
world on the device, it re-enables this deliberately and re-measures.

### 2026-09-13 — The aarch64 touch regression does not apply

The known Luanti touch regression on aarch64 was in 5.8. The device runs 5.10.0, so it is not
affected. Touch behaviour still has to be confirmed on the panel in v0.5/v0.7 — this entry only
closes the *known* risk, not touch in general.

### 2026-09-13 — On the Mac the game is symlinked into the legacy `minetest` user directory

`~/Library/Application Support/minetest/games/h11v` → the repo's `games/h11v`.

**Why it is worth recording:** Luanti 5.17 still uses the pre-rename `minetest` directory name on
macOS, which is surprising enough to cost an hour if rediscovered. `tools/run_local.sh` automates the
link in v0.6.

### 2026-09-13 — The v3 brain host is `ich-picobox`, and it has no discrete GPU

The brain service will run on the LAN box `ich-picobox` (Ubuntu 22.04.5, 4 cores, 15 GB RAM, Intel
integrated graphics, **no NVIDIA GPU**, ollama not yet installed). Connection details live in the
gitignored `.brain-connect.txt`.

**Why not the Mac:** its firewall accepts an inbound LAN connection and tears the socket down before
the first read, so the device cannot reach a service hosted there. This is the same constraint the
roboface project documents for the same reason.

**Consequence:** v3 inference is CPU-bound on four cores. "An answer in 1–3 seconds for three bots"
points at a small quantized model, and it is one more reason the body never waits on a reply.
Narrows — but does not close — open question 2 in [VISION.md](../specification/VISION.md).

---

## v0.3 — Water and trees

### 2026-09-13 — Mapgen settings are overrides, not defaults (correcting v0.2)

`core.set_mapgen_setting(..., false)` and `set_mapgen_setting_noiseparams(..., false)` do **not** mean
"set unless this world already has a value". The engine writes its own defaults into `map_meta.txt`
when the world is created, and that happens **before mods load** — so `false` means *never*, for a
brand-new world as much as an old one.

**Why it matters:** v0.2 registered its terrain tuning with `false` and reported an elevation range of
19 as evidence the tuning worked. It did not: that number came from stock v7 noise. The settings were
inert. All five are now `true`.

**What it costs, accepted:** an existing map re-tuned on next load grows a seam where old and new
chunks meet. In v0 no world outlives a test run, and v0.7 measures a fixed seed on a fresh world.
A setting that applies is worth more than one that cannot. This supersedes the reasoning recorded in
the v0.2 execution report.

### 2026-09-13 — v7's height is a blend, so the blend is pinned

v7 does not take terrain height from one noise:

```
if alt > base then height = alt
else height = base * height_select + alt * (1 - height_select)
```

Tuning `terrain_base` alone therefore moves almost nothing — the short-circuit and the blend swamp
it. This is the second reason v0.2's numbers refused to budge.

**Decision:** `mgv7_np_height_select` is pinned to a constant 1 and `mgv7_np_terrain_alt` is kept in a
narrow band that cannot exceed base, leaving **`mgv7_np_terrain_base` as the single dial** for
terrain shape.

**Why:** a 128×128 pocket world needs one number a designer can turn, not three interacting ones
tuned for an endless continent. With water level 6, offset 12 and scale 12 give elevation range 19,
turf on 93% of sampled columns and water on 7% — lakes and a shoreline rather than a lawn or a swamp.
