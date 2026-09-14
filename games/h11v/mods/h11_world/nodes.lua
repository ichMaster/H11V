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
-- THE CATALOGUE IS IN TWO HALVES, and the split is the art direction rather than
-- a filing convenience (specification/ART-COLONY.md §2). Everything here belongs
-- to exactly one of two material languages and they are never blended:
--
--   GROWN  — the planet. Mineral, crystalline, cool. regolith, fines, lithic,
--            drift, spire, bloom, meltwater, and the H11 crust.
--   BUILT  — the colony. Machined, flat, seamed. hull, prefab, crate, beacon.
--
-- A player must be able to tell which half a block belongs to at eight pixels.
-- That is why the beacon and the crust both emit light but look nothing alike:
-- one is a lamp somebody bolted down, the other is the algorithm showing through.
--
-- TILE ORDER IS A TRAP. Luanti reads tiles as
--     {top, bottom, right, left, back, front}
-- with shorthand fill-in: one entry means all six faces, two means top/bottom
-- then the four sides, three means top, bottom, then sides. So regolith needs a
-- THREE-element list with fines explicitly in the middle. Give it two and the
-- crusted side texture is drawn on the block's underside, which looks almost
-- right from above and wrong from anywhere else. This is one of the three engine
-- strictnesses that fail silently rather than loudly.

local S = core.get_translator and core.get_translator("h11_world") or function(s) return s end

