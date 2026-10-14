-- Shared GUI-side input handling helpers
local M = {}

local mode = require("common.input.mode")
local button = require("ui.templates.button")
local actions = require("common.input.actions")
local axis = require("common.input.axis")
local client = require("common.audio.client")
local ad_state = require("common.ad_state")

function M.is_ad_busy()
	return ad_state.is_busy()
end

local ACTIONS = { "primary_action", "rewarded_action", "cancel_action",
	"menu_up", "menu_down", "menu_left", "menu_right" }

local MENU = {
	[actions.menu_up] = true,
	[actions.menu_down] = true,
	[actions.menu_left] = true,
	[actions.menu_right] = true,
}

---Initialize input mode and device state for a GUI screen.
---@param self table
---@param data? table
function M.init(self, data)
	data = data or {}
	self.input_tracker = mode.new({
		keyboard_actions = ACTIONS,
		device_category = data.device_category or "desktop",
		clock = socket.gettime,
	})
	if data.input_mode and data.input_mode ~= "" then
		self.input_tracker:restore_mode(data.input_mode)
	end
	self.input_mode = self.input_tracker:get_mode()
end

---Track an input event and update the active control scheme.
---@param self table
---@param action_id hash
---@param action table
---@return boolean has_mode_changed
function M.observe(self, action_id, action)
	local has_changed = self.input_tracker:observe(action_id, action)
	if has_changed then
		local current_mode = self.input_tracker:get_mode()
		self.input_mode = current_mode
		if current_mode == "keyboard" or current_mode == "gamepad" then
			button.lock_pointer_hover()
		else
			button.unlock_pointer_hover()
		end
	end
	return has_changed
end

---Restore input mode from a screen payload when focus returns.
---@param self table
---@param data table
function M.restore(self, data)
	if data.device_category then self.input_tracker:set_device_category(data.device_category) end
	if data.input_mode then self.input_tracker:restore_mode(data.input_mode) end
	self.input_mode = self.input_tracker:get_mode()
	if self.input_mode == "keyboard" or self.input_mode == "gamepad" then
		button.lock_pointer_hover()
	else
		button.unlock_pointer_hover()
	end
end

---Notify the audio service of a press so browser audio can start. Ignore presses during ads.
---@param action table
function M.report_audio_gesture(action)
	if not M.is_ad_busy() and action and action.pressed then
		client.gesture()
	end
end

---Handle audio activation and the optional reset shortcut, unless input is blocked.
---Return true when the screen should stop processing this input.
---@param self table
---@param action_id hash
---@param action table
---@param opts table
---@return boolean
function M.handle_common_input(self, action_id, action, opts)
	if M.is_ad_busy() then return true end
	opts = opts or {}
	M.report_audio_gesture(action)
	if opts.blocked and not opts.reset_while_blocked then
		return true
	end
	if action_id == actions.reset_save and action and action.pressed then
		if opts.on_reset then
			opts.on_reset(self)
			return true
		end
	end
	return opts.blocked == true
end

---Update the input mode and hover state. Convert horizontal stick input into button presses for Druid.
---@param self table
---@param action_id hash
---@param action table
---@param opts table
---@return table button_input
function M.route(self, action_id, action, opts)
	opts = opts or {}
	local was_hover_locked = button.is_pointer_hover_locked()
	local mode_changed = M.observe(self, action_id, action)
	local hover_unlocked = was_hover_locked and not button.is_pointer_hover_locked()
	if mode_changed and opts.on_mode then
		opts.on_mode(self)
	end
	if hover_unlocked and opts.on_hover then
		opts.on_hover(self)
	end
	local button_input = action
	local stick = opts.stick
	if stick and MENU[action_id] and axis.is_press(action) then
		button.lock_pointer_hover()
	end
	if stick and actions.is_menu_horizontal(action_id) then
		self.navigation_input = self.navigation_input or {}
		button_input = axis.update_digital_action(stick, action_id, action, self.navigation_input)
	end
	return button_input
end

return M
