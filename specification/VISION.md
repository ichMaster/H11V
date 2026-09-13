# Vision — H11V

## In one sentence

H11V is a handheld voxel game built for one specific machine — a 3.5″ 640×480 PocketTerm — where a
first-person player and three small robots share a pocket-sized world that an algorithm slowly
rewrites, and the arc of the project is to make that fiction literally true: by the last version the
algorithm mutating the world is real code, and the robots deciding what to do about it are a real
model running on a machine down the hall.

## What we are building

A Minecraft-shaped game that runs natively at 640×480 on a Raspberry Pi 5 handheld, one render pixel
per panel pixel, with hand-authored 32×32 pixel art in a bright-luminous palette. It starts as one
island you can walk, dig and build on, and grows into a world with a pulse: blocks that mutate from
cycle to cycle, three bots that live there on their own rules, then a brain on the local network that
gives those bots language and judgement, and finally tools for the player to argue with the algorithm
— protect a patch, feed a mutation, plant an anchor.

The point of the game is not crafting. It is cohabitation. The player is a witness and a part-time
gardener in a world that is alive, luminous, and not entirely theirs.

The name is the fiction. *Hypothesis 11* is the proposition that one algorithm mutates both an
environment and the creatures inside it. In v1 that is a table of deterministic rules and a glyph
etched on every block it has touched. By v3 the creatures are reading their own situation through a
language model. The roadmap's endpoint is the same sentence as a system diagram.

## For whom

One player, one device, in the hand. The Waveshare PocketTerm35 is the target and the constraint: a
640×480 panel, a keyboard, a touch layer, four Cortex cores and a V3D GPU, Raspberry Pi OS with Sway
on Wayland, and no mouse. Everything is sized to that — the view range, the art, the HUD, the frame
budget, the controls. It runs on a Mac too, at the same resolution with the same settings, because
that is where it is developed; the Mac is an emulator of the device, never a second platform with its
own affordances.

There is no multiplayer in the first year and no second screen size. A second resolution is a second
product; we do not have one.

## Principles

- **One device, one resolution.** 640×480 native, nearest filtering, no upscale and no letterbox.
  Minimum UI element 48 px, because a finger is not a mouse. Every asset and HUD coordinate is
  authored for that grid.
- **The device is the truth.** A frame-rate claim measured on the Mac is not a measurement, and a
  measurement taken on a software rasterizer is not a measurement either. The GPU preflight in
  [ARCHITECTURE.md](ARCHITECTURE.md) is a gate, not a suggestion.
- **We write content, not an engine.** Luanti draws, lights, saves, generates and networks. Every
  line we write is a Lua mod on top of it. Whenever a need looks like it wants a new engine feature,
  the answer is almost always a stock primitive we have not read about yet.
- **Mechanics live as data.** The block catalogue is a table from v0 on; mutation rules are a table
  of `rule → block transformation → condition` over that same catalogue; bot characters are needs
  weightings in a table. This is what makes the endpoint reachable — an algorithm that rewrites the
  world only has to rewrite data, and a model that proposes a mutation only has to propose a row.
- **The brain never blocks a tick.** A bot's body runs on fast ticks with no network in the loop and
  executes one intent for hundreds of ticks. The brain is asked at four specific moments and answers
  whenever it answers. With no server, the bots keep living on rules.
- **The world is small on purpose.** One map on the order of 128×128 blocks, a few biomes, no
  infinite generation. A pocket world you can come to know is the point; an endless one you cannot is
  a different game.

## The arc

```
v0  the device       one player, one island, on the panel, at a measured frame rate
v1  the world        H11 mutates it — biomes, rules, cycles, a visible log
v2  the inhabitants  three bots living on rules, reacting to what H11 does
v3  the brain        a local model on the LAN gives them judgement and character
v4  the argument     the player gets tools to influence, protect and talk
```

The world and its inhabitants grow on separate axes and meet at the mutation cycle: v1 makes the
world mutate, v2 puts creatures in it that notice, v3 makes those creatures able to reason about what
they noticed, v4 lets the player take a side. Complexity is added by version, never all at once.

## Not this

No infinite world, no crafting with recipes, no hostile mobs, no combat, no multiplayer in the first
year, no custom renderer. All of it exists in Luanti and can be switched on later; none of it is part
of this project. There is no winning: a session is a few cycles long, the world is saved, and it
keeps mutating while the device is off.

H11V is also a standalone project. No code, prompts or assets are carried in from any other
repository — the tooling in `codegen/` and `.claude/skills/` is shared machinery, the game is not.

## Still open

1. How long one mutation cycle lasts in real time — minutes (a game for one session) or hours and
   days (a world that lives in the background)?
2. Which local model runs on the brain server, sized to answer in 1–3 seconds for three bots, and
   whether that machine has a GPU.
3. Whether the README and the player guide stay Ukrainian while the code and specifications are
   English.
