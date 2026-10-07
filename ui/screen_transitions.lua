-- Common screen transitions configuration
local M = {}

local monarch = require("monarch.monarch")
local gui = require("monarch.transitions.gui")

local defold_gui = _G.gui
---@class starbreaker.screen_transitions
---@field screen hash|string
---@field root node
---@field is_visible boolean
---@field on_transition function|nil
---@field create function
---@field transition any

---Create screen transition state and connect its completion callback.
---@param screen hash|string
---@param on_transition? function
---@return starbreaker.screen_transitions
function M.new(screen, on_transition)
	local self = setmetatable({ screen = screen, is_visible = false,
		root = defold_gui.get_node("root"), on_transition = on_transition }, { __index = M })
	local function fade(fn, is_visible)
		return function(node, data, easing, duration, delay, done)
			self.is_visible = is_visible
			if on_transition then on_transition(is_visible, false) end
			fn(node, data, easing, duration, delay, function()
				if on_transition then on_transition(is_visible, true) end
				if done then done() end
			end)
		end
	end
	local function create()
		return gui.create(self.root)
		.show_in(fade(gui.fade_in, true), defold_gui.EASING_INOUTQUAD, 0.2)
		.back_in(fade(gui.fade_in, true), defold_gui.EASING_INOUTQUAD, 0.2)
		.show_out(fade(gui.fade_out, false), defold_gui.EASING_INOUTQUAD, 0.2)
		.back_out(fade(gui.fade_out, false), defold_gui.EASING_INOUTQUAD, 0.2)
	end
	self.create = create
	self.transition = create()
	self:snap(false)
	if monarch.screen_exists(screen) then
		monarch.on_transition(screen, function(...) self:handle(...) end)
	end
	return self
end

---Pass a Monarch transition event to this screen's motion state.
---@param self starbreaker.screen_transitions
---@param ... table
function M:handle(...)
	-- 6.0.2 retains its in-progress count after a layout interruption.
	self.transition = self.create()
	self.transition.handle(...)
end

---Refresh screen transitions after a window or layout change.
---@param self starbreaker.screen_transitions
function M:resize()
	self.transition.handle(hash("layout_changed"), {})
	self:snap(self.is_visible)
end

---Whether an entering or leaving transition still blocks input.
---@param self starbreaker.screen_transitions
---@return boolean
function M:is_input_blocked()
	return not self.is_visible or monarch.is_busy()
end

---Restore the visible state after returning to this screen.
---@param self starbreaker.screen_transitions
function M:restore_focus()
	-- Monarch 6.0.2 sends focus to retained popups but skips BACK_IN.
	self:snap(true)
end

---Set visibility immediately, skipping the transition animation.
---@param self starbreaker.screen_transitions
---@param is_visible boolean
function M:snap(is_visible)
	self.is_visible = is_visible
	local color = defold_gui.get_color(self.root)
	color.w = is_visible and 1 or 0
	defold_gui.set_color(self.root, color)
end

---Release screen-transition resources.
---@param self starbreaker.screen_transitions
function M:final()
	if monarch.screen_exists(self.screen) then monarch.on_transition(self.screen, nil) end
end

return M
