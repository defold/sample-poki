-- Coordinates pausing, resuming and leaving a mission.
local M = {}

local monarch = require("monarch.monarch")
local poki_service = require("app.modules.platform.poki_service")
local addresses = require("common.addresses")
local gameplay = require("game.modules.runtime.gameplay")
local app_state = require("game.modules.runtime.app_state")
local client = require("common.audio.client")

local function can_pause_screen(self)
	return self.app.screen == "gameplay" or self.app.screen == "mothership"
end

local function sync_mothership_pause(self, is_paused)
	if self.is_mothership_ready then
		msg.post(addresses.MOTHERSHIP_GUI, "pause_visibility", { paused = is_paused == true })
	end
end

local function sync_gameplay_pause(self, is_paused, is_hud_paused)
	if not self.is_gameplay_ready then return end
	gameplay.sync_input(self, app_state)
	msg.post(addresses.GAMEPLAY_HUD, "pause_visibility",
		{ paused = is_paused == true or is_hud_paused == true })
end

local function complete_resume(self, phase, options)
	app_state.enter(self, phase, options)
	if not options.keep_paused then self.pause_reason = nil end
	self.time:set_block("focus_loss", self.has_lost_window_focus == true)
	sync_gameplay_pause(self, false, options.keep_paused)
	if not options.await_input then sync_mothership_pause(self, false) end
	-- Gameplay remains paused until the next input.
	gameplay.apply_world_factor(self)
	app_state.sync(self)
	return true
end

-- A pause restores the phase it interrupted.
local function arm_await_resume(self)
	local phase = self.phase_before_pause or "PLAYING"
	if phase ~= "PLAYING" and phase ~= "PREPLAY" then phase = "PLAYING" end
	return complete_resume(self, phase, { await_input = true })
end

---Keep the rescued mission paused until its popups close and the player presses a control.
---@param self table
---@return boolean
function M.resume_after_rescue(self)
	return complete_resume(self, "PLAYING", { await_input = true, keep_paused = true })
end

local function finish_resume(self)
	if not self.time:has_block("pause") then return false end
	if self.phase_before_pause == "PLAYING" and poki_service.get_state().has_started_once then
		return arm_await_resume(self)
	end
	-- PREPLAY must remain frozen until the first meaningful input as well.
	return complete_resume(self, self.phase_before_pause or "PREPLAY",
		{ await_input = self.phase_before_pause == "PREPLAY" })
end

local function begin_resume(self)
	if self.active_transition then
		return false
	end
	self.ui.popup = "none"
	local transition = app_state.begin_transition(self, { freeze_gameplay = true })
	gameplay.apply_world_factor(self)

	-- Resume only after the pause popup closes, any commercial break ends, and the player provides fresh input.
	local function after_pause_closed()
		if not app_state.is_transition(self, transition) then return end
		local function finish()
			if app_state.finish_transition(self, transition) then finish_resume(self) end
		end
		local run = self.current_run
		if self.app.screen == "gameplay" and self.phase_before_pause == "PLAYING"
			and run then
			local placement = string.format("pause_resume_%02d", run.level_id)
			if not poki_service.commercial_break({ placement = placement }, finish) then finish() end
		else
			finish()
		end
	end
	if monarch.is_top(addresses.SCREEN_CREDITS_POPUP) then
		monarch.back({ sequential = true }, nil, function()
			monarch.back({ sequential = true }, nil, after_pause_closed)
		end)
	else
		monarch.back({ sequential = true }, nil, after_pause_closed)
	end
	app_state.sync(self)
	return true
end

local function begin_pause(self, reason)
	self.phase_before_pause = self.app.phase
	self.pause_reason = reason or "pause"
	app_state.enter(self, "PAUSED")
	if poki_service.get_state().is_playing then
		poki_service.gameplay_stop(reason or "pause")
	end
	if self.is_gameplay_ready then
		sync_gameplay_pause(self, true)
	end
	sync_mothership_pause(self, true)
	gameplay.cancel_ui_input(self)
	monarch.show(addresses.SCREEN_PAUSE_POPUP, { sequential = true }, {
		input_mode = self.app.input_mode,
		device_category = self.app.device_category,
		muted = self.app.is_muted == true,
		language = self.app.language,
	}, function()
		gameplay.apply_world_factor(self)
		msg.post(addresses.POPUP_GUI.pause, "audio_state", { muted = self.app.is_muted == true })
		msg.post(addresses.POPUP_GUI.pause, "language_changed", { language = self.app.language })
	end)
	app_state.sync(self)
	return true
end

