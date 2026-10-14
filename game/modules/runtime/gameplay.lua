-- Updates gameplay input, collection time and viewport size.


---Update gameplay input flags immediately, before another input or fixed update can run.
local M = {}

local addresses = require("common.addresses")
local poki_service = require("app.modules.platform.poki_service")

function M.sync_input(self, session)
	require("game.modules.player.player_input").sync_session(self, session)
end

---Cancel pressed UI controls before switching screens.
---@param self table
function M.cancel_ui_input(self)
	if self.is_gameplay_ready then msg.post(addresses.GAMEPLAY_HUD, "cancel_ui_input") end
	if self.is_mothership_ready then msg.post(addresses.MOTHERSHIP_GUI, "cancel_ui_input") end
end

---Enable or disable the gameplay input blocker during transitions.
---@param self table
---@param is_blocked boolean
function M.set_input_blocker(self, is_blocked)
	is_blocked = is_blocked or poki_service.get_state().is_ad_busy
	if is_blocked then
		M.cancel_ui_input(self)
	end
	self.ui.is_blocked = is_blocked == true
	msg.post(addresses.APP_CONTROLLER, "refresh_input_focus")
end

---Clear held controls when an ad starts or finishes.
function M.cancel_ad_input(self)
	require("game.modules.player.player_input").cancel_active_controls()
	M.cancel_ui_input(self)
end

---Apply the effective time factor to the gameplay collection.
---@param self table
function M.apply_world_factor(self)
	self.app.world_time_factor = self.time:get_factor()
	if self.app.screen ~= "gameplay" then return end
	-- Monarch timestep changes are disabled for gameplay. Apply the combined pause and tutorial factor here.
	local transition_needs_time = self.active_transition
		and not self.active_transition.freeze_gameplay
	local factor = transition_needs_time and 1 or self.app.world_time_factor
	if factor ~= self.applied_world_factor then
		self.applied_world_factor = factor
		msg.post(addresses.GAMEPLAY_PROXY, "set_time_step", { factor = factor, mode = 0 })
	end
end

---Update layout and pointer projection after a window resize.
---@param self table
---@param data table
function M.handle_resize(self, data)
	local viewport = {
		width = data.width or 0,
		height = data.height or 0,
	}
	-- Ready flags are cleared as soon as a collection starts unloading.
	if self.is_gameplay_ready then
		msg.post(addresses.GAMEPLAY_CAMERA, "viewport_resized", viewport)
		msg.post(addresses.GAMEPLAY_HUD, "viewport_resized", viewport)
	elseif self.is_mothership_ready then
		msg.post(addresses.MOTHERSHIP_CONTROLLER, "viewport_resized", viewport)
	end
end

return M
