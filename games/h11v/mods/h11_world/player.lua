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

local function spawn_for(x, z)
	local y = core.get_spawn_level(x, z)
	-- nil means the mapgen has no suitable surface there (underwater, or outside
	-- the generated region). Above the water line, or the player arrives swimming.
	if y and y > WATER_LEVEL then
		return { x = x, y = y + 0.5, z = z }
	end
	return nil
end

local function find_spawn()
	-- Spiral outward from the origin. On a map that is mostly land this succeeds
	-- on the first or second try; the loop exists for the case where it does not.
	for radius = 0, 60, 6 do
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

local function place(player)
	local pos = find_spawn()
	if pos then
		player:set_pos(pos)
		return true
	end
	core.log("warning", "[h11_world] no spawn above water found; leaving the engine's default")
	return false
end

core.register_on_newplayer(place)
core.register_on_respawnplayer(place)

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
