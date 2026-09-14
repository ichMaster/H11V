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
--   player   the hand, the starting inventory, the spawn, the privileges and the
--            HUD. After mapgen, because it hands the player blocks that nodes.lua
--            defined and reads the water level that mapgen.lua installs.
--   music    the looping track and the per-player /music switch.
--   turn     the shoulder-button camera, which only reads player controls and so
--            depends on nothing here.
--
-- All five ship. This list read as three for several versions after music and
-- turn landed, which is the kind of drift a header invites: a documented load
-- order that does not enumerate what is loaded is worse than none, because it is
-- read instead of the code below.
--
-- See specification/ARCHITECTURE.md §Components.

--- The engine floor, enforced instead of declared.
--
-- game.conf carried `min_luanti_version = 5.10` and no engine has ever read it:
-- lua_api.md's Games section lists every key the engine takes from game.conf and
-- there is no version among them (ContentDB's metadata key is spelled
-- min_minetest_version, and it is the website that reads it). So the floor was
-- announced in the one file that looks most like a contract and enforced
-- nowhere — the same unknown-field-ignored failure this mod documents for
-- mapgen aliases and node drawtypes. An older engine showed no version message
-- at all, only whichever of our calls it did not have, in a stack trace.
--
-- core.features is a fact about the running engine rather than a claim about it.
-- bulk_lbms is flagged 5.10.0 in lua_api.md's feature table, so it is exactly the
-- floor this game targets: the device runs 5.10.0 and the Mac 5.17.0, and
-- anything older stops here with a sentence naming the version.
if not core.features.bulk_lbms then
	error(("[h11_world] H11V needs Luanti 5.10 or newer; this engine reports %s")
		:format(core.get_version().string))
end

local modpath = core.get_modpath(core.get_current_modname())

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/mapgen.lua")
dofile(modpath .. "/player.lua")
dofile(modpath .. "/music.lua")
dofile(modpath .. "/turn.lua")

core.log("action", "[h11_world] loaded from " .. modpath)
