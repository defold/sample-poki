-- Routes navigation actions between shop screens and focus targets.
local M = {}

local actions = require("common.input.actions")
local axis = require("common.input.axis")

local PRESS = 0.65
local RELEASE = 0.25
local SILENCE_SECONDS = 0.18
local REPEAT_DELAY = 0.65
local REPEAT_INTERVAL = 0.32

---Return a row step for up/down input, with repeat timing for held controls.
---@param tracker table
---@param action_id hash
---@param action table
---@param now number
---@return integer
function M.vertical_step(tracker, action_id, action, now)
	if action_id ~= actions.menu_up and action_id ~= actions.menu_down then return 0 end
	if action.gamepad == nil then
		return (axis.update_axis_edges(tracker, action_id, action) == "pressed")
			and (action_id == actions.menu_up and -1 or 1) or 0
	end

	if tracker.last_vertical_sample and now - tracker.last_vertical_sample > SILENCE_SECONDS then
		tracker.is_vertical_held = false
		tracker.vertical_direction = nil
	end
	tracker.last_vertical_sample = now
	local value = math.abs(action.value or (action.pressed and 1 or 0))
	if value <= RELEASE then
		tracker.is_vertical_held = false
		tracker.vertical_direction = nil
		return 0
	end
	if action.released then return 0 end
	local direction = action_id == actions.menu_up and -1 or 1
	if tracker.is_vertical_held then
		if tracker.vertical_direction ~= direction then return 0 end
		if value < PRESS then
			tracker.vertical_repeat_at = now + REPEAT_DELAY
			return 0
		end
		if not action.pressed and not action.repeated and now >= tracker.vertical_repeat_at then
			tracker.vertical_repeat_at = now + REPEAT_INTERVAL
			return direction
		end
		return 0
	end
	if action.repeated or value < PRESS then return 0 end
	tracker.is_vertical_held = true
	tracker.vertical_direction = direction
	tracker.vertical_repeat_at = now + REPEAT_DELAY
	return direction
end

return M
