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

---

## v0.7.1 — Device fixes

### 2026-09-13 — The gamepad buttons are keyboard keys, and the mapping came from H11

Established on this hardware, not assumed: **every button sends an ordinary keyboard key.** There is
no `BTN_*` anywhere, `/proc/bus/input/devices` lists no joystick, and the twelve gamepad codes the
keyboard advertises in its capability bitmap are never used. So this is a keymap, and Luanti needs no
joypad path at all.

The codes were captured on this device by the sibling project H11 (its `ARCHITECTURE.md`) and
confirmed here against the input device list:

```
A 30 · B 48 · X 45 · Y 21 · L 38 · R 19    each sends the letter on its own face
Select 99 = SysRq (KEY_PRINT, not KEY_SNAPSHOT — see v0.7.2)   Start 119 = Pause (KEY_PAUSE)
D-pad 103/108/105/106 = the arrow keys
```

**Luanti binds one key per action — there is no secondary binding** — so these *replace* the desktop
keys rather than joining them. Hence `tools/device/gamepad.conf`, appended only by the device deploy
and never by `run_local.sh`: on the panel the D-pad moves you, on the Mac W/A/S/D does. The same
two-profile split H11 arrived at for the same reason.

| | |
|---|---|
| D-pad | move |
| A / B | jump / sneak |
| X / Y | place / dig |
| L / R | hotbar previous / next |
| Select / Start | inventory / chat |

A is jump without a collision precisely because A and D were *left* and *right* by default, and the
D-pad has taken those. Escape is the pause menu and is not rebindable, so Start went to chat — which
on this device is the only reason to want a keyboard mid-game (`/time`, `/music`).

`keymap_rangeselect` was unbound from R in the base config: R is the right shoulder and belongs to
`hotbar_next`. A silent binding conflict is worse than the harmless warning the engine logs about
rangeselect having no key.

### 2026-09-13 — A deploy must wait for the engine to exit, not just signal it

**Luanti writes its settings back to the config file as it shuts down.** A deploy that swaps the file
while the old process is still dying gets its new config overwritten by the old one's memory —
silently, and with the comments preserved, so it looks like it worked.

Diagnosed the hard way: a whole keymap block arrived on the device as comments with every setting
stripped out, plus a `sound_volume = 1` nobody wrote. The deploy now waits for the process to be gone
before swapping, with a SIGKILL escalation. `--stop` had already learned this lesson; the deploy path
had not.

### 2026-09-13 — The on-screen jump/sneak buttons: hidden, because 5.10 cannot move them

They are drawn across hotbar slots 5-8. Three approaches were tried on the device:

| approach | result |
|---|---|
| `texture_path` texture pack | does not override these textures at all |
| replacing them in `/usr/share/luanti/textures/base/pack/` | **works** — they are gone |
| `hud_scaling` 1.4 → 0.8 | no effect on button size or position |

So they are blanked in place, with the originals kept beside them as `.orig`. **The touch zone
remains** — 5.10 has no way to remove or move a button, only to stop drawing it — so slots 5-8 are
selected with the keyboard, or now with the L/R shoulder buttons, which is the better answer anyway.

Moving and resizing them needs the touchscreen layout editor added in **5.11**. Debian trixie carries
only 5.10 with no backports; Flathub has an aarch64 build. **Decision: stay on the Debian package.**
The engine is the one dependency this project does not want to be clever about.

### 2026-09-13 — Turning on L/R, and why it costs a flash

**Luanti has no key binding for the camera.** `keymap_*` covers movement, strafing, digging and
menus; looking belongs to the mouse and the touchscreen. On a device with neither a mouse nor a
comfortable way to drag-and-tap at once, that makes turning the single most awkward thing in the
game. So it is done in `turn.lua`, reading controls and calling `set_look_horizontal`.

**The buttons have to arrive as something a mod can see.** `get_player_control()` reports a fixed
set — movement, jump, sneak, dig, place, aux1, zoom — so L and R are bound to `zoom` and `aux1`
purely because those two were unclaimed. The binding is a transport, not a meaning.

**A transport must be inert, and neither of these was:**

| | effect | how it was neutralised |
|---|---|---|
| R → `aux1` | sprinted while turning | the `fast` privilege is **revoked**, not merely ungranted — privileges live in the world's auth database, so one granted by an earlier version of this file survives forever unless something removes it |
| L → `zoom` | zooms the camera | `zoom_fov = fov` did **not** work; `turn.lua` pins the FOV with `set_fov` while the button is held |

