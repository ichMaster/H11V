# H11V — M0 specification: player and world on the PocketTerm35

M0 is one player in one world, without bots and without a server. The goal is to test the device and to see how well Luanti draws a voxel world on the Pi 5 GPU at 640x480, and which settings give a good picture at a stable frame rate. Anything that does not help answer that question is not part of M0.

Visual canon: the bright-luminous art direction fixed in [H11V-CONCEPT.md](H11V-CONCEPT.md) section 12 and the reference images in `specification/art/`. All M0 assets come from the designed pack ordered by [H11V-M0-DESIGN-BRIEF.md](H11V-M0-DESIGN-BRIEF.md); there is no procedural texture generation.

## 1. Outcome

A first-person game in the Minecraft style, heavily simplified: the player walks, jumps, looks around, takes blocks and places them. A world with terrain, water and trees and a day-night cycle, looking solid on a 3.5-inch screen. Plus documented measurements: fps on the device for several graphics profiles, and screenshots from the device in each of them.

M0 is done when, on the PocketTerm35, the game launches fullscreen from the Sway desktop, touch and keyboard work, the player can walk around and change the world, and `docs/decisions.md` records the fps, the chosen graphics profile, the Luanti version and the GPU renderer string proving hardware rendering (section 5).

## 2. Scope

