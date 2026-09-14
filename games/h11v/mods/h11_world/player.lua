--- The player layer: the hand, what you start with, where you appear, and the HUD.
--
-- Moves into h11_hud when that mod arrives at v1. It lives here in v0 because
-- there is no second concern to separate it from yet, and a mod boundary drawn
-- before there is anything on the other side of it is just ceremony.

--- The hand, which is a scanner.
--
-- Luanti's default hand can barely dig anything: it is deliberately feeble so a
-- game can define its own tools. v0 has no tools, so this IS the tool, and it
-- must cover every dig group the NODES table uses — crumbly (regolith, fines,
-- drift), cracky (lithic, crust, and all four colony blocks), choppy (spire),
-- snappy (bloom). Miss one and that block type is simply not diggable, with
-- nothing in any log to say why.
core.override_item("", {
	-- Not a bare hand: the scanner the player is holding in both canon references
	-- (specification/ART-COLONY.md §6.3). It is still the engine's empty item, so
	-- it still digs and places; only what you see changed.
	wield_image = "h11_scanner.png",
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
-- Exactly eight stacks, because the hotbar is exactly eight slots — a ninth would
-- be invisible on the device and would look like an inventory bug.
--
-- The colony's four blocks come FIRST, in slots 1-4. They are what the player
-- builds with, they are the half of the catalogue that makes this world a landing
-- site rather than a biome, and the first four slots are the ones reachable
-- without cycling. Planet materials fill 5-8; drift, bloom and fines are dug
-- rather than given, since nothing about them needs testing on day one.
--
-- Meltwater is excluded: it is not placeable by hand, and a bucket is a crafting
-- mechanic v0 does not have.
local STARTING_INVENTORY = {
	"h11_world:hull 64",
	"h11_world:prefab 64",
	"h11_world:beacon 16",
	"h11_world:crate 32",
	"h11_world:regolith 64",
	"h11_world:lithic 64",
	"h11_world:spire 32",
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
--
-- The sea's datum is read back from the mapgen rather than repeated here. This
-- was a second copy of the 6 that mapgen.lua installs, and a spawn rule that
-- carries its own idea of the water line goes on being plausible for exactly as
-- long as nobody moves the sea. get_mapgen_setting returns the ACTIVE value as a
-- string (lua_api.md), and init.lua loads mapgen before this file, so by now the
-- value is the one the world will be generated with. The literal survives only as
-- the fallback for a mapgen that somehow has no water level at all.
local WATER_LEVEL = tonumber(core.get_mapgen_setting("water_level")) or 6

-- get_spawn_level knows the TERRAIN and nothing about what grows on it, so a
-- column it calls a fine surface may have a growth standing on it — and the
-- player arrives embedded in a trunk, staring at brown. (Seen on the device: the
-- overlay read `pointed: h11_world:trunk` with the whole screen the colour of
-- bark — that block is called `spire` now, but the failure it describes is
-- unchanged.)
--
-- The map is not loaded at join time, so the growths cannot be looked up, and
-- nothing in this function can avoid one: the spiral's 8-node spacing means a
-- single 5x5 crown cannot cover two candidates, which is not the same as missing
-- the one it does cover — measured, eighteen per cent of candidates have a growth
-- over them. settle(), below, is what actually deals with them.
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
-- fraction of a second that takes, which is invisible, and arrives on the ground
-- under the growth wherever the column leaves room to stand there.

-- A GROWTH IS NOT GROUND, and until this was written the descent could not tell
-- the difference. It stopped at the first non-air node with two air above it,
-- and under a spire that node is the top of the bloom crown — the schematic puts
-- nothing above the cap, so the cap has its two clear nodes and passes the test
-- on the first try. The "keep descending" branch could only ever fire for a gap
-- inside the crown, never for its top.
--
-- Measured headless on the real map at the shipped density, seed 20260913, over
-- the 6228 spawn candidates in the 81x81 columns around the origin: 1122 of them
-- — eighteen per cent — stood the player on a crown, usually five nodes above the
-- regolith they were meant to be on. With the descent below, 897 of those land on
-- the ground instead and the other 225 keep a crown top for the reason the
-- fallback describes.
--
-- Group membership rather than node ids: `tree` and `leaves` are what the
-- catalogue marks the stalk and the crown with (nodes.lua), and v1's biomes will
-- add growths this file has never heard of.
local function is_growth(name)
	return core.get_item_group(name, "tree") > 0 or core.get_item_group(name, "leaves") > 0
end

local function settle(player, candidate)
	-- By NAME, not by the ObjectRef. The emerge takes a moment, and a player who
	-- leaves and rejoins inside that moment gets a new ObjectRef: the captured one
	-- is then invalid, is_player() correctly refused it, and nothing ever settled
	-- the player who is now standing at the unsettled candidate — the one case
	-- this whole function exists to prevent. A name outlives the reconnection, and
	-- nil simply means nobody holds it any more.
	local name = player:get_player_name()
	local pos = vector.new(candidate)
	local min = vector.new(pos.x - 2, pos.y - 12, pos.z - 2)
	local max = vector.new(pos.x + 2, pos.y + 12, pos.z + 2)

	core.emerge_area(min, max, function(_, _, remaining)
		if remaining ~= 0 then return end
		local subject = core.get_player_by_name(name)
		if not subject then return end

		-- Walk down to the first ground node with room to stand, passing through
		-- anything growing on the way, and keep the best growth-top seen as the
		-- fallback.
		--
		-- The fallback is for a column where the growth sits ON the ground rather
		-- than above it: the stalk's own column, and — more often, because the
		-- terrain is not flat — a crown node resting directly on a neighbouring
		-- rise. There is then no height in this column with both ground and
		-- headroom, so the descent alone would find nothing and leave the player
		-- at the unsettled candidate, INSIDE the growth: the "staring at brown"
		-- failure this whole two-step dance was written for, and a worse outcome
		-- than the crown-standing it replaced. Measured, that is 225 of 6228
		-- candidates — 3.6 per cent, a fifth of all growth-covered columns — so it
		-- is not a corner. Standing on the crown is what the old code did
		-- everywhere; keeping it only where nothing better exists costs one local.
		local on_growth

		for y = max.y, min.y, -1 do
			local here = core.get_node({ x = pos.x, y = y, z = pos.z }).name
			if here ~= "air" and here ~= "ignore" then
				local above = core.get_node({ x = pos.x, y = y + 1, z = pos.z }).name
				local head = core.get_node({ x = pos.x, y = y + 2, z = pos.z }).name
				local room = above == "air" and head == "air"
				if room and not is_growth(here) then
					subject:set_pos({ x = pos.x, y = y + 1.5, z = pos.z })
					return
				end
				if room and not on_growth then on_growth = y + 1.5 end
			end
		end

		-- No ground with headroom anywhere in the 25-node window: a crown top if
		-- one was passed, and otherwise the candidate find_spawn chose, which is
		-- simply a bad one.
		if on_growth then
			subject:set_pos({ x = pos.x, y = on_growth, z = pos.z })
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
end)

-- `set_properties({ hp_max = 20 })` stood here and is gone: 20 is already the
-- engine's default for players on both versions (lua_api.md: "For players, this
-- defaults to core.PLAYER_MAX_HP_DEFAULT (20)"), so it set nothing. Its comment
-- claimed the game was "creative-flavoured", which read as "the inventory does
-- not deplete" — it does, and place sixty-four hull plates and you have none.

--- The camera: zoom off, and that is an input fix rather than a taste.
--
-- creative_mode gives every player the engine's default zoom_fov of 15 degrees
-- (lua_api.md, Object properties: "Defaults to 15 in creative mode, 0 in survival
-- mode"; "zoom_fov = 0 disables zooming for the player"). Nothing in this game
-- wants a telescope, and on this device the property is actively harmful: L is
-- carried on the `zoom` control as a transport for turning (turn.lua,
-- tools/device/gamepad.conf), so every turn to the left also asked the client to
-- zoom. That is the flash recorded in docs/decisions.md §Turning on L/R — the
-- client applies the zoom FOV the instant the key goes down and the server's
-- set_fov undoes it a step later — and zoom is not free even when it is undone:
-- the API's own note is that it "loads and/or generates world beyond the
-- server's maximum send and generate distances", which is map work on a Pi whose
-- frame budget v0.7 measured to the millisecond.
--
-- With the property at 0 the client has no zoom FOV to apply, so there is
-- nothing to predict and nothing to correct. Not yet re-measured on the panel —
-- the device was in use when this landed — so turn.lua's FOV pin stays as the
-- belt to this pair of braces, and is the thing that still holds if some later
-- code path (a bot camera, a v1 tool) hands the zoom back.
--
-- What it does NOT do is remove the touch overlay's magnifier button or the
-- `Aux1` label sitting over the right third of the playfield: 5.10 draws both
-- unconditionally, whatever the player can actually do, and the taps they eat
-- still reach turn.lua as a turn. That residue is recorded where the client
-- settings live, in tools/device/gamepad.conf.
core.register_on_joinplayer(function(player)
	player:set_properties({ zoom_fov = 0 })
end)

-- The water level is in the line because it is DERIVED now rather than written
-- here: this is where a run that spawns people in the sea would show that the
-- mapgen setting never reached this file.
core.log("action", ("[h11_world] player layer: hand, inventory, spawn above y=%d, HUD, zoom off")
	:format(WATER_LEVEL))
