---Reusable icon + optional label + current/max value Druid Widget.
---Used for hull, ammo and objective counters.
---@class starbreaker.stat: druid.widget
---@field root node
---@field icon node
---@field label_node node
---@field value_node node
---@field label any
---@field value any
---@field mode string|nil
---@field is_centered boolean
---@field rest_position vector3
---@field rest_icon table
---@field rest_label table
---@field rest_value table
local M = {}

local colors = require("ui.colors")
local math_utils = require("common.math_utils")

local SCALE_EMPHASIS = 1.18
local EMPHASIS_SECONDS = 0.18

local function vec_copy(source)
	return vmath.vector3(source.x, source.y, source.z)
end

local function color_copy(source)
	return vmath.vector4(source.x, source.y, source.z, source.w)
end

local function text_box(widget)
	return widget.text or widget
end

local function capture_rest(self)
	self.rest_position = vec_copy(gui.get_position(self.root))
	self.rest_icon = {
		position = vec_copy(gui.get_position(self.icon)),
		scale = vec_copy(gui.get_scale(self.icon)),
		color = color_copy(gui.get_color(self.icon)),
	}
	self.rest_label = {
		scale = vec_copy(gui.get_scale(self.label_node)),
		color = color_copy(gui.get_color(self.label_node)),
	}
	self.rest_value = {
		position = vec_copy(gui.get_position(self.value_node)),
		scale = vec_copy(gui.get_scale(self.value_node)),
		color = color_copy(gui.get_color(self.value_node)),
	}
end

local function emphasis_scale(rest_scale, is_emphasized)
	if not is_emphasized then
		return rest_scale
	end
	return vmath.vector3(rest_scale.x * SCALE_EMPHASIS, rest_scale.y * SCALE_EMPHASIS, rest_scale.z)
end

local function apply_node(gui_node, rest, color, is_emphasized, should_animate)
	local scale = emphasis_scale(rest.scale, is_emphasized)
	gui.cancel_animations(gui_node, gui.PROP_SCALE)
	gui.cancel_animations(gui_node, gui.PROP_COLOR)
	if should_animate then
		gui.animate(gui_node, gui.PROP_COLOR, color, gui.EASING_OUTQUAD, EMPHASIS_SECONDS)
		gui.animate(gui_node, gui.PROP_SCALE, scale, gui.EASING_OUTBACK, EMPHASIS_SECONDS)
	else
		gui.set_color(gui_node, color)
		gui.set_scale(gui_node, scale)
	end
end

local function apply_emphasis(self, should_animate)
	local rest_icon, rest_label, rest_value = self.rest_icon, self.rest_label, self.rest_value
	if not rest_icon then
		return
	end
	local is_emphasized = self.mode == "cleared" or self.mode == "failed"
	local icon_color, label_color, value_color = rest_icon.color, rest_label.color, rest_value.color
	if self.mode == "cleared" then
		icon_color, value_color = colors.primary, colors.primary
	elseif self.mode == "failed" then
		icon_color, label_color, value_color = colors.fail, colors.fail, colors.fail
	end
	apply_node(self.icon, rest_icon, icon_color, is_emphasized, should_animate)
	apply_node(self.label_node, rest_label, label_color, is_emphasized, should_animate)
	apply_node(self.value_node, rest_value, value_color, is_emphasized, should_animate)
end

---Bind a HUD statistic, optionally with a translated label.
---@param self starbreaker.stat
---@param locale_id string|nil
function M:init(locale_id)
	self.root = self:get_node("stat")
	self.icon = self:get_node("icon")
	self.label_node = self:get_node("label")
	self.value_node = self:get_node("value")
	self.mode = nil
	self.is_centered = false
	self.label = self.druid:new_lang_text("label")
	self.value = self.druid:new_text("value")
	if locale_id then
		gui.set_enabled(self.label_node, true)
		self.label:translate(locale_id)
	else
		gui.set_enabled(self.label_node, false)
	end
	capture_rest(self)
end

---Show the current and maximum values as whole numbers.
---@param self starbreaker.stat
---@param current number
---@param maximum number
---@return starbreaker.stat
function M:set_counts(current, maximum)
	self.value:set_text(string.format("%d/%d", math.ceil(current or 0),
		math.max(math_utils.non_negative_integer(maximum), 1)))
	return self
end

---Switch the statistic icon's flipbook animation.
---@param self starbreaker.stat
---@param animation hash|nil
---@return starbreaker.stat
function M:set_icon(animation)
	if animation then
		gui.play_flipbook(self.icon, animation)
	end
	return self
end

---Show or hide the full statistic row.
---@param self starbreaker.stat
---@param is_visible boolean
---@return starbreaker.stat
function M:set_visible(is_visible)
	gui.set_enabled(self.root, is_visible == true)
	return self
end

---Center the icon/value pair when its label is hidden.
---@param self starbreaker.stat
---@param is_centered boolean
---@return starbreaker.stat
function M:place(is_centered)
	self.is_centered = is_centered == true
	local rest = self.rest_position
	if not rest then
		return self
	end
	local x = rest.x
	if self.is_centered then
		x = -(self.rest_icon.position.x + self.rest_value.position.x) * 0.5
	end
	gui.set_position(self.root, vmath.vector3(x, rest.y, rest.z))
	return self
end

---mode is nil, "cleared" or "failed".
---Newly cleared objective pairs may animate.
---@param self starbreaker.stat
---@param mode string|nil
---@param should_animate boolean
---@return starbreaker.stat
function M:set_emphasis(mode, should_animate)
	if self.mode == mode and not should_animate then
		return self
	end
	self.mode = mode
	apply_emphasis(self, should_animate == true)
	return self
end

---Reflow text and reapply the current emphasis.
---@param self starbreaker.stat
function M:on_layout_change()
	capture_rest(self)
	local label = text_box(self.label)
	local value = text_box(self.value)
	label:set_size(gui.get_size(label.node))
	value:set_size(gui.get_size(value.node))
	self:place(self.is_centered)
	apply_emphasis(self, false)
end

return M
