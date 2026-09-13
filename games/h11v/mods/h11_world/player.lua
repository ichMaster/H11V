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
-- The engine's static spawn can drop a player into the sea or inside a tree, and
-- on a 128x128 map with lakes that is not a rare accident. So: look for turf,
-- above the water line, with air above it, spiralling out from the origin until
-- one is found.
local WATER_LEVEL = 6

local function is_good_spawn(pos)
	local ground = core.get_node(pos).name
	if ground ~= "h11_world:turf" then return false end
	local above = core.get_node({ x = pos.x, y = pos.y + 1, z = pos.z }).name
	local head = core.get_node({ x = pos.x, y = pos.y + 2, z = pos.z }).name
	return above == "air" and head == "air"
end

local function find_spawn()
	for radius = 0, 60, 4 do
		for _, offset in ipairs({
			{ x = radius, z = 0 }, { x = -radius, z = 0 },
			{ x = 0, z = radius }, { x = 0, z = -radius },
			{ x = radius, z = radius }, { x = -radius, z = -radius },
		}) do
			local x, z = offset.x, offset.z
			-- Search downward from well above the terrain: the first turf with two
			-- air blocks over it is a place a player fits.
			for y = 40, WATER_LEVEL, -1 do
				local pos = { x = x, y = y, z = z }
				if is_good_spawn(pos) then
					return { x = x, y = y + 1, z = z }
				end
			end
		end
	end
	return nil
end

core.register_on_respawnplayer(function(player)
	local pos = find_spawn()
	if pos then
		player:set_pos(pos)
		return true    -- we handled it; the engine must not also move the player
	end
	return false
end)

core.register_on_newplayer(function(player)
	local pos = find_spawn()
	if pos then player:set_pos(pos) end
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