**The flash that remains is structural.** The client predicts the zoom the instant the key goes down;
the server undoes it on its next step. **The step length is the flash length** — 90 ms at Luanti's
default `dedicated_server_step`, which is exactly what "a flash of milliseconds" was. It is now
`0.02`, so both the correction and the turn itself run at 50 Hz rather than 11: the flash is much
shorter and the turn stopped stepping. The device has the headroom — 2-3 ms of drawtime against 33,
four cores, no entities and no ABMs.

It cannot be removed. `zoom` is **not a registered privilege** in 5.10 (checked against the engine's
own `privileges.lua`: interact, shout, basic_privs, privs, teleport, bring, settime, server,
protection_bypass, ban, kick, give, password, fly, fast, noclip, rollback, debug — no zoom), so there
is nothing to revoke, and Luanti has no client-side API that would let a mod suppress the prediction.
**Accepted as-is on Vitalii's call.**

The escape hatch, if it ever stops being acceptable: drop turning from L and keep it only on R, whose
`aux1` transport is genuinely inert and flashes not at all.

## v0.7.2 — Turning, and the hotbar on Select

### 2026-09-13 — Select cycles the hotbar: two wrong answers before the key even reached the game

Select's final job is `hotbar_next`, cycling slots 1→8→1. L/R gave up hotbar duty when they took over
turning, and Start stays on chat. Getting one button to do one thing took three separate corrections,
and only the last of them was in this repository at all.

**1. `hotbar_previous` had to be actively emptied.** Luanti's default for it is `KEY_KEY_B` — the same
B that is sneak here. Dropping the binding is not the same as unbinding it: the default reappears. So
`tools/device/gamepad.conf` carries `keymap_hotbar_previous =` with nothing after the `=`. Cycling in
one direction only is also the better behaviour on a single button: eight slots, one key, wraps round.
Verified on the device — the eighth press returns to the starting slot, the ninth moves on.

**2. The engine's name for the key is `KEY_PRINT`, not `KEY_SNAPSHOT`.** The physical Select sends
evdev code **99 = `KEY_SYSRQ`**, which xkb maps to the keysym `Print`; Irrlicht calls that `KEY_PRINT`.
`KEY_SNAPSHOT` is accepted by the config parser without complaint and simply never fires. Measured
three ways on the device, restarting between each, by counting changed pixels in the hotbar strip:

```
KEY_SNAPSHOT + injected Print  ->  no change
KEY_PRINT    + injected Print  ->  the hotbar advances
```

**3. Sway was eating the key, and editing its config did nothing.** `bindsym Print exec grim` sat at
line 119 of `~/.config/sway/config` and took the key before any client saw it. The evidence was
sitting in `$HOME`: **106 stray screenshots**, one per press, accumulating while the button "did
nothing". Moved to `$mod+Print`, with a backup at `~/.config/sway/config.bak-h11v`.

The part worth remembering is what came next. After the edit the button still failed, because **Sway
does not reload its configuration when the file changes** — and `swaymsg -t get_config` returns the
config *as loaded*, not the file on disk, so the two disagreed while looking like the same thing. The
old `bindsym Print` was still live and still counting up screenshots. `swaymsg reload` is the step, and
`get_config` is the way to confirm it actually happened.

**A compositor binding is invisible from inside the game.** Nothing reaches the engine, so nothing
appears in `debug.txt`, and the natural conclusion — the wrong key name — was wrong twice over. When a
key does nothing on this device, ask the compositor what it has claimed before touching the game's
keymap. The current claims: `$mod`-prefixed bindings, and `$mod+Print`.

## Art direction

### 2026-09-13 — The world stops being a meadow: colonising another planet

Vitalii's judgement after playing the device build: *"зараз мод дуже схожий на стандартний мод
майнкрафту навіть з нашими кастомізаціями"* — and he is right. The v0 pack is well drawn, tiles
cleanly and reads at 3.5 inches; none of that was the problem.

**The problem is the vocabulary, not the palette.** Grass, soil, bark, leaves, sand, cobble and water
are not generic voxel materials — they are Minecraft's own material set, and a player recognises the
game by them before noticing a single hex value. Every fix available inside that set is a recolour,
and a recolour of Minecraft is Minecraft. So the set itself changes.

The new direction is a **planetary colony**, fixed by two reference images in
`specification/art/space/` and written up as [ART-COLONY.md](../specification/ART-COLONY.md):

