--- The player layer: the hand, what you start with, where you appear, and the HUD.
--
-- Moves into h11_hud when that mod arrives at v1. It lives here in v0 because
-- there is no second concern to separate it from yet, and a mod boundary drawn
-- before there is anything on the other side of it is just ceremony.

--- The hand.
--
-- Luanti's default hand can barely dig anything: it is deliberately feeble so a
-- game can define its own tools. v0 has no tools, so the hand IS the tool, and it
-- must cover every dig group the NODES table uses — crumbly (soil and sand),
-- cracky (stone and crust), choppy (trunk), snappy (leaves). Miss one and that
-- block type is simply not diggable, with nothing in any log to say why.
core.override_item("", {
	wield_image = "h11_hand.png",
	wield_scale = { x = 1, y = 1, z = 2.5 },
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 0,
		groupcaps = {
			crumbly = { times = { [2] = 1.20, [3] = 0.60 }, uses = 0, maxlevel = 1 },
			cracky  = { times = { [2] = 3.50, [3] = 2.00 }, uses = 0, maxlevel = 1 },
			choppy  = { times = { [2] = 2.00, [3] = 1.40 }, uses = 0, maxlevel = 1 },
			snappy  = { times = { [2] = 0.80, [3] = 0.40 }, uses = 0, maxlevel = 1 },
		},
		damage_groups = { fleshy = 1 },
	},
})

--- What the player starts with.
--
-- A stack of everything placeable. v0 is about walking, digging and placing on a
-- device — asking the player to mine a stack of stone before they can find out
-- whether building feels right on a touchscreen would be measuring the wrong
-- thing. Water is excluded: it is not placeable by hand, and a bucket is a
-- crafting mechanic v0 does not have.
local STARTING_INVENTORY = {
	"h11_world:turf 64",
	"h11_world:dirt 64",
	"h11_world:stone 64",
	"h11_world:sand 32",
	"h11_world:trunk 32",
	"h11_world:leaves 32",
	"h11_world:crust 16",
}

core.register_on_newplayer(function(player)
	local inv = player:get_inventory()
	for _, stack in ipairs(STARTING_INVENTORY) do
		inv:add_item("main", stack)
	end
end)

--- Where the player appears.
--
-- The engine's default spawn can put a player inside the ground: our terrain's
-- surface runs from y=6 to y=25 and the default is not aware of that.
--
-- The obvious fix — scan downward with core.get_node until turf appears — does
-- not work on a fresh world, and fails in the worst way. A new player joins
-- before the map around the origin has been emerged, so every get_node returns
-- "ignore", the scan finds nothing, and the player is silently left wherever the
-- engine put them. The screen is simply black, with nothing in any log to say
-- why. (Found on the device: the hotbar rendered, the world did not.)
--
-- core.get_spawn_level is the right tool: it asks the MAPGEN what the surface
-- height at a column will be, which needs no loaded map and is available the
-- instant a player joins.
local WATER_LEVEL = 6

-- get_spawn_level knows the TERRAIN and nothing about what grows on it, so a
-- column it calls a fine surface may have a tree standing on it — and the player
-- arrives embedded in a trunk, staring at brown. (Seen on the device: the overlay
-- read `pointed: h11_world:trunk` with the whole screen the colour of bark.)
--
-- The map is not loaded at join time, so the trees cannot be looked up; instead
-- the candidates are spread far enough apart that a single 5x5 canopy cannot
-- cover two of them, and the fallback keeps walking outward.
local function spawn_for(x, z)
	local y = core.get_spawn_level(x, z)
	-- nil means the mapgen has no suitable surface there (underwater, or outside
	-- the generated region). Above the water line, or the player arrives swimming.
	if y and y > WATER_LEVEL then
		-- +2 rather than +0.5: clear of a trunk's first node if one is there, and
		-- a short fall onto the ground is unremarkable, while spawning inside a
		-- block is not.
		return { x = x, y = y + 2, z = z }
	end
	return nil
end

local function find_spawn()
	-- Spiral outward from the origin. On a map that is mostly land this succeeds
	-- on the first or second try; the loop exists for the case where it does not.
	for radius = 0, 60, 8 do
		if radius == 0 then
			local pos = spawn_for(0, 0)
			if pos then return pos end
		else
			for _, o in ipairs({
				{ radius, 0 }, { -radius, 0 }, { 0, radius }, { 0, -radius },
				{ radius, radius }, { -radius, -radius }, { radius, -radius }, { -radius, radius },
			}) do
				local pos = spawn_for(o[1], o[2])
				if pos then return pos end
			end
		end
	end
	return nil
end

