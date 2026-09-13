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

### 2026-09-13 — The world is still unbounded, and "exactly 128×128" is not available

VISION asks for "a single map on the order of 128×128 blocks, no infinite generation". The engine
setting for that is `mapgen_limit`, a radius in nodes — but **only mapchunks lying completely within
the limit are generated, and a mapchunk is 80 nodes.** So `mapgen_limit = 64` generates a single
central mapchunk: an **80×80** world, not 128×128. Measured, not reasoned: the worldgen probe's
sampled columns fell from 1024 to 400, exactly the 0.625 span ratio that implies, and the tree count
fell below the DoD's threshold with it.

The available sizes are therefore quantised to mapchunks — 80×80, 240×240, and so on — and 128×128 is
not among them.

**Decision: leave the world unbounded through v0.** A boundary is not in any v0 phase's DoD; v0 exists
to measure the device. Introducing one now would mean either shipping an 80×80 world that contradicts
the specification, or a 240×240 one that contradicts it in the other direction, and silently
rewriting a released phase's acceptance numbers to match whichever was chosen.

**Owed to v1**, where the world's size is a genuine design question rather than a setting: pick
80×80 or 240×240 (or a soft barrier at 128 inside a larger generated region), update VISION to the
number actually chosen, and re-derive the gate's density thresholds from it.

---

## v0.6 — Device profiles and scripts

### 2026-09-13 — The device renders through GLX on XWayland, not EGL on Wayland

Debian trixie's `luanti` 5.10 is the **legacy Irrlicht X11 build**: linked against `libX11`, with no
SDL, no EGL and no GLESv2. The binary contains the strings `ogles2` and `opengl3`, so both look like
valid `video_driver` values — and the engine rejects both at runtime with `Invalid video_driver`,
then falls through to an X11 device and dies with `Need running XServer`.

**Decision:** `video_driver = opengl`, and `DISPLAY=:0` set explicitly by `tools/run_on_pi.sh` (over
ssh there is none). The render path is GLX → XWayland → Mesa V3D.

**It is still hardware**, which is the part that matters:

```
DISPLAY=:0 glxinfo -B
  direct rendering: Yes
  OpenGL renderer string: V3D 7.1.7.0
  OpenGL version string: 3.1 Mesa 25.0.7-2+rpt4
```

**Consequence for the preflight, and the reason this entry exists:** `tools/gpu_preflight.sh`
originally probed **EGL**, which reported `V3D 7.1.7.0` — correctly, and about a path the game never
takes. A check that verifies the wrong path is not a weaker check, it is a false one. It now probes
GLX first and keeps EGL as a secondary reading. ARCHITECTURE.md §The GPU path is corrected to match.

### 2026-09-13 — `--gameid list` writes to stderr on 5.10 and stdout on 5.17

The game-visibility guard added by v0.1's code review read only stdout, so on the device it saw
nothing and **blocked a deploy that would have worked**.

**Why it is recorded rather than just fixed:** the guard was added *because* a silent failure had cost
a debugging session, and it promptly caused one of its own in the opposite direction. A guard that
produces false positives is worse than no guard, because it is believed. Both `run_on_pi.sh` and
`run_local.sh` now capture both streams.

---

## v0.7 — The measurement session

### 2026-09-13 — The device has ample headroom at 30 fps, and cannot hold 60

Measured on the PocketTerm35, fixed seed 20260913, each profile deployed fresh, the debug overlay
read from a screenshot after a 25-second walk. Renderer **V3D 7.1.7.0**, preflight green — without
that line none of the below would count.

| profile | `viewing_range` set | achieved | fps (cap) | **drawtime** |
|---|---|---|---|---|
| low | 40 | 40 | 29 (30) | **2 ms** |
| mid | 60 | 60 | 29 (30) | **3 ms** |
| high | 100 | **60** | 29 (60) | 3 ms |

**Low and mid hold their 30 fps cap with room to spare.** A drawtime of 2–3 ms against a 33 ms budget
means the GPU is doing almost nothing: the V3D is not the constraint at these settings, and there is
a great deal of headroom for what v1 and v2 will add.

**High does not reach 60 fps**, and the engine responds by cutting the view range from the configured
100 down to 60 on its own — and still lands at 29. So 60 fps is not available at this range on this
device, and asking for it costs view distance rather than buying frames.

**Therefore: `mid` is the default profile.** It is the most the device delivers without the engine
overriding the setting, and it holds its cap.

