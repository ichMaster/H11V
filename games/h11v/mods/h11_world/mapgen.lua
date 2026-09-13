--- Point the stock generator at our blocks.
--
-- This is where a Luanti game stops being a mod collection and becomes a world.
-- It is also the second of the three engine strictnesses that fail silently
-- rather than loudly, so the reasoning is written down rather than implied.
--
-- ALIASES ARE NOT THE SURFACE. Under v7 — and every mapgen except the legacy v6
-- — the engine reads exactly three aliases:
--
--     mapgen_stone  mapgen_water_source  mapgen_river_water_source
--
-- and takes everything else from BIOME DEFINITIONS. The v6 aliases that look
-- like they should work here —
--
--     mapgen_dirt  mapgen_dirt_with_grass  mapgen_sand
--
-- — are read by v6 alone. Register those instead and v7 generates a world of
-- bare stone and water, with no error to explain it: the aliases are accepted,
-- they are simply never consulted. That is why they are absent below, and why
-- this comment is here instead of a line of code.
--
-- Verified empirically in v0.1: an empty game logs "Mapgen alias 'mapgen_stone'
-- is invalid!" for precisely these three and no others.

-- The structural nodes, which the generator places directly.
core.register_alias("mapgen_stone", "h11_world:stone")
core.register_alias("mapgen_water_source", "h11_world:water_source")
-- River water has no separate node in v0: the pocket world has lakes and a sea,
-- not rivers. Pointing it at the same source keeps the engine quiet and the
-- world consistent; v1 may give rivers their own node when biomes arrive.
core.register_alias("mapgen_river_water_source", "h11_world:water_source")

-- Mandatory for any game, even one with no caves or dungeons: the engine asks
-- for them during decoration and dungeon placement whether or not it uses them.
core.register_alias("mapgen_lava_source", "h11_world:stone")
core.register_alias("mapgen_cobble", "h11_world:stone")

--- The surface.
--
-- ONE biome, covering the whole heat/humidity range. This is a technical
-- registration, not a gameplay biome: without at least one, v7 has nothing to
-- put on top of the stone and the world generates as a grey slab. The three real
-- H11V biomes arrive in v1.1, and they replace this rather than extend it.
core.register_biome({
	name = "h11v:island",
	node_top = "h11_world:turf",
	depth_top = 1,
	node_filler = "h11_world:dirt",
	depth_filler = 2,
	node_riverbed = "h11_world:sand",
	depth_riverbed = 2,
	y_max = 200,
	y_min = -100,
	heat_point = 50,
	humidity_point = 50,
})

--- Mapgen parameters.
--
-- OVERRIDE, not default, and the difference is the whole reason this comment
-- exists. set_mapgen_setting's third argument looks like "don't clobber a world
-- that already has a value", but the engine writes its OWN defaults into
-- map_meta.txt when the world is created, which happens before mods load. So
-- `false` does not mean "unless it exists" — it means "never", including for a
-- brand new world. v0.2 shipped these tuned and inert: the terrain it measured
-- was stock v7, not ours.
--
-- The cost is real and accepted: an existing map re-tuned on next load grows a
-- seam where old and new chunks meet. In v0 no world outlives a test run, and
-- v0.7 measures a fixed seed on a fresh world, so a setting that applies is
-- worth more than one that cannot.
core.set_mapgen_setting("mg_name", "v7", true)
-- Water level above the terrain's mean, not below it. v0.2 put the base at 6 and
-- the water at 1, so the island generated entirely above the water line: the map
-- had lakes in principle and none in fact, and the gate honestly reported
-- water=0. The sea is the datum here, and the terrain rises out of it.
core.set_mapgen_setting("water_level", "6", true)

-- No caves, no dungeons, no floatlands in v0. Every one of them is geometry the
-- device has to render and v0 exists to find out what the device can do with the
-- simple case first. They are cheap to switch on later, and expensive to have
-- confounded a measurement.
core.set_mapgen_setting("mg_flags", "nocaves,nodungeons,light,decorations,biomes", true)

--- Terrain shape: a pocket island rather than a continent.
--
-- v7 does not take its height from one noise. It computes
--
--     if alt > base then height = alt
--     else height = base * height_select + alt * (1 - height_select)
--
-- so tuning terrain_base alone moves almost nothing: the blend and the
-- short-circuit swamp it. That is why v0.2's numbers refused to budge no matter
-- what base was set to.
--
-- So the blend is made deterministic and base is left as the only dial:
-- height_select is pinned to a constant 1, and terrain_alt is kept in a narrow
-- band that can never exceed base. Height is then simply terrain_base, which is
-- what a 128x128 pocket world wants — a designer needs one number to turn, not
-- three interacting ones tuned for an endless continent.
core.set_mapgen_setting_noiseparams("mgv7_np_height_select", {
	offset = 1, scale = 0,
	spread = { x = 500, y = 500, z = 500 },
	seed = 4213, octaves = 1, persistence = 0.5, lacunarity = 2.0,
}, true)