--- The catalogue. Order is presentation order, not load-bearing.
local NODES = {
	----------------------------------------------------------------- the planet
	{
		-- Bedrock. The darkest rung of the value ladder (ART-COLONY.md §4.1), so
		-- cliff faces read against the pale ground rather than merging with it.
		-- Three tiles because exposed bedrock has a weathered top face worth
		-- seeing; the same face serves underneath, as a cut plate should.
		id = "lithic",
		description = S("Lithic Bedrock"),
		tiles = { "h11_lithic_top.png", "h11_lithic_top.png", "h11_lithic.png" },
		groups = { cracky = 3, stone = 1 },
	},
	{
		id = "fines",
		description = S("Mineral Fines"),
		tiles = { "h11_fines.png" },
		groups = { crumbly = 3, soil = 1 },
	},
	{
		-- The walkable surface: mineral crust with a thin biofilm, not turf. Three
		-- tiles, not two: {top, bottom, sides}. See the note above.
		id = "regolith",
		description = S("Regolith"),
		tiles = { "h11_regolith_top.png", "h11_fines.png", "h11_regolith_side.png" },
		groups = { crumbly = 3, soil = 1 },
	},
	{
		id = "drift",
		description = S("Drift"),
		tiles = { "h11_drift.png" },
		groups = { crumbly = 3, falling_node = 1, sand = 1 },
	},
	{
		-- The "tree" of this world, and deliberately not one: a crystal stalk. Two
		-- tiles: {top, sides}, the top repeating underneath, which is what a cut
		-- growth should look like from either end.
		--
		-- `choppy` is kept as the dig group even though nothing here is wood. The
		-- group is a hardness class, not a material claim, and renaming it would
		-- mean re-teaching the hand in player.lua for no gain a player can see.
		id = "spire",
		description = S("Crystal Spire"),
		tiles = { "h11_spire_top.png", "h11_spire_top.png", "h11_spire_side.png" },
		groups = { choppy = 2, tree = 1 },
	},
	{
		-- The crown: hanging crystal filaments. allfaces_optional lets the engine
		-- collapse it to a cheaper draw on the low graphics profile, which is what
		-- v0.7 measured.
		--
		-- `leafdecay = 3` stood here and is deliberately gone. It is a
		-- minetest_game convention, not an engine group: stock Luanti attaches no
		-- behaviour to it, and this game ships no decay ABM on purpose (mapgen.lua
		-- says why). So the row advertised a rule nothing implements — dig a spire
		-- and its crown hangs in the air for the life of the world. A row in this
		-- table is read as the block's behaviour, by a person now and by v1's
		-- mutation rules later, and a group that only looks like behaviour is worse
		-- than no group at all. `leaves` stays and is real: player.lua's spawn
		-- descent reads it to tell growth from ground.
		id = "bloom",
		description = S("Bloom"),
		drawtype = "allfaces_optional",
		tiles = { "h11_bloom.png" },
		groups = { snappy = 3, leaves = 1 },
		extra = { paramtype = "light", waving = 1, sunlight_propagates = true },
	},
	{
		-- The H11 block: what the algorithm leaves behind.
		--
		-- It is also one of only two lights in the game. Night on the device was
		-- reported as "I can't see anything", and 5.10 offers no lever to brighten
		-- it: there is no light_curve_* family in this build and display_gamma
		-- measurably does nothing (1.0 and 2.5 render identically). In this engine
		-- light comes from blocks, so the fix has to be a block.
		--
		-- Making it the crust rather than adding a torch is the point. The art
		-- canon already gives H11 a cyan-to-lilac glow on everything it has
		-- touched; a torch would be a new object with no place in the fiction,
		-- while a glowing crust is the fiction. From v1 the mutation front will
		-- literally light the world as it spreads.
		--
		-- 12 of a possible 14 (`core.LIGHT_MAX`): bright enough to work as a lamp,
		-- short of the daylight ceiling, and two steps below the colony's own
		-- beacon — the player's light should be the better light.
		id = "crust",
		description = S("H11 Crust"),
		tiles = { "h11_crust.png" },
		groups = { cracky = 2, stone = 1 },
		light = 12,
	},
	{
		-- Meltwater. "liquid", not "liquidsource": the latter is not a Luanti
		-- drawtype, and an unknown one falls back to a normal cube with no error —
		-- water that looks like solid stone. ARCHITECTURE.md pins this.
		id = "melt_source",
		description = S("Meltwater"),
		drawtype = "liquid",
		tiles = {
			{
				name = "h11_melt.png",
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
			liquid_alternative_flowing = "h11_world:melt_flowing",
			liquid_alternative_source = "h11_world:melt_source",
			liquid_viscosity = 1,
			-- Stated on both rows of the pair and identical on both, though only
			-- one copy is ever read: the engine takes the spread distance from the
			-- FLOWING definition on every path (5.10 servermap.cpp resolves
			-- `liquid_kind` to `liquid_alternative_flowing_id` before reading
			-- `liquid_range`). This row said nothing and so carried the engine's
			-- default of 8 while its partner said 7 — invisible today, and a trap
			-- for the v1 rules row that clones this row's plumbing for a second
			-- liquid and inherits a number nobody chose.
			liquid_range = 7,
			-- Sampled from the delivered texture (mean rgb 26,149,113): the tint
			-- the screen takes when the player's head goes under. A leftover teal
			-- from the v0 pack would have quietly disagreed with the water itself.
			post_effect_color = { a = 90, r = 26, g = 149, b = 113 },
		},
	},
	{
		-- The other half of the liquid. Without it the first shoreline the player
		-- digs spawns unknown-node checkerboards: the engine wants somewhere to
		-- put the water that is no longer a source, and an unresolved
		-- liquid_alternative_flowing is not somewhere.
		id = "melt_flowing",
		description = S("Flowing Meltwater"),
		drawtype = "flowingliquid",
		-- A flowing liquid draws from special_tiles, not tiles: the engine needs
		-- the animated strip for the sloped faces it builds per flow direction.
		tiles = { "h11_melt.png" },
		groups = { water = 3, liquid = 3, not_in_creative_inventory = 1 },
		extra = {
			paramtype = "light",
			paramtype2 = "flowingliquid",
			walkable = false,
			pointable = false,
			diggable = false,
			buildable_to = true,
			is_ground_content = false,
			drowning = 1,
			liquidtype = "flowing",
			liquid_alternative_flowing = "h11_world:melt_flowing",
			liquid_alternative_source = "h11_world:melt_source",
			liquid_viscosity = 1,
			liquid_range = 7,
			post_effect_color = { a = 90, r = 26, g = 149, b = 113 },
			special_tiles = {
				{
					name = "h11_melt_flowing.png",
					backface_culling = false,
					animation = { type = "vertical_frames", aspect_w = 32, aspect_h = 32, length = 0.8 },
				},
				{
					name = "h11_melt_flowing.png",
					backface_culling = true,
					animation = { type = "vertical_frames", aspect_w = 32, aspect_h = 32, length = 0.8 },
				},
			},
		},
	},

	----------------------------------------------------------------- the colony
	--
	-- Four blocks that were made by people. Nothing places them: they exist so the
	-- player can build, and so that what the player builds belongs to a different
	-- world than the ground it stands on. From v2 they are also the materials the
	-- part catalogue is assembled from (ARCHITECTURE.md, "The build catalogue").
	{
		id = "hull",
		description = S("Hull Plate"),
		tiles = { "h11_hull.png" },
		groups = { cracky = 2, metal = 1 },
	},
	{
		id = "prefab",
		description = S("Prefab Panel"),
		tiles = { "h11_prefab.png" },
		groups = { cracky = 2, metal = 1 },
	},
	{
		-- Two tiles: a lid, and a flank. A crate with one texture on all six faces
		-- reads as a printed cube rather than as a box with a top.
		id = "crate",
		description = S("Cargo Crate"),
		tiles = { "h11_crate_top.png", "h11_crate_top.png", "h11_crate_side.png" },
		groups = { cracky = 3 },
	},
	{
		-- The colony's own light, and the reason it exists: until now the only way
		-- to see at night was to stand near something H11 had rewritten. A player
		-- should be able to light their own camp without the algorithm's help.
		--
		-- 14 is the engine's maximum (`core.LIGHT_MAX`), two steps above the
		-- crust's 12. That ordering is deliberate — what the colony built is the
		-- better lamp, and where the two meet the beacon wins.
		id = "beacon",
		description = S("Beacon"),
		tiles = { "h11_beacon.png" },
		groups = { cracky = 2, metal = 1 },
		light = 14,
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

--- The v0 names, kept resolvable.
--
-- A world generated before the colony retheme holds nodes called
-- `h11_world:turf`, and an id the engine cannot resolve renders as the unknown
-- node — a magenta-and-black checkerboard — rather than as anything explicable.
-- Aliases cost one line each and turn "the world is full of error cubes" into "the
-- world looks slightly wrong", which is the difference between a bug report and a
-- shrug.
--
-- They are not a migration: the ground keeps the shape it generated with, and
-- ART-COLONY.md §10 already accepted that pre-rename worlds are test fixtures
-- rather than saves. These exist so the failure is legible, and they can be
-- dropped once no such world remains.
local RETIRED = {
	turf = "regolith", dirt = "fines", stone = "lithic", sand = "drift",
	trunk = "spire", leaves = "bloom",
	water_source = "melt_source", water_flowing = "melt_flowing",
}
for old, new in pairs(RETIRED) do
	core.register_alias("h11_world:" .. old, "h11_world:" .. new)
end

core.log("action", ("[h11_world] registered %d nodes"):format(#NODES))

-- Exported for v1's rules table, which is the first thing that will actually read
-- it. Nothing reads it today: mapgen.lua names the ids it needs as string
-- literals rather than looking them up here, so renaming a row means grepping the
-- mod for the literal and not merely checking this table's declared consumers.
-- The only global this mod defines.
--
-- Assigned, not read-then-assigned. `h11_world = h11_world or {}` reads a global
-- that does not exist yet, and Luanti's strict-global check warns about exactly
-- that — a warning in the log costs more than it looks, because the next real one
-- arrives in a file someone has learned to skim.
h11_world = { NODES = NODES }