### 2026-09-13 — Raising `fps_max` destroys the measurement it is meant to enable

Luanti steers `viewing_range` toward `fps_max`: it reduces the range when the target is not being
met. So the obvious way to find out "what can this device really do" — lift the cap and look — does
the opposite. With `fps_max = 250`, both low and mid reported **`view range: 40`** and ~74 fps,
because the engine had quietly cut mid's configured 60 to chase a target it could never reach.

**Decision:** each profile is measured at its own shipping cap, and **`drawtime` is the number that
carries the information** — the real per-frame render cost, which neither the cap nor the
range-steering touches. `tools/deploy_to_term35.sh --uncapped` still exists for deliberate
experiments, and `tools/measure_device.sh` no longer uses it.

### 2026-09-13 — What the screenshots do not settle

`tools/measure_device.sh` gets the conditions identical and captures the evidence; it does not read a
frame rate off its own screenshot and write it down. Deliberately: a script confidently OCR-ing the
one measurement this milestone exists to take is a very efficient way to be wrong.

Still owed by a person at the device, and the reason v0.7 is not yet closed:

- legibility of the 32×32 textures at 3.5 inches, and whether 32×32 was the right call over 16×16
- graininess and shimmer on distant blocks while moving
- how the bright-luminous palette holds up at night
- whether the H11 glyph reads on the crust block at normal viewing distance
- whether touch digging and placing actually feel right, which no capture can show

### 2026-09-13 — 32x32 stands. The 16x16 trial was run on the device and reverted

Node textures ship at the authored **32x32**. The entry below proposed 16x16, it was built,
installed, looked at on the panel and rolled back the same day on Vitalii's call. `check_assets.py`
detects the installed resolution, so nothing else moved in either direction.

**Why it is worth keeping the trial on record rather than deleting it:** it cost one command each
way precisely because the delivery of record was never modified, and it retired two plausible
arguments permanently — the "2-pixel clusters" claim (measured: 44%) and the "less shimmer" claim
(measured: no difference). Both are the kind of thing that gets re-proposed from intuition every few
months.

This also answers the first of v0.7's open questions: **32x32 reads correctly at 3.5 inches**,
confirmed by looking at both.

### 2026-09-13 — The engine's dialogs needed two different fixes, not one

Reported from the device: in Change Keys every label ran together. That turned up a second, worse
instance — the pause menu's controls-help column ran off the right edge with no way to reach it.

They look alike and are not the same bug:

- **`font_size` 20 → 14** fixes text overflowing its own cell, which is what makes labels merge.
- **`gui_scaling` 1.4 → 1.0** fixes a dialog *wider than the screen*. The engine's menus are laid out
  for a desktop; scaling them up on a 640x480 panel pushes their right-hand columns past the edge,
  and no font size touches that.

`hud_scaling` stays at 1.4. The HUD and the GUI scale separately and want opposite things here: the
hotbar is a touch target and must stay finger-sized, while the dialogs have to fit the panel.

Confirmed readable on the device after both changes.

### 2026-09-13 — Tree density is a setting, because the forest hid the world

`h11v_tree_density`, default `0.032`, overridden by `tools/deploy_to_term35.sh --trees=N` (which
implies `--fresh`, since decorations are placed at generation).

**Why:** judging the shape of the world — how far it runs, how tall the hills are, whether 128x128
feels like a place — is impossible from inside a forest. The alternative was editing the shipped
value and remembering to revert it, which is the kind of thing that does not get remembered. The gate
still measures the default: `trees=30` against a threshold of 20.

### 2026-09-13 — Node textures ship at 16x16, superseding the 32x32 decision — **REVERTED, see above**

Supersedes "Bright-luminous art canon, 32x32, designed pack only" (13 September) on the resolution
only. The palette, the designed-pack-only rule and the bot canon are unchanged.

Node textures are halved 2:1 from the authored 32x32, nearest-neighbour, by
`tools/downscale_pack.py`. UI art and the hand are not scaled — they are sized in screen pixels or
extruded into a mesh.

**Two arguments were offered for this and both are false.** They are recorded because they are the
arguments anyone would reach for again:

- *"The pack is drawn in 2-pixel clusters, so halving loses nothing."* Measured: only **44%** of its
  2x2 blocks are uniform. Over half the detail is real, and halving discards it.
- *"16x16 shimmers less at distance."* Measured at both near and far block sizes: **no difference**,
  inside the noise. Nearest-neighbour halving smooths nothing — it moves the same hard edges onto a
  smaller grid, and sampling six screen pixels out of sixteen texels crawls exactly as much as six
  out of thirty-two.