-- Never dominant: a gentle undulation that rides under the base rather than
-- replacing it via the short-circuit above.
core.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt", {
	offset = 0, scale = 2,
	spread = { x = 100, y = 100, z = 100 },
	seed = 5934, octaves = 3, persistence = 0.6, lacunarity = 2.0,
}, true)

-- The one dial. Water level is 6, so an offset of 15 with a scale of 12 puts the
-- land mostly above the sea and drops the lowest hollows into it — bays and
-- lakes rather than either a lawn or a swamp. Spread 120 rather than v7's stock
-- 600 puts whole hills inside the area a player can walk.
core.set_mapgen_setting_noiseparams("mgv7_np_terrain_base", {
	offset = 12,
	scale = 12,
	spread = { x = 120, y = 120, z = 120 },
	seed = 82341,
	octaves = 4,
	persistence = 0.6,
	lacunarity = 2.0,
}, true)

--- Trees.
--
-- A schematic handed to the engine, not an ABM and not an on_generated loop:
-- decorations are placed once, with the chunk, by the mapgen thread. Nothing
-- about a tree costs anything per tick afterwards, which is the whole point on a
-- device whose frame budget v0.7 is about to measure.
--
-- No leafdecay either. That is a per-tick ABM over every leaf in view, and v0
-- exists to learn what the device does with the simple case first.

local _ = "air"      -- readability in the layer tables below
local T = "h11_world:trunk"
local L = "h11_world:leaves"

-- Probabilities: 255 is always, 0 is never. The corners of the canopy are given
-- middling odds so that no two trees are quite the same shape — a forest of
-- identical stamps reads as wallpaper.
local SOMETIMES = 160

local tree = {
	size = { x = 5, y = 7, z = 5 },
	yslice_prob = {},
	data = {},
}

-- ORDER MATTERS AND IS NOT THE OBVIOUS ONE. A schematic's `data` is a flat array
-- the engine reads as [z [y [x]]] — z outermost, x innermost. Building it
-- layer-by-layer (y outermost), which is how a human thinks about a tree, writes
-- every node to the wrong coordinate: the result generates without error and
-- looks like trunks floating beside their own canopies. Found by screenshotting
-- the device, because nothing in a log or a block count can see it.
local layers = {
	-- y = 0..2: the trunk alone
	{ pattern = "trunk" }, { pattern = "trunk" }, { pattern = "trunk" },
	-- y = 3..4: the wide canopy, trunk still running through it
	{ pattern = "wide" }, { pattern = "wide" },
	-- y = 5: narrower
	{ pattern = "narrow" },
	-- y = 6: the cap
	{ pattern = "cap" },
}

for z = 1, 5 do
	for _y, layer in ipairs(layers) do
		for x = 1, 5 do
			local centre = (x == 3 and z == 3)
			local inner = (math.abs(x - 3) <= 1 and math.abs(z - 3) <= 1)
			local corner = (math.abs(x - 3) == 2 and math.abs(z - 3) == 2)
			local node, prob = _, 255

			if layer.pattern == "trunk" then
				node = centre and T or _
			elseif layer.pattern == "wide" then
				if centre then node = T
				elseif corner then node, prob = L, SOMETIMES
				else node = L end
			elseif layer.pattern == "narrow" then
				if inner then node = L
				elseif not corner then node, prob = L, SOMETIMES end
			elseif layer.pattern == "cap" then
				if centre then node = L
				elseif inner and not corner then node, prob = L, SOMETIMES end
			end

			tree.data[#tree.data + 1] = { name = node, prob = prob, param2 = 0 }
		end
	end
end

core.register_decoration({
	name = "h11_world:tree",
	deco_type = "schematic",
	place_on = { "h11_world:turf" },
	sidelen = 16,
	-- Tuned for a wooded island rather than a forest or a lawn: dense enough that
	-- the 128x128 map clears the DoD's 20 trees with room to spare, sparse enough
	-- that the player can see across it.
	fill_ratio = 0.032,
	y_max = 200,
	y_min = 7,          -- above the water line: no trees standing in the sea
	schematic = tree,
	flags = "place_center_x, place_center_z",
	rotation = "random",
})

core.log("action", "[h11_world] mapgen wired: v7, one technical biome, 3 structural aliases")
