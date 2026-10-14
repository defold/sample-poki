-- Platform-independent input-mode classification and tracking.
local M = {}

M.KEYBOARD, M.MOUSE, M.TOUCH, M.GAMEPAD = "keyboard", "mouse", "touch", "gamepad"

local KEYBOARD_ACTIONS = {
	"move_left", "move_right", "primary_action", "rewarded_action",
	"menu_up", "menu_down", "menu_left", "menu_right",
	"ui_accept", "ui_back", "cancel_action",
}
local POINTER_ACTIONS = { "touch", "mouse_button_1", "pointer" }
local TOUCH_ACTIONS = { "touch_multi" }

local function to_action_id(value)
	return type(value) == "string" and hash(value) or value
end

local function make_action_set(values)
	local result = {}
	for key, value in pairs(values or {}) do
		local action = type(key) == "number" and value or (value and key)
		if action ~= nil then result[to_action_id(action)] = true end
	end
	return result
end

local function absolute(value)
	return math.abs(type(value) == "number" and value or 0)
end

local function moved_far_enough(action, threshold)
	return absolute(action.dx) > threshold or absolute(action.dy) > threshold
end

local function axis_is_meaningful(action, deadzone)
	if absolute(action.value) > deadzone then return true end
	local x = type(action.x) == "number" and action.x or 0
	local y = type(action.y) == "number" and action.y or 0
	return x * x + y * y > deadzone * deadzone
end

local function touch_is_meaningful(action, threshold)
	if type(action.touch) ~= "table" then return false end
	for _, touch in pairs(action.touch) do
		if type(touch) == "table"
			and (touch.pressed or moved_far_enough(touch, threshold)) then
			return true
		end
	end
	return false
end

function M.initial_mode(category)
	if category == "mobile" or category == "tablet" then return M.TOUCH end
	return M.KEYBOARD
end

function M.prepare_actions(options)
	options = options or {}
	return {
		keyboard_actions = make_action_set(options.keyboard_actions or KEYBOARD_ACTIONS),
		pointer_actions = make_action_set(options.pointer_actions or POINTER_ACTIONS),
		touch_actions = make_action_set(options.touch_actions or TOUCH_ACTIONS),
		device_category = options.device_category or "desktop",
		gamepad_deadzone = options.gamepad_deadzone or 0.25,
		pointer_threshold = options.pointer_threshold or 2,
	}
end

local CLASSIFICATIONS = {
	no_action = { reason = "no_action" },
	gamepad_button = { mode = M.GAMEPAD, reason = "gamepad_button" },
	gamepad_axis = { mode = M.GAMEPAD, reason = "gamepad_axis" },
	gamepad_deadzone = { reason = "gamepad_deadzone" },
	multi_touch = { mode = M.TOUCH, reason = "multi_touch" },
	touch = { mode = M.TOUCH, reason = "touch" },
	touch_release = { reason = "touch_release" },
	pointer_release = { reason = "pointer_release" },
	touch_drag = { mode = M.TOUCH, reason = "touch_drag" },
	touch_press = { mode = M.TOUCH, reason = "touch_press" },
	mouse_move = { mode = M.MOUSE, reason = "mouse_move" },
	mouse_press = { mode = M.MOUSE, reason = "mouse_press" },
	keyboard_key = { mode = M.KEYBOARD, reason = "keyboard_key" },
	not_meaningful = { reason = "not_meaningful" },
}

function M.classify(action_id, action, prepared)
	if type(action) ~= "table" then return CLASSIFICATIONS.no_action end
	prepared = prepared or M.prepare_actions()
	if action.gamepad ~= nil then
		if action.pressed then return CLASSIFICATIONS.gamepad_button end
		if axis_is_meaningful(action, prepared.gamepad_deadzone) then
			return CLASSIFICATIONS.gamepad_axis
		end
		return CLASSIFICATIONS.gamepad_deadzone
	end
	if touch_is_meaningful(action, prepared.pointer_threshold) then
		return CLASSIFICATIONS.multi_touch
	end
	if prepared.touch_actions[action_id] then
		if action.pressed or moved_far_enough(action, prepared.pointer_threshold) then
			return CLASSIFICATIONS.touch
		end
		return CLASSIFICATIONS.touch_release
	end
	local pointer_action = prepared.pointer_actions[action_id]
	local pointer_movement = action_id == nil and moved_far_enough(action, prepared.pointer_threshold)
	if pointer_action or pointer_movement then
		if not action.pressed and not moved_far_enough(action, prepared.pointer_threshold) then
			return CLASSIFICATIONS.pointer_release
		end
		if prepared.device_category == "mobile" or prepared.device_category == "tablet" then
			return pointer_movement and CLASSIFICATIONS.touch_drag or CLASSIFICATIONS.touch_press
		end
		return pointer_movement and CLASSIFICATIONS.mouse_move or CLASSIFICATIONS.mouse_press
	end
	if prepared.keyboard_actions[action_id] and action.pressed then
		return CLASSIFICATIONS.keyboard_key
	end
	return CLASSIFICATIONS.not_meaningful
end

local Tracker = {}
Tracker.__index = Tracker
function Tracker:get_mode() return self.mode end
function Tracker:get_device_category() return self.prepared.device_category end

function Tracker:set_device_category(category)
	if category ~= "mobile" and category ~= "tablet" and category ~= "desktop" then
		return false
	end
	if self.prepared.device_category == category then return false end
	self.prepared.device_category = category
	if not self.has_meaningful_input then
		local previous = self.mode
		self.mode = M.initial_mode(category)
		if previous ~= self.mode and self.on_change then
			self.on_change(self.mode, previous, "device_category", nil, nil)
		end
	end
	return true
end

function Tracker:restore_mode(mode)
	if mode ~= M.KEYBOARD and mode ~= M.MOUSE and mode ~= M.TOUCH and mode ~= M.GAMEPAD then
		return false
	end
	self.mode, self.has_meaningful_input = mode, true
	if mode == M.TOUCH then self.last_touch_at = self.clock() end
	return true
end

---@return boolean has_mode_changed
function Tracker:observe(action_id, action, now)
	local classification = M.classify(action_id, action, self.prepared)
	local mode = classification.mode
	if not mode then return false end
	now = now or self.clock()
	if mode == M.TOUCH then
		self.last_touch_at = now
	elseif mode == M.MOUSE and now - self.last_touch_at <= self.synthetic_mouse_window then
		return false
	end
	self.has_meaningful_input = true
	if mode == self.mode then return false end
	local previous = self.mode
	self.mode = mode
	if self.on_change then self.on_change(mode, previous, classification.reason, action_id, action) end
	return true
end

function M.new(options)
	options = options or {}
	local prepared = M.prepare_actions(options)
	return setmetatable({
		prepared = prepared, mode = M.initial_mode(prepared.device_category),
		has_meaningful_input = false, last_touch_at = -math.huge,
		synthetic_mouse_window = options.synthetic_mouse_window or 0.35,
		clock = options.clock or os.clock, on_change = options.on_change,
	}, Tracker)
end

return M
