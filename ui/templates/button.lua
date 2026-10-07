-- Reusable button Druid widget with focus, input and visual states.
---@class starbreaker.button: druid.widget
---@field root node
---@field background node
---@field content node
---@field icon_left node
---@field icon_right node
---@field text any
---@field button any
---@field hover any
---@field callback function|nil
---@field params any
---@field normal_color vector4
---@field highlight_color vector4
---@field is_highlighted boolean
---@field is_hovered boolean
---@field is_hover_shown boolean|nil
---@field prompt_kind 'primary'|'rewarded'|'cancel'|nil
---@field prompt_mode string|nil
---@field input_mode string|nil
---@field is_prompt_visible_when_disabled boolean|nil
local M = {}

local ad_state = require("common.ad_state")

local EMPTY_ACTION = {} -- Read-only argument for Druid's interruption callback.
local PROMPTS = {
	primary = { keyboard = hash("keyboard_space"), gamepad = hash("xbox_button_color_a") },
	rewarded = { keyboard = hash("keyboard_r"), gamepad = hash("xbox_button_color_b") },
	cancel = { keyboard = hash("keyboard_escape"), gamepad = hash("xbox_button_menu") },
}

local function lighter(color)
	return vmath.vector4(vmath.lerp(0.40, color.x, 1),
		vmath.lerp(0.40, color.y, 1), vmath.lerp(0.40, color.z, 1), color.w)
end

-- Keyboard/gamepad navigation freezes leftover pointer hover until the next mouse/touch input
local is_pointer_hover_locked = false

local function should_show_hover(self)
	return self.is_hovered and not is_pointer_hover_locked
end

local function render_color(self)
	gui.set_color(self.background,
		(self.is_highlighted or should_show_hover(self)) and self.highlight_color or self.normal_color)
end

---Ignore stale mouse hover during keyboard or gamepad navigation.
function M.lock_pointer_hover()
	is_pointer_hover_locked = true
end

---Allow pointer hover to select buttons again.
function M.unlock_pointer_hover()
	is_pointer_hover_locked = false
end

---Check whether keyboard or gamepad navigation is blocking pointer hover.
---@return boolean
function M.is_pointer_hover_locked()
	return is_pointer_hover_locked
end

local function digital_prompt_mode(self, input_mode)
	if input_mode == "keyboard" or input_mode == "gamepad" then
		self.prompt_mode = input_mode
		return input_mode
	end
	if input_mode == "touch" then
		return nil
	end
	-- When using a mouse, show the most recent keyboard/gamepad glyph.
	return self.prompt_mode or "keyboard"
end

local function render_prompt(self)
	local prompts = PROMPTS[self.prompt_kind]
	local mode = digital_prompt_mode(self, self.input_mode)
	local animation = prompts and mode and prompts[mode]
	gui.set_enabled(self.icon_right, animation ~= nil and (self:is_enabled() or self.is_prompt_visible_when_disabled))
	if animation then gui.play_flipbook(self.icon_right, animation) end
end

local function on_mouse_hover(self, _, is_hovered)
	self.is_hovered = is_hovered
	render_color(self)
end

---Bind button nodes, click callback, and hover coloring.
---@param self starbreaker.button
---@param callback function|nil
---@param params any
function M:init(callback, params)
	self.root = self:get_node("button")
	self.background = self:get_node("background")
	self.content = self:get_node("content")
	self.icon_left = self:get_node("icon_left")
	self.icon_right = self:get_node("icon_right")
	self.normal_color = gui.get_color(self.background)
	self.highlight_color = lighter(self.normal_color)
	self.callback, self.params = callback, params
	self.is_highlighted, self.is_hovered = false, false
	self.prompt_mode = "keyboard"
	self.text = self.druid:new_lang_text("text")
	self.button = self.druid:new_button(self.root, function()
		if not ad_state.is_busy() and self.callback then self.callback(self:get_context(), self.params, self) end
	end)
	self.hover = self.button.hover
	self.hover.on_mouse_hover:subscribe(on_mouse_hover, self)
	ad_state.changed:subscribe(M.cancel_press, self)
	render_prompt(self)
end

---Cancel both the visual press and Druid's pending click, including key release.
---@param self starbreaker.button
---@return starbreaker.button
function M:cancel_press()
	self.button:on_input_interrupt(nil, EMPTY_ACTION)
	return self
end

---Cancel a held press when this widget loses focus.
---@param self starbreaker.button
function M:on_focus_lost() self:cancel_press() end

---Cancel a held press after a resize.
---@param self starbreaker.button
function M:on_window_resized() self:cancel_press() end