-- Placing in two steps, because neither step alone is enough.
--
-- get_spawn_level gives a terrain height without needing a loaded map, but knows
-- nothing about what grows on that terrain — so on its own it drops the player
-- inside a tree, which at this tree density is common rather than unlucky.
-- Reading the actual nodes would know about trees, but at join time the map is
-- not loaded and every read returns "ignore".
--
-- So: use the mapgen's answer to pick a candidate, emerge a small area around it,
-- and only then read the nodes and find real air. The player stands still for the
-- fraction of a second that takes, which is invisible, and arrives on grass
-- rather than inside bark.
local function settle(player, candidate)
	local pos = vector.new(candidate)
	local min = vector.new(pos.x - 2, pos.y - 12, pos.z - 2)
	local max = vector.new(pos.x + 2, pos.y + 12, pos.z + 2)

	core.emerge_area(min, max, function(_, _, remaining)
		if remaining ~= 0 then return end
		if not player:is_player() then return end

		-- Walk down to the first solid node, stepping over anything growing, then
		-- stand on top of it.
		for y = max.y, min.y, -1 do
			local here = core.get_node({ x = pos.x, y = y, z = pos.z }).name
			if here ~= "air" and here ~= "ignore" then
				local above = core.get_node({ x = pos.x, y = y + 1, z = pos.z }).name
				local head = core.get_node({ x = pos.x, y = y + 2, z = pos.z }).name
				if above == "air" and head == "air" then
					player:set_pos({ x = pos.x, y = y + 1.5, z = pos.z })
					return
				end
				-- Solid, but something is standing on it (a trunk, a canopy).
				-- Keep descending; the loop will find the ground under the tree,
				-- and if that is also blocked the candidate is simply a bad one.
			end
		end
	end)
end

local function place(player)
	local pos = find_spawn()
	if pos then
		player:set_pos(pos)    -- immediately, so the player is never in the void
		settle(player, pos)    -- then properly, once the map around them exists
		return true
	end
	core.log("warning", "[h11_world] no spawn above water found; leaving the engine's default")
	return false
end

core.register_on_newplayer(place)
core.register_on_respawnplayer(place)

--- Privileges.
--
-- A game that grants none leaves the player with the engine's bare defaults —
-- interact and shout — and everything else silently refuses. That is not a
-- theoretical gap: /time answered "missing privilege: settime" on the device,
-- which is why the day-night cycle could not be checked at all, and the touch
-- menu's own Fly / Fast / Noclip buttons are equally dead without them.
--
-- H11V is single-player on a personal handheld. There is nobody to protect the
-- world from, so the player gets the lot. When v1 makes the world something the
-- H11 algorithm owns rather than the player, this is the line to revisit.
local PRIVS = {
	interact = true, shout = true,
	settime = true,          -- /time, needed to look at the world at night
	fly = true, noclip = true,
	-- `fast` is deliberately NOT granted. The R shoulder button is carried on
	-- aux1 (tools/device/gamepad.conf), and aux1 with the fast privilege makes
	-- the player sprint while turning. A transport key has to be inert.
	give = true, teleport = true, debug = true,
	basic_debug = true, bring = true,
}

-- Privileges that must NOT be held, and are actively taken away.
--
-- Granting alone is not enough: privileges live in the world's auth database, so
-- one that was granted by an earlier version of this file stays granted forever
-- unless something removes it. `fast` was, and the R shoulder button — carried on
-- aux1 — made the player sprint while turning until it was revoked here rather
-- than merely dropped from the list above.
local DENY = { fast = true }

core.register_on_joinplayer(function(player)
	-- Applied on join rather than through default_privs so it holds on the Mac
	-- and the device alike, and on a world created before this landed.
	local name = player:get_player_name()
	local have = core.get_player_privs(name)
	local changed = false
	for priv in pairs(PRIVS) do
		if not have[priv] then have[priv] = true; changed = true end
	end
	for priv in pairs(DENY) do
		if have[priv] then have[priv] = nil; changed = true end
	end
	if changed then core.set_player_privs(name, have) end
end)

--- The HUD: hotbar and crosshair, and nothing else.
--
-- v0 has no damage model, so an empty heart row is noise — and noise costs more
-- on a 3.5-inch panel than it does on a monitor, because there is no spare room
-- to ignore it in.
--
-- Width, not height, is what constrains the hotbar. The bar is one slot tall
-- (~78 px at hud_scaling 1.4, about a sixth of 480), but 8 slots at the engine's
-- 48 px base times 1.4 plus padding span roughly 627 of the 640 available
-- pixels. It fits, barely, and the designed bar is built from 8 identical 64x64
-- cells so a 6-slot crop stays lossless if the device says otherwise.
local HOTBAR_SLOTS = 8

core.register_on_joinplayer(function(player)
	player:hud_set_hotbar_itemcount(HOTBAR_SLOTS)
	player:hud_set_hotbar_image("h11_hotbar.png")
	player:hud_set_hotbar_selected_image("h11_hotbar_selected.png")
	player:hud_set_flags({
		hotbar = true,
		crosshair = true,
		healthbar = false,
		breathbar = false,
		minimap = false,
		wielditem = true,
	})
	-- Creative-flavoured for v0: the point is to walk, dig and place, not to
	-- manage a supply. v1 can take this away when scarcity starts meaning
	-- something.
	player:set_properties({ hp_max = 20 })
end)

core.log("action", "[h11_world] player layer: hand, inventory, spawn, HUD")
