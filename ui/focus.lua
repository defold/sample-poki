-- Focus (highlights) selection and activation for UI buttons.

---Build a hover callback that moves focus only when the hovered row changes.
---@param index integer
---@param get_focus fun(): integer
---@param set_focus fun(index: integer)
---@return fun()
local M = {}

local button = require("ui.templates.button")

function M.create_hover_callback(index, get_focus, set_focus)
	return function()
		if button.is_pointer_hover_locked() or get_focus() == index then
			return
		end
		set_focus(index)
	end
end

---Connect button hover callbacks to a shared focus index.
---@param buttons table
---@param get_focus fun(): integer
---@param set_focus fun(index: integer)
function M.bind_hover(buttons, get_focus, set_focus)
	for index, button_instance in ipairs(buttons) do
		local focus_index = index
		button_instance.hover.on_mouse_hover:subscribe(function(_, hovered)
			if hovered and not button.is_pointer_hover_locked()
				and get_focus() ~= focus_index then
				set_focus(focus_index)
			end
		end)
	end
end

return M