| v0 | now |
|---|---|
| turf / dirt / stone / sand | regolith / fines / lithic / drift — bone-pale mineral, violet-grey, no green |
| trunk / leaves | spire / bloom — a faceted crystal stalk and a hanging filament crown |
| water | meltwater — luminous cyan, lit from within |
| — | **hull, prefab, crate, beacon** — the colony's own hardware, what the player builds with |

**The colony blocks are the load-bearing half of the change.** The planet set alone would still be a
terrain recolour; four machined, human-made blocks in the hotbar are what makes the world read as a
landing site rather than a biome. The brief states it as one rule: every block belongs to either the
**grown** language (facets, needles, filaments, internal light) or the **built** one (plates, seams,
rivets, stencils), and the two must be distinguishable at 8 pixels.

**Two things deliberately survive the change**, because they were never the problem: the **UI voice**
(dark glass, thin light borders, cyan monospace, the event and world-change cards) and the **H11 glyph
language**. `ART.md` stays authoritative for both, and for the v0 pack that currently ships.

**The cost is a rename, and it is not free.** Node ids move with the fiction
(`h11_world:turf` → `regolith`, and so on), which touches `nodes.lua`, `mapgen.lua`, `player.lua` and
the pinned filename tables in `tools/check_assets.py`. Worlds generated before it will not survive —
accepted: v0's world is a test fixture, not a save. §10 of the brief carries the list so the delivery
does not arrive looking cheaper than it is.

### 2026-09-13 — The bone planet nearly read as porridge, and the fix is a rule, not a palette

Writing the colony brief produced a palette worth measuring before anyone drew from it. Measured in
CIE L\*a\*b\*, **four of its six opaque materials sat within ΔL\* 4 of each other**: regolith and drift
differed by 1.4 at an *identical* hue, lithic and the ship's hull by 1.6. On a 3.5-inch panel that is
one grey planet with a grey shipwreck on it.

**Why this world is prone to it.** The fiction asks for bone regolith, bone bedrock, pale drift and a
white hull — four ways of saying "pale mineral". The reference images carry it because ray-traced
shadows and ambient occlusion separate the forms. **The device has no shadows in any profile**, and
that is a frame-rate decision, so the separation has to live in the textures themselves.

**And the scale is brutal.** At view range 40–100 most blocks on screen are 5–20 px tall, where a
texture collapses to roughly its mean colour. Clusters, rivets and glyphs are all gone. Two materials
are told apart by their means and by nothing else.

So [ART-COLONY.md](../specification/ART-COLONY.md) §4.1 states six binding rules — an 8-point L\*
ladder, a 60° hue spread for anything closer than that, four named structural collisions
(lithic↔meltwater, regolith↔meltwater, hull↔crate, fines↔bloom), spatial frequency as a third axis,
top-vs-side, and a check at 30% brightness — plus a verification method: downscale each tile to one
pixel and compare every pair.

**The hex values are deliberately not binding.** Vitalii's call: give Claude Design the constraints and
let it choose the colour. A worked palette that passes the rules is included only as proof they are
satisfiable, and it is explicitly a floor to beat rather than a proposal. The rules are checkable; a
hex table is just someone's taste with authority it has not earned.

Worth turning into a gate later: `tools/check_assets.py` already decodes PNGs with the stdlib, so
measuring each delivered node texture's mean and failing on a too-tight pair is a small addition. Not
built yet — the textures do not exist and the filenames change with them.

## Design direction — the catalogue, and mutation as infection

### 2026-09-13 — What H11 acts on: parts, not anonymous blocks

Worked out with Vitalii across one conversation, before any of it is built. Recorded here because it
settles several things the roadmap had left vague, and one thing `CLAUDE.md` had listed as open.

**The build interface is a catalogue of parts, not freeform block placement.** A model cannot
reliably emit fifty thousand coordinates — it loses count and drifts. So it emits a compact plan in a
small vocabulary, and deterministic Lua expands it. Two levels, both needed: **primitives** (box,
dome, wall, lamps) for terrain and filler, and **parts** — authored `.mts` schematics — for anything
that has to look good.

Parts carry **sockets**: `{at, dir, type}`. With them a plan contains no coordinates at all —
`attach habitat_a to hub_core.socket[1]` — which removes the model's weakest skill (arithmetic) from
the critical path and leaves it doing what it is good at, composition. Two engine features do more
work here than they look: `place_schematic`'s `rotation` turns one schematic into four, and its
`replacements` re-materialises the same shape in a different block set.

