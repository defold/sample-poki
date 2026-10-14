-- Selects music for each game screen and loads the deferred mothership track.
local M = {}

local client = require("common.audio.client")

M.BATTLE = "music"
M.CALM = "mothership_music"

---Choose the music track for the app's current screen and state.
---@param app table
---@param transition table|nil
---@return string|false|nil track
function M.track_for(app, transition)
	if transition and transition.destination == "gameplay" then
		return nil
	end
	if not transition and app.phase == "PLAYING" then
		return M.BATTLE
	end
	if app.phase == "RESULT" or app.phase == "MOTHERSHIP" then
		return M.CALM
	end
	return false
end

---Choose and apply music for the app's current state.
---@param self table
function M.sync_music(self)
	local track = M.track_for(self.app, self.active_transition)
	if track == false then
		return
	end
	if track == M.CALM then
		-- Pending music starts when the deferred audio collection is ready.
		self.deferred_assets:request("audio")
		if self.audio:has_event(M.CALM) and self.deferred_assets:is_ready("audio") then
			client.set_music(track)
		else
			client.set_music(nil)
		end
		return
	end
	client.set_music(track)
end

---Bind a music resource once the deferred audio pack has loaded.
---@param self table
---@param message table
function M.on_deferred_audio_ready(self, message)
	self.audio:bind_event(M.CALM, {
		url = msg.url(message.url),
		gain = 0.36,
	})
	M.sync_music(self)
end

return M
