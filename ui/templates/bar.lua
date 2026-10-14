---Reusable HUD fill bar Druid widget (for HP, ammunition, boss HP)
---@class starbreaker.bar: druid.widget
---@field root node
---@field back node
---@field fill node
---@field progress any
---@field ratio number
---@field is_failed boolean
---@field rest_back vector4
---@field rest_fill vector4
local M = {}

local colors = require("ui.colors")

local FLASH_SECONDS = 0.24

local function color_copy(source)
	return vmath.vector4(source.x, source.y, source.z, source.w)
end

local function capture_rest(self)
	self.rest_back = color_copy(gui.get_color(self.back))
	self.rest_fill = color_copy(gui.get_color(self.fill))
end

local function apply_colors(self)
	gui.cancel_animations(self.back, gui.PROP_COLOR)
	gui.cancel_animations(self.fill, gui.PROP_COLOR)
	if self.is_failed then
		gui.set_color(self.back, colors.fail)
		gui.set_color(self.fill, colors.fail)
	else
		gui.set_color(self.back, self.rest_back)
		gui.set_color(self.fill, self.rest_fill)
	end
end

---Set up the fill animation and save the colors to restore after a flash or failure.
---@param self starbreaker.bar
function M:init()
	self.root = self:get_node("bar")
	self.back = self:get_node("back")
	self.fill = self:get_node("fill")
	self.ratio = 1
	self.is_failed = false
	self.progress = self.druid:new_progress("fill", "x", 1)
	capture_rest(self)
end

---Animate the fill to the current fraction of health or ammo.
---@param self starbreaker.bar
---@param current number
---@param maximum number
---@return starbreaker.bar
function M:set_ratio(current, maximum)
	self.ratio = (current or 0) / math.max(maximum or 0, 1)
	self.progress:to(self.ratio)
	return self
end

---Cancel the fill animation and reset the bar to full.
---@param self starbreaker.bar
---@return starbreaker.bar
function M:reset()
	self.ratio = 1
	self.progress.target = nil
	self.progress:set_value(1)
	return self
end

---Switch the bar to failure colors, or restore its theme.
---@param self starbreaker.bar
---@param is_failed boolean
---@return starbreaker.bar
function M:set_failed(is_failed)
	is_failed = is_failed == true
	if self.is_failed == is_failed then
		return self
	end
	self.is_failed = is_failed
	apply_colors(self)
	return self
end

---Briefly flash a successful hit unless the bar has failed.
---@param self starbreaker.bar
---@return starbreaker.bar
function M:flash()
	if self.is_failed then
		return self
	end
	gui.cancel_animations(self.fill, gui.PROP_COLOR)
	gui.set_color(self.fill, colors.bar_flash)
	gui.animate(self.fill, gui.PROP_COLOR, self.rest_fill, gui.EASING_OUTQUAD, FLASH_SECONDS)
	return self
end

---Resize the fill component to the current background.
---@param self starbreaker.bar
---@return starbreaker.bar
function M:sync_layout()
	self.progress:set_max_size(gui.get_size(self.back)):set_value(self.ratio)
	return self
end

---Recapture themed colors and redraw the fill.
---@param self starbreaker.bar
function M:on_layout_change()
	capture_rest(self)
	self:sync_layout()
	apply_colors(self)
end

return M