**A registry of placed parts is the one new structure**, in mod storage:
`{id, part, pos, rot, material, sockets_used, born_cycle, last_mutated_cycle}`. It costs almost
nothing and it is what makes everything below possible — including `/undo`, without which an
experimenting agent cannot be given any freedom.

### 2026-09-13 — Mutation is an infection with a focus, and the frontier is maths

Vitalii's framing, and it settles the mechanic: H11 is not a per-block dice roll, it is an
**infection spreading from a focus**. The v1.2 rules table stays exactly as planned; what changes is
what selects its targets.

**The engine is already shaped for contact spread.** An ABM takes `neighbors` (and, from 5.10,
`without_neighbors`), so "change only next to something already infected" is one field — the same
mechanic as the engine's own canonical lava-cooling example.

What the metaphor buys, none of which had a mechanic before:

| | |
|---|---|
| **susceptibility per material** | crystal spreads fast, colony hull resists — so the player has a reason to choose what they build with |
| **incubation** | the H11 glyph appears before the material changes: a warning, and something for the event card to report |
| **quarantine** | the M4 anchor in `ref-03` suppresses mutation in a radius — now that is a barrier contact cannot cross, not just a look |
| **a frontier the player can watch approach** | tension, and a reason to build away from it or against it |

**The conflict, and the fix.** ABMs run only on loaded blocks, so contact spread alone would advance
the infection *only where the player is standing* — run away and it freezes. That breaks the fiction
and the determinism together.

So the two levels are split:

- **The frontier is a pure function.** `infected(pos, cycle) = dist(pos, focus) < r(cycle) + noise(pos)`.
  Computable for any point at any time with no map loaded, independent of where the player has been.
- **The detail is ABMs**, working *inside* a frontier that has already been decided. Contact spread
  survives as local drawing, not as the thing that computes the boundary.

**Determinism is the invariant to protect.** Lazy evaluation means the result must not depend on when
the player walked past, so every rule is a pure function of `(state, cycle, seed)` —
`hash(part_id, cycle, seed) < threshold`, never a per-tick dice roll. Otherwise two players with the
same seed get different worlds and the cycle log describes something that never happened.

**Mutate few things per cycle.** Forty changes read as noise; one reads as an event — which is why the
reference art's `WORLD CHANGE` card shows a single change. With the part registry that card also stops
being generic: *"HABITAT 02 → recursive lithic growth, built cycle 3, changed cycle 11"* rather than
*"regolith → ..."*.

**One trap, named early.** The player extends things by hand. Re-placing a schematic would erase that
and read as a bug. So mutation edits nodes **in place**, touching only those that still match the
original schematic — which is also what `CLAUDE.md` already requires: old blocks stay, changed ones
carry the H11 stencil.

**This closes an open question.** `CLAUDE.md` lists "catching up missed cycles after shutdown" as open
at M4. It is now answered: lazily, at block load, via LBM (the engine tracks
`lbm_introduction_times` in `env_meta.txt` for exactly this), computing the missed cycles from the
frontier function rather than replaying them.

## The colony retheme

### 2026-09-14 — A gate that had been asserting sixteen times what it claimed

`test_worldgen.sh` checked `trees >= 20` and its own comment said this was the v0.3 DoD, *"at least 20
trees in a 128x128 area"*. It was not. `trees` counts **sampled columns** containing a spire, and the
probe walks every 4th column on both axes — one column in sixteen. The threshold was therefore
demanding about **320 growths**, sixteen times what anyone wrote down.

**It passed for a year of commits because the margin was enormous**, and went red the instant the
margin shrank for an unrelated reason. That is the failure mode worth remembering: a wrong assertion
with a comfortable margin is indistinguishable from a right one until something moves.

The probe now reports `growths` — the sample scaled by the step — and `STEP` is a named constant
instead of a literal `4` in the loop, because the scale-up depends on it and a literal in one place
with a constant in another is how two numbers quietly stop agreeing. `trees` survives as a floor
(`>= 4`) that still catches a schematic placing nothing.

### 2026-09-14 — The same density, a different world: 0.032 magenta is not 0.032 green

The retheme changed the textures and nothing about the geometry, and the first device screenshot came
back as a **solid pink field to the horizon** — no terraces, no water, no sense of scale. Nothing was
broken: `test_worldgen` had just reported `surface_top=regolith 93%`, `water=70`, `trees=31`, all
green, describing a world that was unplayable to look at.

