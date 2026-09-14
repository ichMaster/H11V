--- Turning the view with the shoulder buttons.
--
-- The PocketTerm has no mouse, so looking around is a finger drag — which is the
-- same gesture as aiming before a tap, and the two fight each other. Shoulder
-- buttons for yaw is the scheme handhelds settled on decades ago.
--
-- Luanti has no key binding for it. The keymap_* list covers movement, strafing,
-- digging, placing and menus, and the camera belongs entirely to the mouse and
-- the touchscreen: there is no keymap_turn_left. So the rotation has to be done
-- here, and the buttons have to arrive as something a mod can see.
--
-- get_player_control() reports a fixed set — movement, jump, sneak, dig, place,
-- aux1, zoom — so L and R are bound to `zoom` and `aux1` in
-- tools/device/gamepad.conf purely because those two are observable and unused
-- in v0. The binding is a transport, not a meaning; nothing here zooms or
-- sprints.
--
-- Server-side look-setting is mildly unusual and worth knowing: in singleplayer
-- the server and client are the same process, so it is immediate. Were this ever
-- multiplayer, turning would acquire the round trip and want doing client-side.

local TURN_SPEED = tonumber(core.settings:get("h11v_turn_speed")) or 2.2   -- rad/s
local ENABLED = core.settings:get_bool("h11v_button_turn", true)

-- L is carried on the `zoom` control, and the engine zooms when it is held. That
-- is a side effect of the transport, not something anyone asked for.
--
-- Putting `zoom_fov = 72` in the client's config was tried first and did nothing
-- at all, for a reason that took a while to see: zoom_fov is a player OBJECT
-- PROPERTY in the Lua API and not a config key, so the line set nothing
-- (docs/decisions.md, v0.7.1 §Turning on L/R records the measurement). player.lua
-- now sets that property to 0 on join, which is the switch the config line was
-- only pretending to be.
--
-- This pin stays regardless, and is not redundant: it is what holds if anything
-- ever hands the property back, and it needs no cooperation from the client at
-- all. While the button is down the server pins the FOV, and on release hands it
-- back (0 means "whatever the client's own setting is"); the engine's camera
-- tests for a server-sent FOV before it tests for zoom, so the view does not move.
--
-- Pinned as a MULTIPLIER of 1 rather than as a number of degrees. set_fov's
-- second argument means "this value is a multiplier" (lua_api.md, ObjectRef), and
-- the client multiplies its own FOV by it — so 1 is by construction the same
-- number the client would have drawn with no override at all. The old code read
-- the `fov` SETTING once at load and pinned that: the server's idea of the
-- player's field of view, frozen at startup, so a player who changed FOV in the
-- pause menu got a visible jump for the length of every L hold — precisely the
-- artifact this pin exists to suppress, delivered by the pin itself.
--
-- Pinned only while held, and released once, rather than every step — a server
-- that re-sends the same FOV sixty times a second is chattier than it needs to
-- be even when the client is the same process.
local pinned = {}

local function hold_fov(player, name, want)
	if want and not pinned[name] then
		player:set_fov(1, true)
		pinned[name] = true
	elseif not want and pinned[name] then
		player:set_fov(0)
		pinned[name] = nil
	end
end

core.register_on_leaveplayer(function(player)
	pinned[player:get_player_name()] = nil
end)

-- The longest step this turn will ever act on. globalstep's dtime is however long
-- the last server step actually took, and nothing bounds it: one stall — an
-- emerge storm, the SD card, a profile swap — arrives as a single call carrying
-- the whole pause, and at 2.2 rad/s a two-second hitch with L held is about 250
-- degrees of yaw in one frame. The player releases a button and is facing
-- somewhere else entirely, with nothing on screen to explain it.
--
-- 0.1 s is three frames at the 30 fps the device was measured at
-- (docs/decisions.md §The device has ample headroom at 30 fps), so no healthy
-- step is ever clamped. Past that the turn stops keeping up with real time, which
-- is the right way round for a camera to fail.
local MAX_STEP = 0.1

core.register_globalstep(function(dtime)
	if not ENABLED then return end
	-- dtime-scaled so the speed is the same whether the device is drawing 30 fps
	-- or 60, which is the whole reason v0.7 measured both; clamped so that a stall
	-- is not handed over as one enormous step.
	local step = TURN_SPEED * math.min(dtime, MAX_STEP)

	for _, player in ipairs(core.get_connected_players()) do
		local c = player:get_player_control()
		hold_fov(player, player:get_player_name(), c.zoom)

		local turn = 0
		if c.zoom then turn = turn + step end   -- L
		if c.aux1 then turn = turn - step end   -- R
		-- Both held cancels out, which is the right answer and costs nothing.
		if turn ~= 0 then
			player:set_look_horizontal((player:get_look_horizontal() + turn) % (2 * math.pi))
		end
	end
end)
