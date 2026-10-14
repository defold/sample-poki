---Reusable selector Druid widget with left and right arrows and a button in the middle.
---Used for ship and skin selection, or language change.
---@class starbreaker.selector: druid.widget
---@field root node
---@field prev starbreaker.button
---@field action starbreaker.button
---@field next starbreaker.button
---@field row_hover any
---@field is_hovered boolean|nil
local M = {}

local button = require("ui.templates.button")

local function subscribe_hover(button_instance, on_hover)
	button_instance.hover.on_mouse_hover:subscribe(function(_, is_hovered)
		if is_hovered and not button.is_pointer_hover_locked() then
			on_hover()
		end
	end)
end

---Bind the previous, action, and next buttons for one shop row.
---@param self starbreaker.selector
---@param on_action function|nil
---@param on_prev function|nil
---@param on_next function|nil
---@param on_hover function|nil
function M:init(on_action, on_prev, on_next, on_hover)
	self.root = self:get_node("row")
	local function bind(callback)
		if not callback then return nil end
		return function()
			callback(self:get_context())
		end
	end
	self.prev = self.druid:new_widget(button, "prev", nil, bind(on_prev))
	self.action = self.druid:new_widget(button, "action", nil, bind(on_action))
	self.next = self.druid:new_widget(button, "next", nil, bind(on_next))
	if on_hover then
		subscribe_hover(self.prev, on_hover)
		subscribe_hover(self.next, on_hover)
		self.row_hover = self.druid:new_hover(self.root)
		self.row_hover.on_mouse_hover:subscribe(function(_, is_hovered)
			self.is_hovered = is_hovered
			if is_hovered and not button.is_pointer_hover_locked() then
				on_hover()
			end
		end)
	end
end

---Whether any part of this selector is under the pointer.
---@param self starbreaker.selector
---@return boolean
function M:is_pointer_hovered()
	return self.is_hovered == true or self.prev:is_pointer_hovered()
		or self.action:is_pointer_hovered() or self.next:is_pointer_hovered()
end

---Clear pending clicks on all three selector buttons.
---@param self starbreaker.selector
---@return starbreaker.selector
function M:cancel_press()
	self.prev:cancel_press()
	self.action:cancel_press()
	self.next:cancel_press()
	return self
end

return M