In: the game `games/h11v` with a single mod `h11_world`; terrain with hills and hollows via the stock mapgen (v7, or flat with our own noise — the implementation's choice, the only criterion being a horizon with elevation rather than a slab); 8 block types in the bright-luminous H11V palette (dirt, turf, stone, sand, water, trunk, leaves, and the lithic crust bearing the H11 glyph; 9 registered nodes, since water needs a flowing partner — see section 8); simple trees; a day-night cycle; a digging hand drawn as the ivory gauntlet from the reference art; a starting inventory and an 8-slot hotbar styled per the art; a surface spawn; a minimal HUD (hotbar and crosshair only); the designed 32x32 asset pack integrated; the device profile `tools/device/minetest.conf`; launch scripts for the Mac and for the device plus a deploy script; and a headless world-generation check.

Out: bots, the brain service, the mutation cycle, the cycle HUD, H11 chat commands, sound, menus beyond the stock one with our menu art, any saving beyond what Luanti does by itself, and any mechanic other than walking, digging and placing.

## 3. Components

`games/h11v/game.conf` and the mod `h11_world`: block registration (`core.register_node`) with 32x32 textures from the designed asset pack; the mapgen aliases v7 actually reads (`mapgen_stone`, `mapgen_water_source`, `mapgen_river_water_source`) plus one `core.register_biome` call, which is what puts turf, dirt and sand on the surface — v6's `mapgen_dirt` / `mapgen_dirt_with_grass` / `mapgen_sand` aliases are ignored by v7 (see section 8); tree decorations via `core.register_decoration` or a simple `on_generated`; a hand with `tool_capabilities` for the groups `crumbly`, `cracky`, `choppy` and `snappy`; `register_on_newplayer` with the starting inventory; and the stock day-night cycle (`time_speed`).

`tools/device/minetest.conf`: fullscreen 640x480, `video_driver = ogles2` (VideoCore-native GL ES 2; `opengl3` is the fallback if the build lacks GLES), touch with the crosshair interaction style (`touch_use_crosshair` on 5.10, `touch_interaction_style = tap_crosshair` on 5.12+ — the default tap style draws no crosshair at all, and section 2 promises one), no `secure.*` needed. Three graphics profiles switched by separate files `device-low.conf`, `device-mid.conf` and `device-high.conf` (see section 5).

`tools/`: `run_local.sh` (Mac, a 640x480 window with the same settings as the device), `deploy_to_pi.sh`, `run_on_pi.sh` (Wayland via SDL), `test_worldgen.sh`.

## 4. Controls on the device

Touch for looking and tapping blocks; keyboard for WASD movement, space to jump, and digits to select a slot. Digging and placing use Luanti's stock touch gestures — hold to dig, short tap to place — with `touch_controls` enabled. Minimum UI element size 48 pixels, `hud_scaling` and `gui_scaling` around 1.4, font 20. Width, not height, is the binding constraint: the bar is one slot tall (~78 px at `hud_scaling` 1.4, about a sixth of 480), but 8 slots at the engine's 48 px base times 1.4 plus padding span roughly 627 of the 640 available pixels. Check the bar fits with margin at the device's display density; if it overflows or crowds the touch corners, cut to 6 slots or lower `hud_scaling`.

## 5. Graphics profiles for the measurements

**GPU preflight — before any measurement.** M0's whole question is what the Pi 5's GPU can do, so the render path must be the hardware V3D driver, never Mesa's llvmpipe software rasterizer (which "works" and silently answers a different question). Verify once per install: `glxinfo -B` / `eglinfo` (package `mesa-utils`) must name `V3D` as the renderer, `LIBGL_ALWAYS_SOFTWARE` must not be set, and after the first launch the renderer line in Luanti's `debug.txt` must not contain `llvmpipe` — `run_on_pi.sh` greps for exactly that and aborts with a loud message if it does. Record the renderer string in `docs/decisions.md`; measurements taken on a software renderer are void.

Three profiles, each launched on the device with the same seed and from the same spot. Fps is read from the F5 debug overlay (F3 toggles fog, and the chat command `/status` reports server uptime and lag, never client fps); the average and the minimum fps after 30 seconds of walking are recorded.

The ladder is keyed on settings that exist in current Luanti. Basic shaders became mandatory in 5.11 and `enable_shaders` was removed, so shaders-on/off is not an axis unless the whole protocol is pinned to the Debian 5.10 package — record the version actually used before measuring.

Low: `viewing_range` 40, `smooth_lighting = false`, no waving, `mip_map = false`, post-processing and bloom off, `fps_max` 30.
Mid: `viewing_range` 60, `smooth_lighting = true`, `mip_map` and bilinear filtering off (a pixel look), no dynamic shadows, `fps_max` 30.
High: `viewing_range` 100, smooth lighting, waving leaves and water, fog, `fps_max` 60; dynamic shadows measured separately as a fourth run, since they most likely will not hold up.

Separately, judge by eye and write down in words: the legibility of the 32x32 textures at 3.5 inches, graininess and shimmer on distant blocks, how the bright-luminous palette holds up at night, and whether the H11 glyph on the crust block reads at typical viewing distance.

## 6. Acceptance test

Without a screen: `tools/test_worldgen.sh` starts `luantiserver` with the game, emerges a 128x128 area, checks that there is a surface with an elevation range of at least 8 blocks, that there is water, and that there are at least 20 trees, then exits with code 0. On the Mac: `run_local.sh` shows the world in a 640x480 window, and the player walks, digs and places blocks. On the device: section 1, with fps across the three profiles and screenshots in `docs/device/`, and the GPU preflight from section 5 passed (renderer is V3D, not llvmpipe).

## 7. Project structure

The repository after M0:

```
H11V/
  LICENSE
  CLAUDE.md
  games/
    h11v/
      game.conf                   game title, description
      screenshot.png              optional 3:2 key shot from the asset pack
      menu/
        icon.png                  H11 hex-cluster glyph (from the asset pack)
        header.png                H11V logotype (from the asset pack)
        background.png            key-art background (from the asset pack, optional)
      mods/
        h11_world/
          mod.conf
          init.lua                loads the modules below in order
          nodes.lua               the NODES table + registration loop + mapgen aliases
          mapgen.lua              mapgen selection and parameters, tree decorations
          player.lua              hand, starting inventory, spawn, hotbar and crosshair styling
          textures/               the designed 32x32 pack (h11_*.png) + UI textures
  tools/
    device/
      minetest.conf               shared device base: fullscreen 640x480, touch, scaling
      device-low.conf             profile deltas (section 5)
      device-mid.conf
      device-high.conf
    run_local.sh                  Mac: 640x480 window, device-equivalent settings
    run_on_pi.sh                  device: Wayland via SDL, fullscreen
    deploy_to_pi.sh               rsync game + assembled conf to the Pi
    test_worldgen.sh              headless acceptance test (section 6)
  specification/
    eng/  ukr/  art/
  docs/
    decisions.md                  running log of closed decisions and measurements
    device/                       fps notes and screenshots per profile
```

Rules the structure encodes: the game is self-contained under `games/h11v` and can be symlinked or copied into any Luanti `games/` directory; everything device-specific lives under `tools/` and never inside the game; textures ship inside the mod (`h11_world/textures/`), because a Luanti mod's textures travel with the mod, while menu art lives at the game level (`menu/`).

## 8. Architecture

**Game vs engine.** Luanti draws, saves, lights and generates; `h11v` is content only. The game registers its own nodes and hands them to the stock generator two ways — the `mapgen_*` aliases for the structural nodes (stone, water) and a biome definition for the surface layers — which together are what make the stock generator build an H11V-looking world. Nothing in M0 patches or forks the engine.

**The GPU path.** Rendering on the device is hardware or the milestone is void: SDL video on Wayland (`SDL_VIDEODRIVER=wayland`, set by `run_on_pi.sh`), EGL + GL ES 2 through Mesa's V3D driver on the Pi 5's VideoCore VII, selected in the config as `video_driver = ogles2`. The failure mode this guards against is silent: with a broken EGL setup Mesa falls back to llvmpipe, everything still draws, and the fps numbers become fiction. Hence the section 5 preflight, the grep in `run_on_pi.sh`, and the renderer string in `docs/decisions.md`. On the Mac, `run_local.sh` needs no such guard — Apple's GL is always hardware — which is exactly why the measurements only count on the device.

**One mod, four small modules.** `h11_world` is deliberately a single mod in M0 (the concept's mod split into `h11_world` / `h11_bots` / `h11_hud` begins at M1-M2, when there is a second concern to separate).

- `nodes.lua` holds a single data table, `NODES`, and a loop that calls `core.register_node` for each entry. Nine registered nodes for eight player-visible block types: `h11_world:dirt`, `h11_world:turf`, `h11_world:stone`, `h11_world:sand`, `h11_world:water_source`, `h11_world:water_flowing`, `h11_world:trunk`, `h11_world:leaves`, `h11_world:crust`. Each entry carries tiles, dig groups, drawtype where needed, and light emission for the crust's glyph glow. Three details the engine is strict about:
  - Tile order is `{top, bottom, right, left, back, front}` with shorthand fill-in, so turf needs a **triple** — `{h11_turf_top.png, h11_dirt.png, h11_turf_side.png}` — or the green-fringed side texture lands on the block's underside. Trunk takes a pair (`{top, side}`, top repeating on the bottom, which is correct for a cut log).
  - Water is a **pair**: `h11_world:water_source` (`drawtype = "liquid"`) and `h11_world:water_flowing` (`drawtype = "flowingliquid"`, flow animation on `special_tiles`), cross-referenced through `liquid_alternative_source` and `liquid_alternative_flowing`. Without the flowing partner, the first shoreline the player digs spawns unknown-node checkerboards. (A still pond is possible with a source-only node at `liquid_range = 0`, but then water never flows — not what a Minecraft-like dig-a-channel world wants.)
  - Leaves use `drawtype = "allfaces_optional"` so the engine can simplify them on the low profile.

  The table, not the loop, is the point: M1's mutation rules will be entries of the form "rule → block transformation → condition" over these same ids, so the block catalogue must already live as data.
- `mapgen.lua` selects the mapgen and its parameters (single 128x128-scale map feel: modest height amplitude, water level, no caves in M0), wires the world's surface, and places trees — `core.register_decoration` with a small Lua-table schematic (trunk column + leaf blob), which keeps trees out of the walking-and-digging hot path entirely.

  Surface wiring is the one part worth stating precisely, because the obvious approach silently fails. Under v7 (and every mapgen except v6), the engine reads only three aliases — `mapgen_stone`, `mapgen_water_source`, `mapgen_river_water_source` — and the surface layers come from **biome definitions**, not from aliases. So M0 registers one `core.register_biome` entry (`node_top = h11_world:turf`, `depth_top = 1`, `node_filler = h11_world:dirt`, `depth_filler = 2`, `node_riverbed = h11_world:sand`) covering the whole heat/humidity range. This is a technical registration, not a gameplay biome — the three H11V biomes arrive at M1. Registering the v6 aliases (`mapgen_dirt`, `mapgen_dirt_with_grass`, `mapgen_sand`) instead yields a world of bare stone and water: v7 never reads them.
- `player.lua` overrides the hand (`core.override_item("", ...)`) with `tool_capabilities` for `crumbly`/`cracky`/`choppy`/`snappy` and the gauntlet `wield_image`; gives the starting inventory in `register_on_newplayer`; sets the hotbar length to 8 and its designed textures via `hud_set_hotbar_itemcount`, `hud_set_hotbar_image` and `hud_set_hotbar_selected_image`; and disables the HUD elements M0 does not use (health, breath) with `hud_set_flags`, leaving hotbar and crosshair.
- `init.lua` is only `dofile` calls in a fixed order: nodes, mapgen, player.

**Assets are content, not code.** The designed pack from [H11V-M0-DESIGN-BRIEF.md](H11V-M0-DESIGN-BRIEF.md) drops into `h11_world/textures/` and `games/h11v/menu/` under the exact filenames the brief fixes; code references those names and nothing else. Until the pack lands, headless work proceeds without textures (the server does not render), and visual steps wait — see section 9 ordering.

**Configuration layering.** `tools/device/minetest.conf` holds everything shared (fullscreen 640x480, `touch_controls`, scaling, font); the three `device-*.conf` files hold only the deltas from section 5. `deploy_to_pi.sh` concatenates base + chosen profile into the single config the Pi runs with, and `run_local.sh` does the same on the Mac with fullscreen swapped for a window. One source of truth for shared settings, no drift between profiles.

**Headless test mechanics.** `test_worldgen.sh` builds a throwaway world directory, enables a tiny test-only world mod (living under `tools/`, never shipped in the game) that on server start force-emerges the 128x128 area, scans it with a VoxelManip, prints one parseable result line (elevation range, water count, tree count) and calls `core.request_shutdown()`. The script greps the line, applies the section 6 thresholds, and exits 0/1. The game itself contains no test code.

## 9. Implementation plan

Each step is one commit (English message), and every step that can be checked headlessly is checked before moving on. Steps 1-3 do not need the asset pack; step 4 is where it lands.

0. **Toolchain.** Install Luanti on the Mac and on the Pi (Pi OS package; AppImage/Flatpak fallback if the repo version lags — this is also the first risk check for the 5.8 touch regression). On the Pi, run the GPU preflight from section 5 (`mesa-utils`, renderer = V3D) before anything else. Record both versions and the renderer string in `docs/decisions.md`. No commit; a decisions entry.
1. **Skeleton.** `games/h11v/game.conf` + empty `h11_world` (mod.conf, init.lua). The game appears in Luanti's menu and creates a world. In parallel, send [H11V-M0-DESIGN-BRIEF.md](H11V-M0-DESIGN-BRIEF.md) to Claude Design so asset production overlaps steps 2-3.
2. **Blocks and terrain.** `nodes.lua` with the full NODES table and mapgen aliases; `mapgen.lua` with mapgen parameters; first version of `test_worldgen.sh` asserting the elevation range. Headless test green.
3. **Water and trees.** The water source/flowing pair registered and cross-referenced; the surface biome registration verified by generating a world and confirming turf on top rather than bare stone; tree decoration with the schematic; `test_worldgen.sh` extended to the full section 6 assertions (water present, ≥ 20 trees). Headless test green.
4. **Asset pack integration.** Drop the delivered pack into `textures/` and `menu/`; verify every NODES entry resolves its textures (no "unknown node" checkerboards) in a Mac window run.
5. **Player layer.** `player.lua`: hand with gauntlet wield image, starting inventory (a stack of each placeable block), surface spawn, 8-slot hotbar with the designed bar and selection frames, crosshair, HUD flags. Mac run: walk, dig, place, day-night pass.
6. **Device profiles and scripts.** `tools/device/*.conf`, `run_local.sh`, `run_on_pi.sh`, `deploy_to_pi.sh`. `run_local.sh` on the Mac reproduces device settings in a 640x480 window.
7. **Device session.** Deploy to the PocketTerm35; re-check the GPU preflight, then run the section 5 measurement protocol (three profiles + the shadows run, same seed, same spot, 30 s walks); save screenshots to `docs/device/`; write fps, the chosen default profile, the Luanti version and the renderer string into `docs/decisions.md`. M0 done per section 1.

Dependency note: only step 4 blocks on Claude Design. If the pack is late, steps 5-6 may proceed with placeholder-free code paths (hotbar/crosshair styling calls guarded behind a texture-exists check), but the device session (step 7) waits for the pack — measuring fps with missing textures would not answer M0's question about the real picture.

## 10. Next milestones

M1 — the H11 mutation cycle and the cycle HUD (in the new mod `h11_hud`). M2 — bots on rules. M3 — the brain service on the LAN server. See [H11V-CONCEPT.md](H11V-CONCEPT.md) section 7. No bot or brain code exists yet and none is carried in from anywhere: it will be written fresh at M2 and M3.
