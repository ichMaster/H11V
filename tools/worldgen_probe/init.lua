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

--- Walk down from the sky to the first non-air node: that is the surface.
local function surface_at(vm, area, data, x, z)
	for y = Y_MAX, Y_MIN, -1 do
		local vi = area:index(x, y, z)
		local id = data[vi]
		if id ~= core.CONTENT_AIR and id ~= core.CONTENT_IGNORE then
			return y, id
		end
	end
	return nil, nil
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
	local columns, sampled = 0, 0

	-- Sample every 4th column: 32x32 = 1024 probes over a 128x128 area is ample
	-- for an elevation range and a surface histogram, and keeps the gate fast
	-- enough that nobody is tempted to skip it.
	for x = pmin.x, pmax.x, 4 do
		for z = pmin.z, pmax.z, 4 do
			columns = columns + 1
			local y, id = surface_at(vm, area, data, x, z)
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
			"elevation_range", "surface_top", "surface_top_pct", "water", "trees" },
		status = sampled > 0 and "ok" or "empty",
		area = AREA,
		columns = columns,
		sampled = sampled,
		surface_min = surface_min or "nil",
		surface_max = surface_max or "nil",
		elevation_range = (surface_min and surface_max) and (surface_max - surface_min) or -1,
		surface_top = top_name,
		surface_top_pct = sampled > 0 and math.floor(100 * top_count / sampled) or 0,
		-- Placeholders until v0.3 registers water's flowing partner and the trees.
		water = counts["h11_world:water_source"] or 0,
		trees = counts["h11_world:trunk"] or 0,
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
