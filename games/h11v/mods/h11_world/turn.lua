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
-- Setting zoom_fov equal to fov was tried first and did not stop it, so rather
-- than keep guessing at why, the mod takes the field of view away from the
-- engine: while the button is down the server pins the FOV, and on release hands
-- it back (0 means "whatever the client's own setting is"). Server-set FOV wins
-- over the client's zoom, so the view simply does not move.
--
-- Pinned only while held, and released once, rather than every step — a server
-- that re-sends the same FOV sixty times a second is chattier than it needs to
-- be even when the client is the same process.
local FOV = tonumber(core.settings:get("fov")) or 72
local pinned = {}

local function hold_fov(player, name, want)
	if want and not pinned[name] then
		player:set_fov(FOV)
		pinned[name] = true
	elseif not want and pinned[name] then
		player:set_fov(0)
		pinned[name] = nil
	end
end

core.register_on_leaveplayer(function(player)
	pinned[player:get_player_name()] = nil
end)

core.register_globalstep(function(dtime)
	if not ENABLED then return end
	-- dtime-scaled so the speed is the same whether the device is drawing 30 fps
	-- or 60, which is the whole reason v0.7 measured both.
	local step = TURN_SPEED * dtime

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
