--- The block catalogue.
--
-- One table and one loop. The table is the point: from v1 the H11 mutation rules
-- are rows of the form `rule -> block transformation -> condition` addressing
-- exactly these node ids, and a catalogue written as a hundred separate
-- core.register_node calls cannot be addressed that way. Adding a block is
-- adding a row; it is never adding a branch.
--
-- The row shape is a contract (specification/ARCHITECTURE.md, "Components"):
--
--   id          string, required. Node id without the "h11_world:" prefix.
--   description string, required. Shown in the inventory.
--   tiles       list, required. See the tile-order note below.
--   groups      table, required. Dig groups; every node must be diggable by
--               something, or the player can create a block they cannot remove.
--   drawtype    string, optional. Omitted means a normal cube.
--   light       number, optional -> light_source.
--   extra       table, optional. Merged last, for the handful of fields only one
--               node needs (liquid plumbing, sounds). Kept separate so the common
--               rows stay readable rather than every row carrying empty slots.
--
-- TILE ORDER IS A TRAP. Luanti reads tiles as
--     {top, bottom, right, left, back, front}
-- with shorthand fill-in: one entry means all six faces, two means top/bottom
-- then the four sides, three means top, bottom, then sides. So turf needs a
-- THREE-element list with dirt explicitly in the middle. Give it two and the
-- green-fringed side texture is drawn on the block's underside, which looks
-- almost right from above and wrong from anywhere else. This is one of the three
-- engine strictnesses that fail silently rather than loudly.

local S = core.get_translator and core.get_translator("h11_world") or function(s) return s end

--- The catalogue. Order is presentation order, not load-bearing.
local NODES = {
	{
		id = "stone",
		description = S("H11 Stone"),
		tiles = { "h11_stone.png" },
		groups = { cracky = 3, stone = 1 },
	},
	{
		id = "dirt",
		description = S("Dirt"),
		tiles = { "h11_dirt.png" },
		groups = { crumbly = 3, soil = 1 },
	},
	{
		-- Three tiles, not two: {top, bottom, sides}. See the note above.
		id = "turf",
		description = S("Turf"),
		tiles = { "h11_turf_top.png", "h11_dirt.png", "h11_turf_side.png" },
		groups = { crumbly = 3, soil = 1 },
	},
	{
		id = "sand",
		description = S("Sand"),
		tiles = { "h11_sand.png" },
		groups = { crumbly = 3, falling_node = 1, sand = 1 },
	},
	{
		-- Two tiles: {top, sides}. The top repeats on the bottom, which is what a
		-- cut log should look like from either end.
		id = "trunk",
		description = S("Trunk"),
		tiles = { "h11_trunk_top.png", "h11_trunk_top.png", "h11_trunk_side.png" },
		groups = { choppy = 2, tree = 1 },
	},
	{
		-- allfaces_optional lets the engine collapse leaves to a cheaper draw on
		-- the low graphics profile, which is exactly what v0.7 measures.
		id = "leaves",
		description = S("Leaves"),
		drawtype = "allfaces_optional",
		tiles = { "h11_leaves.png" },
		groups = { snappy = 3, leafdecay = 3, leaves = 1 },
		extra = { paramtype = "light", waving = 1, sunlight_propagates = true },
	},
	{
		-- The H11 block: what the algorithm leaves behind. Registered from v0 so
		-- the catalogue is complete and the art can be judged on the device in
		-- v0.7, even though nothing places it until v1's mutation cycle.
		id = "crust",
		description = S("H11 Crust"),
		tiles = { "h11_crust.png" },
		groups = { cracky = 2, stone = 1 },
		light = 3,
	},
	{
		-- Source only in v0.2. Its flowing partner is v0.3's row, and the two must
		-- be cross-referenced through liquid_alternative_* or the first shoreline
		-- the player digs spawns unknown-node checkerboards.
		id = "water_source",
		description = S("Water"),
		drawtype = "liquidsource",
		tiles = {
			{
				name = "h11_water.png",
				animation = { type = "vertical_frames", aspect_w = 32, aspect_h = 32, length = 2.0 },
			},
		},
		groups = { water = 3, liquid = 3 },
		extra = {
			paramtype = "light",
			walkable = false,
			pointable = false,
			diggable = false,
			buildable_to = true,
			is_ground_content = false,
			drowning = 1,
			liquidtype = "source",
			liquid_alternative_flowing = "h11_world:water_flowing",
			liquid_alternative_source = "h11_world:water_source",
			liquid_viscosity = 1,
			post_effect_color = { a = 90, r = 79, g = 179, b = 201 },
		},
	},
}

--- Required keys on every row. Asserted rather than assumed: a row added in a
--- later phase that quietly omits `groups` produces a block nothing can dig,
--- which is discovered by a player, not by a gate.
local REQUIRED = { "id", "description", "tiles", "groups" }

local function register(row, index)
	for _, key in ipairs(REQUIRED) do
		if row[key] == nil then
			error(("h11_world NODES row %d (%s) is missing required key %q")
				:format(index, tostring(row.id or "?"), key))
		end
	end

	local def = {
		description = row.description,
		tiles = row.tiles,
		groups = row.groups,
	}
	if row.drawtype then def.drawtype = row.drawtype end
	if row.light then def.light_source = row.light end
	for key, value in pairs(row.extra or {}) do
		def[key] = value
	end

	core.register_node("h11_world:" .. row.id, def)
end

for index, row in ipairs(NODES) do
	register(row, index)
end

core.log("action", ("[h11_world] registered %d nodes"):format(#NODES))

-- Exported so mapgen.lua can address the catalogue by id, and so v1's rules
-- table has something to be written against. The only global this mod defines.
h11_world = h11_world or {}
h11_world.NODES = NODES