---Open Pause, or close it and wait for any resume ad to finish.
---@param self table
---@param is_paused boolean
---@param reason string
---@return boolean
function M.set_paused(self, is_paused, reason)
	if poki_service.get_state().is_ad_busy then return false end
	if not can_pause_screen(self) or is_paused == self.time:has_block("pause") then return false end
	if is_paused then
		if self.ui.popup ~= "none" and self.ui.popup ~= "pause" then return false end
		return begin_pause(self, reason)
	end
	return begin_resume(self)
end

---Pause for any popup above gameplay. Regaining focus still requires a new press.
---@param self table
---@param message table
function M.on_screen_focus(self, message)
	-- Focus is queued by Monarch before its completion/ad callback.
	-- Update the popup block even during an ad so it does not remain set after the ad ends.
	local ad_busy = poki_service.get_state().is_ad_busy
	if message.focused then
		local should_resume = self.time:has_block("modal") and self.app.phase == "PLAYING"
			and not self.time:has_block("pause") and not self.active_transition
		if should_resume then
			app_state.await_input(self, true)
		end
		self.time:set_block("modal", false)
		if not ad_busy and not self.active_transition
			and (not self.time:has_block("pause") or self.app.is_awaiting_resume) and not self.time:has_block("result")
			and (self.app.phase == "PLAYING" or self.app.phase == "PREPLAY") then
			sync_gameplay_pause(self, false)
		end
	elseif self.app.screen == "gameplay" then
		self.time:set_block("modal", true)
		if poki_service.get_state().is_playing then poki_service.gameplay_stop("modal") end
		sync_gameplay_pause(self, true)
	end
	app_state.sync(self)
end

---Pause the current screen when gameplay requests it.
---@param self table
function M.on_pause_requested(self)
	if self.active_transition or poki_service.get_state().is_ad_busy then
		return
	end
	if self.app.phase == "PLAYING" or self.app.phase == "PREPLAY"
		or self.app.phase == "MOTHERSHIP" then
		client.play("ui_click")
		M.set_paused(self, true, "pause_button")
	elseif self.app.phase == "PAUSED" then
		client.play("ui_confirm")
		M.set_paused(self, false, "resume_button")
	end
end

---Open credits above the pause screen.
---@param self table
function M.on_credits_open(self)
	if self.ui.popup ~= "pause" or self.active_transition then
		return
	end
	if monarch.is_top(addresses.SCREEN_CREDITS_POPUP) then
		return
	end
	client.play("ui_click")
	monarch.show(addresses.SCREEN_CREDITS_POPUP, { sequential = true }, {
		input_mode = self.app.input_mode,
		device_category = self.app.device_category,
	})
end

---Close credits and return to the pause controls.
---@param self table
function M.on_credits_close(self)
	if not monarch.is_top(addresses.SCREEN_CREDITS_POPUP) then
		return
	end
	client.play("ui_click")
	monarch.back({ sequential = true })
end

---Suspend gameplay and audio when the browser loses focus.
---@param self table
function M.on_focus_lost(self)
	-- Ad overlays emit WINDOW_EVENT_FOCUS_LOST when they close.
	-- The ad already blocks input and time. Adding a focus-loss block here
	-- could leave gameplay paused until the player clicks the canvas.
	if poki_service.get_state().is_ad_busy then return end
	self.has_lost_window_focus = true
	self.time:set_block("focus_loss", true)
	app_state.sync(self)
	if self.app.screen == "gameplay" and self.app.phase == "PLAYING"
		and not self.time:has_block("pause") then
		self.time:set_block("focus_loss", true)
		M.set_paused(self, true, "focus_lost")
	elseif self.app.screen == "mothership" and self.app.phase == "MOTHERSHIP"
		and not self.time:has_block("pause") then
		M.set_paused(self, true, "focus_lost")
	elseif self.app.screen == "gameplay" and self.app.phase == "PREPLAY" then
		self.time:set_block("focus_loss", true)
	end
end

---Clear the focus-loss block. Gameplay still waits for a new press.
---@param self table
---@param is_already_focused boolean
function M.on_focus_gained(self, is_already_focused)
	self.has_lost_window_focus = false
	self.time:set_block("focus_loss", false)
	if self.is_gameplay_ready and not is_already_focused then
		gameplay.cancel_ui_input(self)
	end
	if self.is_gameplay_ready and not self.active_transition and not poki_service.get_state().is_ad_busy
		and (not self.time:has_block("pause") or self.app.is_awaiting_resume)
		and (self.app.phase == "PLAYING" or self.app.phase == "PREPLAY") then
		sync_gameplay_pause(self, false)
	end
	app_state.sync(self)
end

return M
