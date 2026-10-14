-- Handles mission results and the optional rewarded rescue path.
local M = {}

local monarch = require("monarch.monarch")
local poki_service = require("app.modules.platform.poki_service")
local progress = require("game.modules.profile.progress")
local addresses = require("common.addresses")
local gameplay = require("game.modules.runtime.gameplay")
local app_state = require("game.modules.runtime.app_state")
local pause_flow = require("game.modules.flow.pause_flow")
local screen_flow = require("game.modules.flow.screen_flow")
local rewarded = require("game.modules.flow.rewarded")
local client = require("common.audio.client")

local function rescue_kind_for_status(status)
	if status == "fail_health" then
		return "health"
	elseif status == "fail_ammo" then
		return "ammo"
	end
	return nil
end

local function finalize_pending_result(self)
	local message = self.pending_result
	local run = self.current_run
	if not message or not run or message.run_id ~= run.run_id or run.is_finished then
		return false
	end
	local outcome = progress.finish_run(message.run_id, message.status)
	local result = outcome.success and outcome or outcome.previous_result
	if not result then
		return false
	end
	run.is_finished = true
	self.pending_result = nil
	self.is_rewarded_pending = false
	self.last_result = result
	poki_service.measure("level", string.format("mission_%02d", result.level_id),
		result.status == "complete" and "complete" or "fail")
	app_state.sync(self)
	monarch.preload(addresses.SCREEN_MOTHERSHIP)
	return true
end

local function present_result_popup(self)
	local message = self.pending_result
	if not message or not self.current_run or message.run_id ~= self.current_run.run_id
		or self.current_run.is_finished then
		return
	end
	local rescue_kind = message.rescue_available and rescue_kind_for_status(message.status) or nil
	monarch.show(addresses.SCREEN_RESULT_POPUP, { sequential = true }, {
		run_id = message.run_id,
		status = message.status,
		rescue_available = rescue_kind ~= nil,
		rescue_kind = rescue_kind or "",
		input_mode = self.app.input_mode,
		device_category = self.app.device_category,
	}, function()
		gameplay.apply_world_factor(self)
	end)
	if not rescue_kind then
		finalize_pending_result(self)
	end
end

---Record a mission result and open its result screen.
---@param self table
---@param message table
function M.on_mission_result(self, message)
	if not self.current_run or message.run_id ~= self.current_run.run_id
		or self.current_run.is_finished
		or (self.pending_result and self.pending_result.run_id == message.run_id) then
		return
	end
	-- gameplay_stop immediately publishes a platform event and synchronizes the controller.
	-- Set RESULT first so that synchronization cannot restore PLAYING on the failed run.
	app_state.enter(self, "RESULT")
	if poki_service.get_state().is_playing then
		poki_service.gameplay_stop("mission_result")
	end
	self.pending_result = message
	local rescue_kind = message.rescue_available and rescue_kind_for_status(message.status) or nil
	if rescue_kind then
		poki_service.measure("rewarded", "rescue_" .. rescue_kind, "visible")
	end
	client.play(message.status == "complete" and "result_win" or "result_fail")
	app_state.sync(self)
	gameplay.cancel_ui_input(self)
	present_result_popup(self)
end

---Return to the mothership after a completed result.
---@param self table
function M.on_result_continue(self)
	if self.app.screen == "gameplay" and self.app.phase == "RESULT"
		and not self.active_transition and not self.is_rewarded_pending then
		client.play("ui_confirm")
		if finalize_pending_result(self)
			or (self.current_run and self.current_run.is_finished) then
			screen_flow.show_mothership(self)
		else
			client.play("ui_error")
			msg.post(addresses.POPUP_GUI.result, "result_continue_failed")
		end
	end
end

---Open a rescue offer for a failed mission.
---@param self table
---@param message table
function M.on_rewarded_offer_opened(self, message)
	local pending = self.pending_result
	if pending and message.run_id == pending.run_id and not self.is_rewarded_pending
		and rescue_kind_for_status(pending.status) == message.kind then
		rewarded.show(self, {
			popup = "rewarded_confirm",
			screen = addresses.SCREEN_REWARD_CONFIRM_POPUP,
			data = { run_id = pending.run_id, kind = message.kind },
		})
	end
end

---Decline rescue and return to the result screen.
---@param self table
function M.on_rewarded_cancel(self)
	if self.pending_result then
		rewarded.cancel(self, {
			apply = function(app)
				app.ui.popup = "result"
			end,
		})
	end
end

---Request a rescue ad after explicit confirmation.
---@param self table
---@param message table
function M.on_rewarded_confirm(self, message)
	local pending = self.pending_result
	local kind = pending and rescue_kind_for_status(pending.status) or nil
	if not pending or message.run_id ~= pending.run_id or message.kind ~= kind
		or self.is_rewarded_pending then
		return
	end
	rewarded.play(self, {
		screen = addresses.SCREEN_REWARD_CONFIRM_POPUP,
		placement = "rescue_" .. kind,
		pending_popup = "rewarded_pending",
		on_idle = function(app)
			app.ui.popup = "result"
			msg.post(addresses.POPUP_GUI.result, "rewarded_failed")
		end,
		on_claimed = function(result)
			msg.post(addresses.GAMEPLAY_CONTROLLER, "apply_rescue", {
				run_id = pending.run_id,
				kind = kind,
				transaction_id = result.transaction_id,
			})
		end,
	})
end

---Resume the saved run after a successful rescue.
---@param self table
---@param message table
function M.on_rescue_applied(self, message)
	local pending = self.pending_result
	if not pending or message.run_id ~= pending.run_id then
		return
	end
	if message.success then
		local transition = app_state.begin_rescue(self)
		app_state.sync(self)
		monarch.back({ sequential = true }, nil, function()
			if not app_state.finish_transition(self, transition) then return end
			pause_flow.resume_after_rescue(self)
			client.play("ui_confirm")
			msg.post(addresses.GAMEPLAY_HUD, "rescue_feedback", { kind = message.kind })
		end)
	else
		self.ui.popup = "result"
		client.play("ui_error")
		app_state.sync(self)
	end
end

return M
