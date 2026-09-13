--- Background music.
--
-- One looping track, started per player and stopped when they leave. Not
-- positional: it is scored to the world, not emitted by anything in it.
--
-- Two details that matter more than the six lines of code:
--
-- The handle is kept per player and stopped on leave. Without that, a rejoin
-- starts a second copy over the first, and by the fourth reconnection the game
-- is playing a four-part round of itself. The engine will not clean it up —
-- a looping sound with a lost handle plays until the process exits.
--
-- It is a setting, off-switchable, because background music is the first thing
-- anyone turns off and the last thing a game lets them. Sound volume is already
-- the engine's own control; this is the coarser "not at all".

local MUSIC = "h11_world_music"
local GAIN = tonumber(core.settings:get("h11v_music_gain")) or 0.5
local ENABLED = core.settings:get_bool("h11v_music", true)

local playing = {}

local function start(player)
	if not ENABLED then return end
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
	description = "Turn the background music on or off",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return false, "not in game" end
		if param == "off" then
			if playing[name] then core.sound_stop(playing[name]); playing[name] = nil end
			ENABLED = false
			return true, "Music off."
		end
		ENABLED = true
		start(player)
		return true, "Music on."
	end,
})
