-- Shared analog-to-digital input handling.
local M = {}

local PRESS_THRESHOLD = 0.55
local RELEASE_THRESHOLD = 0.25

function M.strength(value, deadzone)
	local strength = math.abs(value or 0)
	if strength <= deadzone then return 0 end
	return math.min((strength - deadzone) / (1 - deadzone), 1)
end

function M.new()
	return { held_actions = {} }
end

function M.is_press(action)
	return action ~= nil and (action.pressed == true
		or (action.gamepad ~= nil and math.abs(action.value or 0) >= PRESS_THRESHOLD))
end

function M.update_axis_edges(tracker, action_id, action)
	local held = tracker.held_actions[action_id] == true
	local value = math.abs(action.value or 0)
	local pressed = action.pressed
		or (not action.released and not held and value >= PRESS_THRESHOLD)
	local released = not pressed and held and (action.released
		or (action.value ~= nil and value < RELEASE_THRESHOLD))
	if pressed then
		tracker.held_actions[action_id] = true
	elseif released then
		tracker.held_actions[action_id] = nil
	end
	if pressed then return "pressed" end
	if released then return "released" end
	return nil
end

function M.update_digital_action(tracker, action_id, action, out)
	local edge = M.update_axis_edges(tracker, action_id, action)
	out.pressed, out.released = edge == "pressed", edge == "released"
	out.value, out.gamepad = action.value, action.gamepad
	return out
end

return M