---Cancel pending input before the widget is removed.
---@param self starbreaker.button
function M:on_remove()
	ad_state.changed:unsubscribe(M.cancel_press, self)
	self:cancel_press()
end

---Refresh hover feedback when the input scheme changes.
---@param self starbreaker.button
---@param action_id hash
---@param action table
---@return boolean
function M:on_input(action_id, action)
	local is_hover_shown = should_show_hover(self)
	if self.is_hover_shown ~= is_hover_shown then
		self.is_hover_shown = is_hover_shown
		render_color(self)
	end
	return false
end

---Refresh hover feedback after Druid interrupts input.
---@param self starbreaker.button
---@param action_id hash
---@param action table
function M:on_input_interrupt(action_id, action) self:on_input(action_id, action) end

---Cancel pressed state when the app requests a UI reset.
---@param self starbreaker.button
---@param message_id hash
function M:on_message(message_id)
	if message_id == hash("cancel_ui_input") then self:cancel_press() end
end

local function label(self)
	return self.text.text or self.text
end

---Recompute text bounds, prompt, and colors after layout.
---@param self starbreaker.button
function M:on_layout_change()
	local text = label(self)
	text:set_size(gui.get_size(text.node))
	self:cancel_press()
	render_color(self)
	render_prompt(self)
end

---Set literal button text and return the widget for chaining.
---@param self starbreaker.button
---@param text string
---@return starbreaker.button
function M:set_text(text)
	self.text:set_text(text)
	return self
end

---Translate the button label with optional format values.
---@param self starbreaker.button
---@param locale_id string
---@param ... any
---@return starbreaker.button
function M:set_lang(locale_id, ...)
	self.text:translate(locale_id, ...)
	return self
end

---Show a flipbook icon on the left, or hide it.
---@param self starbreaker.button
---@param animation hash|nil
---@return starbreaker.button
function M:set_left_icon(animation)
	gui.set_enabled(self.icon_left, animation ~= nil)
	if animation then gui.play_flipbook(self.icon_left, animation) end
	return self
end

---Set a HUD input hint, with an option to show it for disabled actions.
---@param self starbreaker.button
---@param kind 'primary'|'rewarded'|'cancel'
---@param input_mode string
---@param should_show_when_disabled boolean|nil
---@return starbreaker.button
function M:set_input_prompt(kind, input_mode, should_show_when_disabled)
	self.prompt_kind, self.input_mode = kind, input_mode
	self.is_prompt_visible_when_disabled = should_show_when_disabled == true
	render_prompt(self)
	return self
end

---Enable or disable clicks.
---Hover feedback remains active.
---@param self starbreaker.button
---@param is_enabled boolean
---@return starbreaker.button
function M:set_enabled(is_enabled)
	if not is_enabled then self:cancel_press() end
	self.button:set_enabled(is_enabled)
	self.hover:set_enabled(true)
	render_prompt(self)
	return self
end

---Whether Druid currently allows the button to click.
---@param self starbreaker.button
---@return boolean
function M:is_enabled() return self.button:is_enabled() end

---Show or hide the complete button node.
---@param self starbreaker.button
---@param is_visible boolean
---@return starbreaker.button
function M:set_visible(is_visible)
	if not is_visible then self:cancel_press() end
	gui.set_enabled(self.root, is_visible)
	return self
end

---Assign the digital input action that activates the button.
---@param self starbreaker.button
---@param action_id hash|nil
---@return starbreaker.button
function M:set_key_trigger(action_id)
	if self.button:get_key_trigger() ~= action_id then
		-- Adding focus during this pointer press must not cancel that press.
		if self.button:get_key_trigger() ~= nil then self:cancel_press() end
		self.button:set_key_trigger(action_id)
	end
	return self
end

---Set the base color and derive its hover highlight.
---@param self starbreaker.button
---@param color vector4
---@return starbreaker.button
function M:set_color(color)
	self.normal_color = vmath.vector4(color)
	self.highlight_color = lighter(color)
	render_color(self)
	return self
end

---Apply keyboard/gamepad focus coloring.
---@param self starbreaker.button
---@param is_highlighted boolean
---@param color vector4|nil
---@return starbreaker.button
function M:set_highlighted(is_highlighted, color)
	self.is_highlighted = is_highlighted == true
	self.highlight_color = color and vmath.vector4(color) or lighter(self.normal_color)
	self.is_hover_shown = should_show_hover(self)
	render_color(self)
	return self
end

---Whether the pointer is hovering over this button.
---@param self starbreaker.button
---@return boolean
function M:is_pointer_hovered()
	return self.is_hovered == true
end

return M
