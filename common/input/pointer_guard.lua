-- Ignore mouse events generated from an already handled touch.
local M = {}

local actions = require("common.input.actions")

function M.new()
	return { synthetic_block_until = 0 }
end

function M.is_blocked(guard, action_id, now)
	if action_id == actions.touch_multi then
		guard.synthetic_block_until = now + 0.45
	elseif action_id == actions.touch then
		return now <= guard.synthetic_block_until
	end
	return false
end

return M
