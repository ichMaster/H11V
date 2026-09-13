--- Test-only world mod: emerge an area, scan it, report one line, shut down.
--
-- This lives under tools/ and is enabled as a world mod by tools/test_worldgen.sh.
-- It is NEVER shipped inside games/h11v: the game contains no test code, so a
-- player can never be running the harness by accident and the harness can never
-- be a source of gameplay behaviour.
--
-- Output contract — exactly one line, parsed by the shell script:
--
--   H11V-WORLDGEN status=ok area=128 surface_min=2 surface_max=14 ...
--
-- Keys are only ever added, never renamed, because the script greps for them by
-- name and an older script must keep working against a newer probe.

local AREA = tonumber(core.settings:get("h11v_probe_area")) or 128

-- Every STEPth column on both axes, so one column in STEP^2 is looked at. Named
-- rather than written as a bare 4 in the loop below, because the scale-up from a
-- sample to a map-wide figure depends on it, and a literal in one place and a
-- constant in another is how the two quietly stop agreeing.
local STEP = 4
local HALF = math.floor(AREA / 2)
local Y_MIN = -32
local Y_MAX = 96

local pmin = { x = -HALF, y = Y_MIN, z = -HALF }
local pmax = { x = HALF - 1, y = Y_MAX, z = HALF - 1 }

local function report(fields)
	local parts = {}
	for _, key in ipairs(fields.order) do
		parts[#parts + 1] = ("%s=%s"):format(key, tostring(fields[key]))
	end
	-- Both streams: stdout is what the script parses, the log is what a human
	-- reads when the script says the run failed.
	print("H11V-WORLDGEN " .. table.concat(parts, " "))
	core.log("action", "H11V-WORLDGEN " .. table.concat(parts, " "))
end

-- Nodes that sit ON the ground rather than being it. Walking down from the sky
-- and stopping at the first solid node finds a tree canopy, not the ground, and
-- then reports the world as 22% leaves — which says nothing about the terrain the
-- DoD is asking about. So the ground scan steps through them, and trees are
-- counted separately, by their trunks.
--
-- The definition matters more than it looks: `surface_top` means THE GROUND, and
-- a later change that lets a canopy back into that number would silently alter
-- what every assertion in the gate is asserting.
local ABOVE_GROUND = {
	["h11_world:bloom"] = true,
	["h11_world:spire"] = true,
}

--- Walk down from the sky to the first ground node, stepping past anything
--- growing on it. Returns the ground y and id, plus whether a trunk was passed.
local function surface_at(area, data, names, x, z)
	local had_trunk = false
	for y = Y_MAX, Y_MIN, -1 do
		local vi = area:index(x, y, z)
		local id = data[vi]
		if id ~= core.CONTENT_AIR and id ~= core.CONTENT_IGNORE then
			local name = names[id]
			if name == "h11_world:spire" then had_trunk = true end
			if not (name and ABOVE_GROUND[name]) then
				return y, id, had_trunk
			end
		end
	end
	return nil, nil, had_trunk
end

local function scan()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(pmin, pmax)
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()

	local names = {}
	for id, def in pairs(core.registered_nodes) do
		names[core.get_content_id(id)] = def.name
	end

	local counts = {}
	local surface_min, surface_max
	local columns, sampled, trunk_columns = 0, 0, 0

	-- Sample every 4th column: 32x32 = 1024 probes over a 128x128 area is ample
	-- for an elevation range and a surface histogram, and keeps the gate fast
	-- enough that nobody is tempted to skip it.
	for x = pmin.x, pmax.x, STEP do
		for z = pmin.z, pmax.z, STEP do
			columns = columns + 1
			local y, id, had_trunk = surface_at(area, data, names, x, z)
			if had_trunk then trunk_columns = trunk_columns + 1 end
			if y then
				sampled = sampled + 1
				local name = names[id] or ("id:" .. tostring(id))
				counts[name] = (counts[name] or 0) + 1
				if not surface_min or y < surface_min then surface_min = y end
				if not surface_max or y > surface_max then surface_max = y end
			end
		end
	end

	local top_name, top_count = "none", 0
	for name, n in pairs(counts) do
		if n > top_count then top_name, top_count = name, n end
	end

	return {
		order = { "status", "area", "columns", "sampled", "surface_min", "surface_max",
			"elevation_range", "surface_top", "surface_top_pct", "water", "trees",
			"growths" },
		status = sampled > 0 and "ok" or "empty",
		area = AREA,
		columns = columns,
		sampled = sampled,
		surface_min = surface_min or "nil",
		surface_max = surface_max or "nil",
		elevation_range = (surface_min and surface_max) and (surface_max - surface_min) or -1,
		surface_top = top_name,
		surface_top_pct = sampled > 0 and math.floor(100 * top_count / sampled) or 0,
		-- water: sampled columns whose GROUND is a water source — i.e. how much of
		-- the map is under a lake or the sea, not how many water blocks exist.
		water = counts["h11_world:melt_source"] or 0,
		-- trees: sampled columns containing a spire. NOT a count of growths, and
		-- the difference is a factor of sixteen: the scan samples every 4th column
		-- on both axes, so it sees one column in sixteen and each growth stands in
		-- exactly one of them.
		trees = trunk_columns,
		-- growths: the estimate that means what the v0.3 DoD says — "at least 20
		-- trees in a 128x128 area". A growth stands in exactly one column and one
		-- column in STEP^2 is sampled, so scaling the sample back up is the whole
		-- of it. An estimate, not a census: a growth in an unsampled column is
		-- invisible here, which is fine for a threshold and would not be for a
		-- number anyone quoted.
		--
		-- This exists because the gate spent v0 asserting `trees >= 20` while
		-- believing it was checking the DoD. It was not: at the shipped density
		-- that threshold demanded about 320 growths on the map, sixteen times what
		-- was written down. Nobody noticed while the number was comfortably
		-- exceeded — it surfaced only when the colony retheme made the crowns
		-- magenta, the density had to drop to a third for the world to be legible
		-- at all, and a gate that should have passed easily went red.
		growths = trunk_columns * STEP * STEP,
	}
end

core.after(0, function()
	-- Emerging is asynchronous. Sampling before it completes reads CONTENT_IGNORE
	-- and produces a confident, wrong answer — a flaky gate, which is worse than
	-- no gate. So wait for the callback to account for every block.
	core.emerge_area(pmin, pmax, function(_, _, calls_remaining)
		if calls_remaining ~= 0 then return end
		local ok, result = pcall(scan)
		if not ok then
			print("H11V-WORLDGEN status=error message=" .. tostring(result):gsub("%s+", "_"))
			core.log("error", "H11V-WORLDGEN scan failed: " .. tostring(result))
		else
			report(result)
		end
		core.request_shutdown()
	end)
end)

core.log("action", ("[worldgen_probe] emerging %dx%d, y %d..%d"):format(AREA, AREA, Y_MIN, Y_MAX))
