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
	-- Shore sand: the band either side of the water line, which is what makes a
	-- lake read as a lake rather than as a hole with water in it.
	node_dungeon = "h11_world:stone",
	y_max = 200,
	y_min = -100,
	heat_point = 50,
	humidity_point = 50,
})

--- Mapgen parameters.
--
-- Set as defaults, not forced: a world that already exists keeps the parameters
-- it was created with, and overriding them would silently change an existing
-- map's terrain between runs. v0.7 measures a fixed seed, so stability matters
-- more than any particular value here.
core.set_mapgen_setting("mg_name", "v7", false)
core.set_mapgen_setting("water_level", "1", false)

-- No caves, no dungeons, no floatlands in v0. Every one of them is geometry the
-- device has to render and v0 exists to find out what the device can do with the
-- simple case first. They are cheap to switch on later, and expensive to have
-- confounded a measurement.
core.set_mapgen_setting("mg_flags", "nocaves,nodungeons,light,decorations,biomes", false)

--- Terrain shape: a pocket island rather than a continent.
--
-- v7's base terrain is a broad, slow noise meant for an endless world. On a
-- 128x128 map that reads as a featureless tilt. Shortening the spread and
-- lifting the octave count gives a horizon with hills inside the area the player
-- can actually walk — which is what the v0.2 DoD asks for when it demands an
-- elevation range of at least 8 blocks.
core.set_mapgen_setting_noiseparams("mgv7_np_terrain_base", {
	offset = 6,
	scale = 12,
	spread = { x = 120, y = 120, z = 120 },
	seed = 82341,
	octaves = 4,
	persistence = 0.6,
	lacunarity = 2.0,
}, false)

core.set_mapgen_setting_noiseparams("mgv7_np_terrain_alt", {
	offset = 4,
	scale = 10,
	spread = { x = 100, y = 100, z = 100 },
	seed = 5934,
	octaves = 4,
	persistence = 0.6,
	lacunarity = 2.0,
}, false)

core.log("action", "[h11_world] mapgen wired: v7, one technical biome, 3 structural aliases")
