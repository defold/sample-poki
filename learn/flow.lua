-- Controls the sample learn flow and its screen transitions.
local M = {}

local monarch = require("monarch.monarch")
local tips = require("learn.tips")

local LEARN_POPUP = hash("learn_popup")

local function refresh_popup(self)
	if self.is_open and self.is_popup_ready then
		msg.post("learn_popup:/ui#learn", "learn_refresh", { tip_id = tips.context(self.snapshot or {}) })
	end
end

---Close the Learn overlay and restore the underlying screen.
---@param self table
function M.hide(self)
	if self.is_open then
		self.is_open = false
		self.is_popup_ready = false
		-- A new screen may already have removed all popups.
		if monarch.is_top(LEARN_POPUP) then monarch.back({ sequential = true }) end
	end
end

---Open the Learn overlay for the current game context.
---@param self table
---@return boolean is_opened
function M.show(self)
	local s = self.snapshot or {}
	local topic = tips.context(s)
	if self.is_open or s.is_blocked or s.is_ad_busy or not topic then return false end
	self.is_open = true
	self.is_popup_ready = false
	monarch.show(LEARN_POPUP, { sequential = true }, {
		tip_id = topic, input_mode = s.input_mode, device_category = s.device_category,
	}, function()
		if not self.is_open then
			if monarch.is_top(LEARN_POPUP) then monarch.back({ sequential = true }) end
		end
	end)
	return true
end

---Open or close Learn using the same action.
---@param self table
function M.toggle(self)
	if self.is_open then M.hide(self) else M.show(self) end
end

---Refresh the Learn overlay from the latest app snapshot.
---@param self table
---@param snapshot table
function M.on_snapshot(self, snapshot)
	local previous = self.snapshot or {}
	self.snapshot = snapshot
	if snapshot.is_blocked or snapshot.is_ad_busy or previous.screen ~= snapshot.screen
		or previous.popup ~= snapshot.popup then
		M.hide(self)
	end
	if not self.is_auto_shown and tips.context(snapshot) == "first_contact" then
		self.is_auto_shown = M.show(self)
	elseif self.is_open then
		refresh_popup(self)
	end
end

---Track when the popup collection has finished loading and can receive messages.
---@param self table
---@param is_ready boolean
function M.set_popup_ready(self, is_ready)
	self.is_popup_ready = is_ready
	if is_ready then refresh_popup(self) end
end

return M