v0's 0.032 was tuned for green canopies, where a dense wood still reads as ground with trees on it.
The identical geometry in magenta reads as a roof. Now **0.010** — roughly 160 growths, scattered
groves, terrain visible between them, and the crowns still the loudest thing in the frame.

**Neither of these was findable from the gates.** Every acceptance check was green while the world was
wrong, and the only reason either is known is a screenshot pulled off the device with `grim`. The
gates prove the world contains what it should; they have no opinion about whether it can be looked at.

### 2026-09-14 — check_assets.py is an every-issue gate now, because it carries a contract

`ARCHITECTURE.md` §Components and `nodes.lua` drifted apart for a whole phase: the document went on
listing nine nodes under the retired v0 ids while the code registered thirteen colony ones, and
nothing noticed — because the document is prose and nothing reads prose.

So the assertion is now code. `check_assets.py` parses the node ids out of §Components and out of
`nodes.lua` and compares the sets, reporting a finding in either direction. It was the right home for
it (the alternative, `check_lua.sh`, is shell and would need a Lua parser for a three-line set
difference) — but only once it runs every time, and it was documented as art-only, so exactly the
change class that renames nodes could skip it.

**Measured before promoting it: 1.02 s.** Four of the five pipeline skills already ran it
unconditionally, so this aligns the written policy with what was happening anyway.

The coupling this introduces is stated in both the document and the parser: inside §Components'
**grown** and **built** bullets, nothing is in backticks except a node id. That is a small price for
a contract that fails red instead of rotting quietly, and the parser goes red — not blind — if the
heading or the bullets are renamed.

### 2026-09-14 — The ladder inverted and the audit did not notice, because it checked the arithmetic

`ART-COLONY.md` §4.1 Rule 1 — inside the section headed *this part is binding* — prescribed the value
ladder **drift > lithic > regolith > hull > prefab > fines**, and said the order was chosen "so the
cliffs and dunes read brighter against the ground". The delivered pack measures **hull 86.8 > drift
77.9 > regolith 69.7 > prefab 58.7 > fines 50.4 > lithic 42.0**: bedrock fell from second-brightest to
the floor and the ship's plating rose to the top. The steps are 8.8 · 8.2 · 11.1 · 8.3 · 8.4 — every
one over the required 8.

**The shipped order is accepted, and §4.1 now prescribes it.** A dark bedrock rung is what makes a cut
terrace read as a step rather than a stripe: a pale top face over a dark cut face is Rule 5 expressed
by the ladder instead of fought by it. And a hull brighter than anything the planet has is how the
lander stays findable at 100 nodes, which is the one silhouette the player must be able to get back to.
The brief's version was a reasonable guess written before any texture existed; this one was arrived at
with tiles on a screen.

**The lesson is in how it went unnoticed for a release.** §11's audit row read "holds at every step",
which was true — it measured the five steps, found them all ≥ 8, and said so. It never compared the
*sequence*, which is the half of Rule 1 the rule itself called a deliberate choice. So a binding rule's
arithmetic was verified and its intent was not, and three documents then certified compliance:
§11, ROADMAP v0.8's DoD ("the pack passes every §4.1 separation rule"), and `nodes.lua`, whose lithic
row cites §4.1 for bedrock being "the darkest rung" — citing the spec for the opposite of what the spec
said. Nothing was broken on screen; what was broken was authority. A v1.1 biome author placing new
materials by the binding rule would have put them on the wrong L\* bands, out of a document that read
as verified. **A rule that states a reason needs a check that tests the reason.**

Three things came out of re-measuring rather than re-reading, and they are recorded in §11:

- **Rule 6 (30% brightness) had no audit row at all, and could never have had a passing one.** Multiply
  an encoded colour by 0.3 and white itself lands at L\* 32.5, so above bedrock's dimmed 11.1 there is
  room for three rungs of 8 L\*, not six: no six-material ladder passes Rule 6, in this pack or any
  other. Dimmed, 66 of 105 pairs sit inside 8 L\* against 24 at full brightness. Hue survives the
  multiply as an angle (nothing moves more than 2.7°) but not as chroma (`prefab` 6.3 → 2.34). So
  Rule 6 is a check on the **light**, not the palette — which is the same conclusion v0.6 reached from
  the other end when night on the device was fixed with emitting blocks (`crust` 12, `beacon` 14)
  rather than a gamma setting. The row now says that instead of being absent.
