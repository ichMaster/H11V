--- Background music.
--
-- One looping track, started per player and stopped when they leave. Not
-- positional: it is scored to the world, not emitted by anything in it.
--
-- Three details that matter more than the code they sit above:
--
-- The handle is kept per player and stopped on leave. Without that, a rejoin
-- starts a second copy over the first, and by the fourth reconnection the game
-- is playing a four-part round of itself. The engine will not clean it up —
-- a looping sound with a lost handle plays until the process exits.
--
-- It is a setting, off-switchable, because background music is the first thing
-- anyone turns off and the last thing a game lets them. Sound volume is already
-- the engine's own control; this is the coarser "not at all".
--
-- The switch is PER PLAYER, and it used to be neither one thing nor the other:
-- `/music off` flipped a single upvalue shared by everyone but stopped only the
-- caller's handle. On a dev run with two clients against `luanti --server` — the
-- way this game is played on the Mac — one player's "off" silenced every later
-- joiner while the other player's loop went on playing: the command reached
-- exactly the people it was not aimed at and missed the one it was. It also died
-- with the process, so "off" had to be typed again after every restart.
--
-- The choice is kept on the player instead, where the handle already lives. Player
-- metadata is stored in the world's player database (lua_api.md, PlayerMetaRef),
-- so it survives a restart; the h11v_music setting is what a player who has never
-- said anything gets.

local MUSIC = "h11_world_music"
local GAIN = tonumber(core.settings:get("h11v_music_gain")) or 0.5
local DEFAULT_ON = core.settings:get_bool("h11v_music", true)

local playing = {}

-- "" is an unset key, not an answer: a player who has never used the command
-- follows the setting, and only an explicit choice overrides it.
local function wants_music(player)
	local choice = player:get_meta():get_string("h11v_music")
	if choice == "" then return DEFAULT_ON end
	return choice == "on"
end

local function start(player)
	if not wants_music(player) then return end
	local name = player:get_player_name()
	-- Defensive: if a handle survived somehow, drop it before making another.
	if playing[name] then core.sound_stop(playing[name]) end
	playing[name] = core.sound_play(MUSIC, {
		to_player = name,
		gain = GAIN,
		loop = true,
	})
end

core.register_on_joinplayer(function(player)
	-- A beat after joining: the client is still loading media at join time, and a
	-- sound started into that lands unreliably.
	core.after(2.0, function()
		if player:is_player() then start(player) end
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if playing[name] then
		core.sound_stop(playing[name])
		playing[name] = nil
	end
end)

core.register_chatcommand("music", {
	params = "[on | off]",
	description = "Turn your background music on or off",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return false, "not in game" end
		local want = param ~= "off"
		player:get_meta():set_string("h11v_music", want and "on" or "off")
		if want then
			start(player)
			return true, "Music on."
		end
		if playing[name] then core.sound_stop(playing[name]); playing[name] = nil end
		return true, "Music off."
	end,
})
