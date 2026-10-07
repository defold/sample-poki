-- Builds data sent to the mothership and other session screens.
local M = {}

local progress = require("game.modules.profile.progress")

local function is_retry(self)
	local last = self.last_result
	return last ~= nil and last.status ~= nil and last.status ~= "complete"
end

---Choose the mission to retry, or use the latest unlocked mission.
function M.get_next_level(self)
	local last = self.last_result or {}
	return is_retry(self) and (last.level_id or 1) or progress.snapshot().mission
end

---Build the mothership's UI payload from current app and progress state.
---@param self table
---@param extra table|nil
---@return table
function M.build(self, extra)
	local payload = {
		profile = progress.shop_snapshot(),
		input_mode = self.app.input_mode,
		device_category = self.app.device_category,
		next_level = M.get_next_level(self),
		retry = is_retry(self),
		transitioning = self.active_transition ~= nil,
	}
	for key, value in pairs(extra or {}) do
		payload[key] = value
	end
	return payload
end

return M
