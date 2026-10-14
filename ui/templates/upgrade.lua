-- Reusable upgrade row Druid widget.
-- Used in the shop for the upgrades showing cost, level and purchase state.
---@class starbreaker.upgrade: druid.widget
---@field id string
---@field root node
---@field background node
---@field rest_position vector3
---@field normal_color vector4
---@field highlight_color vector4
---@field is_highlighted boolean
---@field is_hovered boolean
---@field is_hover_shown boolean|nil
---@field name any
---@field level any
---@field price any
---@field row_button any
---@field button starbreaker.button
---@field offer table|nil
local M = {}

local button = require("ui.templates.button")

local EMPTY_ACTION = {} -- Read-only argument for Druid's interruption callback.

-- Use the inner Text component to set the size, as in button.lua. LangText has no set_size method.
local function text_box(widget)
	return widget.text or widget
end

local function target_color(self)
	local is_hovered = self.is_hovered and not button.is_pointer_hover_locked()
	return (self.is_highlighted or is_hovered) and self.highlight_color or self.normal_color
end

local function render_color(self)
	gui.cancel_animations(self.background, gui.PROP_COLOR)
	gui.set_color(self.background, target_color(self))
end

---Bind an upgrade row and its purchase/hover callbacks.
---@param self starbreaker.upgrade
---@param id string
---@param on_purchase function
---@param on_hover function|nil
function M:init(id, on_purchase, on_hover)
	self.id = id
	self.root = self:get_node("row")
	self.background = self:get_node("background")
	self.rest_position = gui.get_position(self.root)
	self.normal_color = gui.get_color(self.background)
	local color = self.normal_color
	self.highlight_color = vmath.vector4(vmath.lerp(0.16, color.x, 1),
		vmath.lerp(0.16, color.y, 1), vmath.lerp(0.16, color.z, 1), color.w)
	self.is_highlighted, self.is_hovered = false, false
	self.name = self.druid:new_lang_text("name", "upgrade_" .. id)
	self.level = self.druid:new_lang_text("level")
	self.price = self.druid:new_text("price")
	local function purchase()
		on_purchase(self:get_context(), self.id)
	end
	self.row_button = self.druid:new_button(self.root, purchase)
	self.row_button:set_animations_disabled()
	self.button = self.druid:new_widget(button, "plus", nil, purchase)
	local function on_row_hover(_, is_hovered)
		self.is_hovered = is_hovered
		render_color(self)
		if is_hovered and on_hover and not button.is_pointer_hover_locked() then
			on_hover()
		end
	end
	self.row_button.hover.on_mouse_hover:subscribe(on_row_hover)
	self:set_offer(nil)
end

---Mark the row selected by digital navigation.
---@param self starbreaker.upgrade
---@param is_highlighted boolean
---@return starbreaker.upgrade
function M:set_highlighted(is_highlighted)
	if self.is_highlighted ~= is_highlighted then
		self.is_highlighted = is_highlighted
		render_color(self)
	end
	return self
end

---Enable or disable clicking the entire upgrade row.
---@param self starbreaker.upgrade
---@param is_enabled boolean
---@return starbreaker.upgrade
function M:set_row_enabled(is_enabled)
	self.row_button:set_enabled(is_enabled == true)
	self.row_button.hover:set_enabled(true)
	return self
end

---Display the next upgrade price, or disable an unavailable row.
---@param self starbreaker.upgrade
---@param offer table|nil
---@return starbreaker.upgrade
function M:set_offer(offer)
	self.offer = offer
	self.level:translate("level_of", offer and offer.level or 0)
	self.price:set_text(offer and tostring(offer.price) or "")
	self.button:set_enabled(offer ~= nil)
	self:set_row_enabled(offer ~= nil)
	return self
end

---Whether the row or plus button is under the pointer.
---@param self starbreaker.upgrade
---@return boolean
function M:is_pointer_hovered()
	return self.is_hovered == true or self.button:is_pointer_hovered()
end

---Refresh hover coloring after a control-scheme change.
---@param self starbreaker.upgrade
---@return boolean
function M:on_input()
	local is_hover_shown = self.is_hovered and not button.is_pointer_hover_locked()
	if self.is_hover_shown ~= is_hover_shown then
		self.is_hover_shown = is_hover_shown
		render_color(self)
	end
	return false
end

---Clear pending clicks on both row and plus button.
---@param self starbreaker.upgrade
---@return starbreaker.upgrade
function M:cancel_press()
	self.button:cancel_press()
	self.row_button:on_input_interrupt(nil, EMPTY_ACTION)
	return self
end

---Flash the row after a successful purchase.
---@param self starbreaker.upgrade
function M:celebrate()
	gui.cancel_animations(self.background, gui.PROP_COLOR)
	gui.set_color(self.background, vmath.vector4(0.22, 0.62, 0.44, self.normal_color.w))
	gui.animate(self.background, gui.PROP_COLOR, target_color(self), gui.EASING_OUTQUAD, 0.42)
end

---Animate the row to signal a rejected purchase.
---@param self starbreaker.upgrade
function M:shake()
	gui.cancel_animations(self.root, gui.PROP_POSITION)
	gui.set_position(self.root, self.rest_position)
	gui.animate(self.root, gui.PROP_POSITION, self.rest_position + vmath.vector3(12, 0, 0),
		gui.EASING_INOUTSINE, 0.06, 0, function()
			gui.animate(self.root, gui.PROP_POSITION, self.rest_position, gui.EASING_OUTBACK, 0.12)
		end)
end

---Reflow labels and restore the current offer state.
---@param self starbreaker.upgrade
function M:on_layout_change()
	render_color(self)
	gui.cancel_animations(self.root, gui.PROP_POSITION)
	self.rest_position = gui.get_position(self.root)
	for _, widget in ipairs({ self.name, self.level, self.price }) do
		local text = text_box(widget)
		text:set_size(gui.get_size(text.node))
	end
	self:set_offer(self.offer)
end

return M
