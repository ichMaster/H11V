--- H11V world mod.
--
-- Loads this mod's modules in a fixed order. The order is the dependency order
-- and is not incidental:
--
--   nodes    the NODES data table and the registration loop. Every block type
--            in the game is defined here and nowhere else, because from v1 the
--            mutation rules are rows addressing these same node ids.
--   mapgen   mapgen parameters, the structural aliases and the surface biome.
--            Needs the nodes to exist before it can point the generator at them.
--   player   the hand, the starting inventory, the spawn and the HUD. Last,
--            because it hands the player blocks that nodes.lua defined.
--
-- See specification/ARCHITECTURE.md §Components. mapgen arrives later in v0.2,
-- player in v0.5.

local modpath = core.get_modpath(core.get_current_modname())

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/mapgen.lua")
dofile(modpath .. "/player.lua")
dofile(modpath .. "/music.lua")

core.log("action", "[h11_world] loaded from " .. modpath)