Performance is not a factor either: 2-3 ms of a 33 ms budget at both sizes.

**So the real reason is aesthetic**, and it is the only one that should be cited: 16x16 is the
resolution the voxel idiom is written in, and whether 32x32's extra detail reads as texture or as
noise on a 3.5-inch panel is a question the panel answers.

**This is explicitly reversible and is not yet closed.** `tools/install_assets.sh --res=32` puts the
authored resolution back in one command: the delivery of record in `specification/art/h11v/` is never
modified, and `tools/check_assets.py` detects the installed resolution instead of being told it, so
nothing else has to change in either direction. The 32x32 decision stands as the fallback until this
one is confirmed on the panel.

**What confirms it:** the same judgement v0.7 has been waiting on — whether 16x16 reads better than
32x32 at 3.5 inches. That question was the reason both sizes were ever in play, and it is answered by
looking at the device, not by reasoning about it here.

### 2026-09-13 — Touch: tap places, long press digs — and it is not discoverable

The engine's own help, which is the authority here:

```
- slide finger: look around
- tap:          place/punch/use
- long tap:     dig/use
```

With `touch_use_crosshair = true` the **crosshair** picks the target, not the point of contact: a tap
anywhere acts on whatever is being aimed at, and a tap while aiming at sky does nothing.

**This is recorded as a finding, not just as documentation.** The control had to be asked for by the
person who commissioned the game, on his own device — which is as clear a signal as this kind of
thing gives. "Tap places, hold digs" also inverts the expectation most people arrive with. Nothing
in v0 is going to fix it (v0 has no UI beyond a hotbar and a crosshair), but v4's player-facing work
should not assume the scheme explains itself.

`touch_interaction_style` was set in the device config and **does not exist in 5.10** — verified
against the binary's own setting list. Removed rather than kept as forward-compatibility for 5.12: a
setting that does nothing reads as a setting that does something, and the next person debugging touch
would start with the one line that cannot possibly be the cause.

### 2026-09-13 — v0.7 answered: the five judgements, from the panel

Answered by Vitalii on the device, which is the only place any of them could be.

| question | answer |
|---|---|
| Do 32x32 textures read at 3.5"? | **Yes** — confirmed by building 16x16, looking at both, and reverting |
| Shimmer on distant blocks? | No difference between the resolutions (measured, not judged) |
| Does the bright palette hold at night? | **Yes** — deep navy sky with stars, turf still readably green, not a grey wash |
| Does the H11 glyph read as a symbol? | **Yes**, once it is the right block — and it now glows |
| Does touch digging and placing work? | **Yes** |

**Three defects surfaced only because someone held the device**, and none of them would have been
found by any gate:

1. **No privileges.** The game granted none, so the player had the engine's bare `interact, shout`.
   `/time` refused, and the touch menu's own Fly / Fast / Noclip buttons were dead. The game looked
   finished while three of its controls did nothing.
2. **Night was unplayable.** "I can't see anything" — and 5.10 has no lever for it: no
   `light_curve_*` family in this build, and `display_gamma` measurably does nothing (night captured
   at 1.0 and 2.5 renders identically). In this engine light comes from blocks, so the fix is a
   block. See the next entry.
3. **The engine's own dialogs did not fit the panel**, in two different ways needing two different
   fixes — see the `font_size` / `gui_scaling` entry.

### 2026-09-13 — The H11 crust is the light, and that is the fiction rather than a workaround

`light_source` 3 → **12** of a possible 14.

**Why a block and not a setting:** 5.10 offers no brightness control that works (above). Light in
this engine comes from nodes.

**Why the crust and not a torch:** a torch would be a new object with no art in the delivered pack
and no place in the fiction. [ART.md](../specification/ART.md) already says H11 leaves "a faint
cyan-to-lilac glow" on everything it has touched — a glowing crust *is* the art direction, not an
accommodation to it. The player starts with 16.

**A consequence worth having:** from v1, the mutation front will literally light the world as it
spreads. 12 rather than 14 keeps a mutated region reading as *glowing* rather than merely lit.

### 2026-09-13 — `/time` takes ticks, not clock digits

`[<0..23>:<0..59> | <0..24000>]`. So `/time 1400` is 01:24 in the morning, not two in the afternoon —
which cost a confused minute on the device. `/time 14:00` is the form to use and the one to put in
the player guide.
