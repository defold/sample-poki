-- Queues mission hints and applies their slow-motion timing.
local M = {}

local progress = require("game.modules.profile.progress")
local time_controller = require("common.time_controller")
local addresses = require("common.addresses")
local gameplay = require("game.modules.runtime.gameplay")

M.TUTORIAL_FOR_EVENT = {
	shot_fired = "ammo",
	ship_damaged = "health",
}

local function tutorial_is_pending(self, tutorial_id)
	return self.tutorial_pending[tutorial_id] == true
		or self.time:get_tutorial_id() == tutorial_id
end

---Start the next queued hint when no other tutorial is active.
---@param self table
function M.start_next_tutorial(self)
	if self.time:get_tutorial_id() or #self.tutorial_queue == 0 then
		return
	end
	local tutorial_id = table.remove(self.tutorial_queue, 1)
	self.time:start_tutorial(tutorial_id)
end

---Queue a tutorial only if it is unseen and neither queued nor active.
---@param self table
---@param tutorial_id string
---@return boolean is_queued
function M.enqueue_tutorial(self, tutorial_id)
	if self.app.screen ~= "gameplay" or self.app.phase ~= "PLAYING" then
		return false
	end
	if tutorial_is_pending(self, tutorial_id) or progress.is_tutorial_seen(tutorial_id) then
		return false
	end
	self.tutorial_pending[tutorial_id] = true
	self.tutorial_queue[#self.tutorial_queue + 1] = tutorial_id
	M.start_next_tutorial(self)
	return true
end

---Attach a time controller with callbacks to the app.
---@param self table
function M.create_time_controller(self)
	self.tutorial_queue = {}
	self.tutorial_pending = {}
	self.time = time_controller.new({
		on_factor = function(factor)
			self.app.world_time_factor = factor
			gameplay.apply_world_factor(self)
		end,
		on_tutorial = function(event_name, tutorial_id)
			if event_name == "started" then
				if self.is_gameplay_ready then
					msg.post(addresses.GAMEPLAY_HUD, "show_tutorial", { id = tutorial_id })
				end
			else
				if self.is_gameplay_ready then
					msg.post(addresses.GAMEPLAY_HUD, "hide_tutorial", { id = tutorial_id })
				end
				progress.set_tutorial_seen(tutorial_id)
				self.tutorial_pending[tutorial_id] = nil
				M.start_next_tutorial(self)
			end
		end,
	})
end

return M
