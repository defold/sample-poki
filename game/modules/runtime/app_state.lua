-- Tracks the current screen, mission phase and reasons gameplay is paused.
local M = {}

local poki_service = require("app.modules.platform.poki_service")
local app_context = require("common.app_context")
local music = require("game.modules.audio.music")
local gameplay = require("game.modules.runtime.gameplay")
local addresses = require("common.addresses")
local client = require("common.audio.client")

local POPUP_FOR_PHASE = { PREPLAY = "none", PLAYING = "none",
	MOTHERSHIP = "none", PAUSED = "pause", RESULT = "result" }

---Set the phase and its pause flags. Existing ad, focus and popup blocks stay active.
---Call sync() after the remaining screen changes are ready.
function M.enter(self, phase, options)
	options = options or {}
	self.app.phase = phase
	self.app.is_awaiting_resume = options.await_input == true
	self.ui.popup = POPUP_FOR_PHASE[phase]
	assert(self.ui.popup, "unknown session phase: " .. tostring(phase))
	if options.screen then self.app.screen = options.screen end
	self.time:set_blocks({
		await_input = phase == "PREPLAY" or self.app.is_awaiting_resume,
		pause = phase == "PAUSED" or options.keep_paused == true,
		result = phase == "RESULT",
	})
end

---Wait for a new press before continuing with the current mission phase.
function M.await_input(self, is_enabled)
	self.app.is_awaiting_resume = is_enabled == true
	self.time:set_block("await_input", is_enabled)
end

---Block input during a screen transition. Callbacks use the returned token to check that it is still current.
function M.begin_transition(self, options)
	options = options or {}
	local token = { freeze_gameplay = options.freeze_gameplay == true, destination = options.destination }
	self.active_transition = token
	self.app.phase = "TRANSITION"
	gameplay.set_input_blocker(self, true)
	self.time:set_block("transition", true)
	return token
end

function M.is_transition(self, token)
	return token ~= nil and self.active_transition == token
end

---Finish only the matching transition. Ignore callbacks from earlier transitions.
function M.finish_transition(self, token)
	if not M.is_transition(self, token) then return false end
	self.active_transition = nil
	self.time:set_block("transition", false)
	gameplay.set_input_blocker(self, false)
	return true
end

---After a successful rescue, gameplay remains paused while Result closes.
function M.begin_rescue(self)
	self.pending_result = nil
	self.pause_reason = "rewarded_rescue"
	self.ui.popup = "none"
	self.time:set_block("pause", true)
	return M.begin_transition(self, { freeze_gameplay = true })
end

---Send the level-start measurement once per run, including across pauses and rescues.
function M.measure_start(self, run)
	if not run or run ~= self.current_run or run.is_start_measured then return end
	run.is_start_measured = true
	poki_service.measure("level", string.format("mission_%02d", run.level_id), "start")
end

---Check whether this run can accept input using the current screen, pause and ad state.
function M.can_accept_input(self, run_id)
	return self ~= nil and self.current_run ~= nil and self.current_run.run_id == run_id
		and self.is_gameplay_ready and self.app.screen == "gameplay"
		and (self.app.phase == "PREPLAY" or self.app.phase == "PLAYING")
		and (not self.time:has_block("pause") or self.app.is_awaiting_resume)
		and not self.active_transition and not self.ui.is_blocked
		and not poki_service.get_state().is_ad_busy
		and not self.time:has_block("modal") and not self.time:has_block("focus_loss")
		and not self.time:has_block("result") and not self.time:has_block("ad")
end

---Start or resume immediately so the same input can move the ship or fire.
function M.start_on_input(self, run_id, mode)
	if not M.can_accept_input(self, run_id) then return false end
	if self.app.phase == "PLAYING" and not self.app.is_awaiting_resume then return true end
	local first_start = self.app.phase == "PREPLAY"
	local rescued = self.pause_reason == "rewarded_rescue"
	M.enter(self, "PLAYING")
	self.pause_reason = nil
	self.app.input_mode = mode or self.app.input_mode

	local platform = poki_service.get_state()
	local accepted = true
	if not platform.has_started_once then
		accepted = poki_service.start_on_first_input("first_input")
	elseif not platform.is_playing then
		accepted = poki_service.gameplay_start("resume_input")
	end
	if not accepted then
		M.await_input(self, true)
		M.sync(self)
		return false
	end
	if not M.can_accept_input(self, run_id) then return false end
	if first_start then
		M.measure_start(self, self.current_run)
		client.play("ui_confirm")
	end
	if rescued then
		msg.post(addresses.GAMEPLAY_HUD, "pause_visibility", { paused = false })
	end
	msg.post(addresses.GAMEPLAY_HUD, "rescue_feedback_done")
	M.sync(self)
	gameplay.apply_world_factor(self)
	return true
end

---Update gameplay input flags, music and the app context read by UI listeners.
function M.sync(self)
	gameplay.sync_input(self, M)
	music.sync_music(self)
	local pending = self.pending_result or self.last_result
	app_context.publish({
		screen = self.app.screen, phase = self.app.phase, popup = self.ui.popup,
		is_paused = self.time:has_block("pause"), pause_reason = self.pause_reason,
		is_awaiting_resume = self.app.is_awaiting_resume == true,
		result_status = pending and pending.status,
		input_mode = self.app.input_mode, device_category = self.app.device_category,
		is_blocked = self.ui.is_blocked == true, is_ad_busy = poki_service.get_state().is_ad_busy,
	})
end

---Apply a reported input-mode change to app state and UI.
---@param self table
---@param message table
function M.on_input_mode(self, message)
	if self.app.input_mode == message.mode then return end
	self.app.input_mode = message.mode
	if self.is_gameplay_ready then
		msg.post(addresses.GAMEPLAY_HUD, "input_mode", { mode = message.mode })
		msg.post(addresses.GAMEPLAY_CONTROLLER, "input_mode", { mode = message.mode })
	end
	M.sync(self)
end

return M
