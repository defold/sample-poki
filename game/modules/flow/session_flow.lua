-- Resets saved progress and handles events from the active mission.
local M = {}

local poki_service = require("app.modules.platform.poki_service")
local progress = require("game.modules.profile.progress")
local settings_flow = require("game.modules.flow.settings_flow")
local addresses = require("common.addresses")
local gameplay = require("game.modules.runtime.gameplay")
local tutorials = require("game.modules.runtime.tutorials")
local app_state = require("game.modules.runtime.app_state")
local screen_flow = require("game.modules.flow.screen_flow")
local client = require("common.audio.client")

---Clear saved progress after an explicit reset request.
---@param self table
---@return boolean
function M.reset_saved_progress(self)
	if self.is_resetting or self.active_transition or self.is_rewarded_pending
		or poki_service.get_state().is_ad_busy then
		return false
	end
	self.is_resetting = true
	if poki_service.get_state().is_playing then
		poki_service.gameplay_stop("save_reset")
	end

	self.pending_language = nil
	local profile = progress.reset_profile()

	self.last_result = nil
	self.pending_result = nil
	self.pending_skin_reward = nil
	self.is_rewarded_pending = false
	tutorials.create_time_controller(self)

	self.app.language = profile.language
	self.app.is_muted = profile.is_muted == true
	client.set_muted(self.app.is_muted)
	app_state.enter(self, "PREPLAY")
	if self.is_gameplay_ready then msg.post(addresses.GAMEPLAY_HUD, "hide_tutorial") end

	local run = progress.start_run(1, 28)
	if not run then
		self.is_resetting = false
		return false
	end
	if self.app.screen == "gameplay" and self.is_gameplay_ready then
		self.current_run = run
		gameplay.set_input_blocker(self, false)
		gameplay.apply_world_factor(self)
		msg.post(addresses.GAMEPLAY_CONTROLLER, "reset_run", {
			run_id = run.run_id,
			level_id = run.level_id,
			seed = run.seed,
			health = run.ship_stats.health,
			ammo = run.ship_stats.ammo,
			damage = run.ship_stats.damage,
			fire_cooldown = run.ship_stats.fire_cooldown,
			move_speed = run.ship_stats.move_speed,
		})
	else
		screen_flow.show_gameplay(self, run)
	end
	client.play("ui_confirm")
	settings_flow.propagate_language(self)
	self.is_resetting = false
	return true
end

---Handle the save-reset request.
---@param self table
function M.on_reset_save_requested(self)
	M.reset_saved_progress(self)
end

---Dispatch a gameplay event to the relevant flow.
---@param self table
---@param message table
function M.on_game_event(self, message)
	local event_id = message.id
	if event_id == "target_destroyed" then
		progress.record_target_destroyed(message.run_id,
			message.target_id, message.credit_bonus)
	end
	local tutorial_id = tutorials.TUTORIAL_FOR_EVENT[event_id]
	if event_id == "tutorial_trigger" then
		tutorial_id = message.tutorial_id
	end
	if tutorial_id then
		tutorials.enqueue_tutorial(self, tutorial_id)
	end
end

return M