- **`prefab` ↔ `regolith_side` is a real Rule-2 failure and is now open** rather than unlisted: ΔL\*
  5.1, Δhue 49.9°, ΔC 5.3, with none of the escapes the other close pairs have, at the
  built-against-terrace boundary — the commonest thing a player will build. The cheapest measured lever
  is lightness: lift `prefab` 2.9 L\* to 61.6, which restores the 8 L\* against the terrace face and
  creates no new sub-60° pair. Logged for the next re-delivery, not fixed by this pass — **the art was
  not touched.**
- **A review's suggested fix can be wrong and only measuring says so.** The code review proposed
  brightening `lithic_top` about 5 L\* to thicken Rule 5's thinnest pair, "headroom to fines at 50.4
  exists". It does not: that puts `lithic_top` 0.5 L\* from `fines` at Δhue 41°, trading a thin
  top/side step for a live collision between two layers of the same column. The pair is accepted at
  +2.9 with the reason stated instead.

## v0.9 — The review pass

### 2026-09-14 — The one dial was never the only dial: v7's mountains and rivers were still on

`mapgen.lua` pinned three noise parameters and claimed height was "simply terrain_base". It was not.
`mgv7_spflags` was never set, so the engine default — `mountains,ridges,nofloatlands,caverns` — kept
running v7's **mountain pass** (`mgv7_np_mount_height`, offset 256, scale 112, spread 1000) and its
**ridge river-carving**, neither of which reads any of the three pinned noises. The file also said in
so many words that "the pocket world has lakes and a sea, not rivers", beside a river-water alias.

**Measured, because inside the gate's window nothing shows.** Two headless worlds on the same seed,
48 sample sites out to radius 8000:

| | highest surface | the patches at (1000,1000) and (500,−2500) |
|---|---|---|
| engine defaults | **y = 179** at (−2393, 0) | solid meltwater at the water line — ridge-carved channels |
| flags pinned | **y = 31** | dry land |

The island's own surface runs 6–25, and `test_worldgen.sh` reported byte-identical numbers before and
after the pin. That is the whole point: the gate measures 128×128 and the world is deliberately
unbounded, so a player walking out of the measured window met mountains above the biome's `y_max` —
bare lithic, no regolith, no growths — and canyons the design says do not exist.

### 2026-09-14 — zoom_fov is an object property, and it does not remove the button

Two corrections, one of them to this review's own finding.

`tools/device/gamepad.conf` carried `zoom_fov = 72` and a confident comment that it made zooming a
no-op. It is **not a client setting at all** — it is a player object property — so the engine ignored
the line the way it ignores any unknown key, which is the real reason the v0.7.1 measurement recorded
that "zoom_fov = fov did NOT work". The line is gone; `fov = 72` stays, because the three profiles
were measured at it.

And the review claimed that setting the property to 0 "kills the button". **It does not on 5.10.**
Read in that version's `touchcontrols.cpp`: the zoom button is added unconditionally, with no
zoom-capability test. So the property silences what the button *does* — the camera never enters its
zoom branch — while the button and its tap zone stay on screen, and a tap still reaches `turn.lua` as
a turn. The magnifier is cosmetic residue until 5.11's touchscreen layout editor.

The `Aux1` label is conditional on exactly one setting, `virtual_joystick_triggers_aux1` — but turning
it on moves aux1 onto the virtual joystick, so every movement drag that leaves the centre circle would
turn the camera right. A live misfire in exchange for a dead label is a bad trade; it stays.

### 2026-09-14 — A quarter of spawns landed on a crown, and the fallback that fix needed

`settle()` stopped its descent at the first solid node with two clear above it. Under a growth that
node is the **top of the bloom crown**, so the player was placed standing on the canopy; the
keep-descending branch could only ever fire for an interior gap. Measured over all **6228** real
spawn candidates in the 81×81 columns around the origin on the shipped seed: **1122 of them — 18% —
landed on bloom.**

Descending through the `tree` and `leaves` groups fixes it, but the naive form regressed 225
candidates (3.6%) from "standing on a crown" to "left at the unsettled candidate" — the trunk column,
and more often a crown resting on a neighbouring rise, where there is no ground with headroom in the
window at all. So the loop keeps the topmost growth-top as a **fallback** and uses it only when no
ground qualifies. Final: 6003 on ground, 225 on a crown, **0 nowhere**.

This is also why `leafdecay` came off the bloom row in the same change. It was a minetest_game
convention no engine code implements, advertising decay this game deliberately does not ship — while
`leaves`, the group beside it, is now genuinely load-bearing: the spawn descent reads it to tell
growth from ground.
