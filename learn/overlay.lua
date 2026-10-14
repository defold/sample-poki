-- Persistent Poki-logo toggle for the sample learn popup.
-- Lives on the overlay GO and sends toggle messages to app.
local M = {}
local tips = require("learn.tips")

local APP_URL = "main:/learn/guide#learn_host"
local LAYOUT_PORTRAIT = hash("Portrait")
local BUTTON_DESKTOP = vmath.vector3(-44, 60, 0)
local BUTTON_MOBILE_LANDSCAPE = vmath.vector3(-44, 220, 0)
local BUTTON_MOBILE_PORTRAIT = vmath.vector3(-44, 280, 0)
local PROMPT_KEYBOARD = hash("keyboard_p")
local PROMPT_GAMEPAD = hash("xbox_button_color_x")
local LOGO_SIZE = vmath.vector3(56, 56, 0)
local PULSE_SIZE = vmath.vector3(62, 62, 0)

local function node(id)
	return gui.get_node(id)
end

local function layout_button(self)
	local is_mobile = self.is_learn_mobile == true
	local is_portrait = gui.get_layout() == LAYOUT_PORTRAIT
	local position = BUTTON_DESKTOP
	if is_mobile then
		position = is_portrait and BUTTON_MOBILE_PORTRAIT or BUTTON_MOBILE_LANDSCAPE
	end
	gui.set_position(node("poki_learn"), position)
end

local function prompt_animation(mode)
	if mode == "gamepad" then
		return PROMPT_GAMEPAD
	end
	return PROMPT_KEYBOARD
end

---Redraw the current Learn card, navigation, and input prompts.
---@param self table
function M.refresh(self)
	layout_button(self)
	local is_visible = self.is_blocked ~= true and tips.label(self.learn_topic) ~= nil
	local logo = node("poki_learn")
	gui.set_enabled(logo, is_visible)
	local label = tips.label(self.learn_topic) or ""
	gui.set_text(node("poki_learn_context"), label)
	-- Short topics keep their badge within the icon's width, clear of shop controls.
	gui.set_size(node("poki_learn_badge"), vmath.vector3(math.max(56, #label * 8 + 16), 24, 0))
	if not is_visible then
		gui.cancel_animations(logo, "size")
		gui.set_size(logo, LOGO_SIZE)
	elseif self.learn_notified_topic ~= self.learn_topic then
		self.learn_notified_topic = self.learn_topic
		-- Size leaves Druid's press/hover scale and the label untouched.
		gui.cancel_animations(logo, "size")
		gui.set_size(logo, LOGO_SIZE)
		gui.animate(logo, "size", PULSE_SIZE, gui.EASING_INOUTSINE, 0.22, 0, nil,
			gui.PLAYBACK_ONCE_PINGPONG)
	end
	local should_show_prompt = is_visible and self.is_learn_mobile ~= true
	local prompt = node("poki_learn_prompt")
	gui.set_enabled(prompt, should_show_prompt)
	if should_show_prompt then
		gui.play_flipbook(prompt, prompt_animation(self.learn_prompt_mode))
	end
end

---Set a Developer Tips topic
---@param self table
---@param topic string|nil
function M.set_context(self, topic)
	self.learn_topic = topic
	M.refresh(self)
end

---Update the overlay for a new device category.
---@param self table
---@param category string
function M.set_device(self, category)
	self.is_learn_mobile = category == "mobile" or category == "tablet"
	M.refresh(self)
end

---Update prompts for the player's active control scheme.
---@param self table
---@param mode string
function M.set_input_mode(self, mode)
	if mode == "keyboard" or mode == "gamepad" then
		self.learn_prompt_mode = mode
	end
	M.refresh(self)
end

---Create and wire the Learn overlay widgets.
---@param self table
---@param druid table
function M.bind(self, druid)
	self.is_learn_mobile = false
	self.learn_prompt_mode = "keyboard"
	gui.set_inherit_alpha(node("poki_learn"), false)
	-- Pointer hits are consumed in overlay.gui_script first.
	-- This callback is the fallback when pick_node misses; flow.toggle ignores a second post.
	self.learn_toggle = druid:new_button("poki_learn", function()
		msg.post(APP_URL, "toggle")
	end)
	M.refresh(self)
end

return M
