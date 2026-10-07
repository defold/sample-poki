-- Opens and closes app screens through the screen navigation system.
local M = {}

local monarch = require("monarch.monarch")
local poki_service = require("app.modules.platform.poki_service")
local progress = require("game.modules.profile.progress")
local addresses = require("common.addresses")
local gameplay = require("game.modules.runtime.gameplay")
local app_state = require("game.modules.runtime.app_state")
local shop_payload = require("game.modules.shop.shop_payload")
local client = require("common.audio.client")

local DEFERRED_PACKS = { "fa", "cyrillic", "cjk", "audio" }

---Keep the loaded mission in preplay until the player presses a control.
---@param self table
function M.activate_loaded_gameplay(self)
	if not self.is_gameplay_ready or self.active_transition or self.app.phase ~= "TRANSITION" then
		return
	end
	app_state.enter(self, "PREPLAY", { screen = "gameplay" })
	app_state.sync(self)
end

---Transition to a mission screen for the given run.
---@param self table
---@param run table
function M.show_gameplay(self, run)
	self.current_run = run
	self.pending_result = nil
	self.is_rewarded_pending = false
	gameplay.cancel_ui_input(self)
	self.is_gameplay_ready = false
	self.is_mothership_ready = false
	local transition = app_state.begin_transition(self)
	app_state.await_input(self, false)
	self.time:set_blocks({ await_input = true, result = false })
	app_state.sync(self)
	monarch.show(addresses.SCREEN_GAMEPLAY, { clear = true, sequential = true }, {
		run = run,
		input_mode = "",
		device_category = poki_service.get_device_category(),
	}, function()
		if not app_state.finish_transition(self, transition) then return end
		M.activate_loaded_gameplay(self)
	end)
end

local function activate_loaded_mothership(self)
	if not self.is_mothership_ready or self.active_transition then return end
	app_state.enter(self, "MOTHERSHIP", { screen = "mothership" })
	-- The initial offers came through Monarch data. Only unlock the controls now.
	msg.post(addresses.MOTHERSHIP_GUI, "mothership_transition", { transitioning = false })
end

---Return to the mothership and refresh its progress payload.
---@param self table
function M.show_mothership(self)
	self.pending_skin_reward = nil
	self.is_rewarded_pending = false
	gameplay.cancel_ui_input(self)
	self.is_mothership_ready = false
	self.is_gameplay_ready = false
	self.ui.popup = "none"
	local transition = app_state.begin_transition(self, { freeze_gameplay = true })
	app_state.sync(self)
	local payload = shop_payload.build(self)
	gameplay.apply_world_factor(self)
	monarch.show(addresses.SCREEN_MOTHERSHIP, { clear = true, sequential = true }, payload, function()
		if not app_state.finish_transition(self, transition) then return end
		activate_loaded_mothership(self)
		app_state.sync(self)
	end)
end

---Request a commercial break before opening the next mission.
---@param self table
---@return boolean
function M.begin_next_run(self)
	if self.active_transition or self.app.screen ~= "mothership" then
		return false
	end
	local next_level = shop_payload.get_next_level(self)
	local run = progress.start_run(next_level)
	if not run then
		return false
	end

	local transition = app_state.begin_transition(self, { destination = "gameplay" })
	msg.post(addresses.MOTHERSHIP_GUI, "mothership_transition", { transitioning = true })

	local function continue_to_mission()
		if not app_state.is_transition(self, transition) then return end
		M.show_gameplay(self, run)
	end
	local placement = string.format("mission_continue_%02d", run.level_id)
	if not poki_service.commercial_break({ placement = placement }, continue_to_mission) then
		continue_to_mission()
	end
	app_state.sync(self)
	return true
end

---Start the saved or first mission at app launch.
---@param self table
function M.show_initial(self)
	local level_id = progress.snapshot().mission or 1
	-- Keep the first mission's tutorial layout consistent.
	local run = progress.start_run(level_id, level_id == 1 and 28 or nil)
	assert(run, "Cannot start mission " .. tostring(level_id))
	M.show_gameplay(self, run)
end

---Handle a screen's ready message and send its initial device, input and timing settings.
---@param self table
---@param message table
function M.on_screen_ready(self, message)
	if message.screen == "gameplay" then
		if not self.current_run or message.run_id ~= self.current_run.run_id then
			return
		end
		self.is_gameplay_ready = true
		self.applied_world_factor = nil
		self.is_mothership_ready = false
		self.app.screen = "gameplay"
		local category = poki_service.get_device_category()
		self.app.device_category = category
		if self.input_tracker then
			self.input_tracker:set_device_category(category)
			self.app.input_mode = self.input_tracker:get_mode()
		end
		if not self.is_pill_configured and poki_service.is_poki_available() then
			self.is_pill_configured = poki_service.move_pill(0, 24) == true
		end
		msg.post(addresses.GAMEPLAY_CONTROLLER, "device_category", { category = category })
		-- Give the newly loaded HUD and controller the input mode already selected by the app.
		msg.post(addresses.GAMEPLAY_HUD, "input_mode", { mode = self.app.input_mode })
		msg.post(addresses.GAMEPLAY_CONTROLLER, "input_mode", { mode = self.app.input_mode })
		-- One Defold ZIP serves every excluded collection.
		-- Request all proxies once the first gameplay screen is ready.
		self.deferred_assets:request_many(DEFERRED_PACKS)
		gameplay.apply_world_factor(self)
		M.activate_loaded_gameplay(self)
	elseif message.screen == "mothership" then
		self.is_mothership_ready = true
		self.is_gameplay_ready = false
		self.app.screen = "mothership"
		activate_loaded_mothership(self)
		app_state.sync(self)
	end
end

---Begin the mission selected from the mothership.
---@param self table
function M.on_mothership_continue(self)
	if not self.active_transition and not self.time:has_block("pause")
		and self.app.screen == "mothership" then
		client.play("ui_confirm")
		M.begin_next_run(self)
	end
end

return M
