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
-- See specification/ARCHITECTURE.md §Components. The modules arrive in v0.2
-- (nodes, mapgen) and v0.5 (player); until then this file registers nothing,
-- which is a complete and valid Luanti game — just an empty one.

local modpath = core.get_modpath(core.get_current_modname())

-- dofile(modpath .. "/nodes.lua")     -- v0.2
-- dofile(modpath .. "/mapgen.lua")    -- v0.2
-- dofile(modpath .. "/player.lua")    -- v0.5

core.log("action", "[h11_world] loaded from " .. modpath)
