-- Starts and resets mission runs and routes their runtime events.
local M = {}

local config = require("game.modules.rules.config")
local mission_state = require("game.modules.rules.mission_state")
local spawn_plan = require("game.modules.rules.spawn_plan")
local combat_runtime = require("game.modules.mission.combat_runtime")
local player_input = require("game.modules.player.player_input")
local player_movement = require("game.modules.player.player_movement")
local ship_visual = require("game.modules.player.ship_visual")
local feedback_events = require("game.modules.mission.presentation.feedback_events")
local view_config = require("game.modules.mission.presentation.view_config")
local addresses = require("common.addresses")

local HUD_URL = addresses.GAMEPLAY_HUD
local APP_URL = addresses.APP_CONTROLLER

---Replace mission state and clear presentation from the previous run.
---@param self table
---@param run table
function M.reset_run(self, run)
	self.run = run
	self.state = mission_state.new(run.level_id, run.seed, run.ship_stats)
	self.phase = view_config.PHASE_PREPLAY
	self.is_playing = false
	self.is_input_locked = false
	self.is_awaiting_input = false
	player_input.reset_move_state(self)
	self.fire_timer = 0
	ship_visual.apply("/player",
		run.ship_stats.id or "scout", run.skin_id or "standard")
	self.pickup_plan = spawn_plan.build_pickups(run.level_id, run.seed)
	self.next_pickup = 1
	player_movement.reset_pose(self)
	combat_runtime.clear_objects(self)
	if self.is_feedback_ready then
		feedback_events.run_reset:trigger({ ship_id = run.ship_stats.id or "scout" })
		self:set_engine_playing(self.is_playing)
	else
		self.is_engine_audio_playing = self.is_playing
	end
	combat_runtime.activate_due_spawns(self)
	msg.post(HUD_URL, "phase", {
		phase = self.phase,
		level = self.state.level_id,
	})
	self:publish_hud_state()
end

---Provide default mission data for collection previews that have no Monarch screen data.
---@return table
function M.default_run()
	return {
		run_id = "development-run",
		level_id = 1,
		seed = 28,
		ship_stats = config.SHIPS.scout,
		skin_id = "standard",
	}
end

---Post a mission result once its state has resolved.
---@param self table
function M.finish_if_needed(self)
	local status = mission_state.resolve(self.state)
	if not status then
		return
	end
	self.phase = view_config.PHASE_RESULT
	self.is_playing = false
	self.is_input_locked = true
	local is_rescue_available = not self.state.is_rescue_used
		and (status == config.STATUS.FAIL_HEALTH or status == config.STATUS.FAIL_AMMO)
	-- Send the final counts before freezing gameplay so the HUD can mark both objective counters complete.
	self:publish_hud_state()
	msg.post(HUD_URL, "phase", {
		phase = self.phase,
		status = status,
	})
	msg.post(APP_URL, "mission_result", {
		run_id = self.run.run_id,
		status = status,
		level_id = self.state.level_id,
		rescue_available = is_rescue_available,
	})
end

---Restore a failed run after an approved rewarded rescue.
---@param self table
---@param message table
function M.apply_rescue(self, message)
	local result = { success = false, reason = "wrong_run" }
	if message.run_id == self.run.run_id and self.phase == view_config.PHASE_RESULT then
		result = mission_state.rescue(self.state, message.kind)
		if result.success then
			self.phase = view_config.PHASE_PLAYING
			self.is_playing = false
			-- Keep input blocked while Result closes. The app will then wait for a new press.
			self.is_input_locked = true
			self.is_awaiting_input = true
			self:set_engine_playing(false)
			msg.post(HUD_URL, "phase", { phase = view_config.PHASE_PLAYING })
			self:publish_hud_state()
		end
	end
	msg.post(APP_URL, "rescue_applied", {
		run_id = self.run.run_id,
		kind = message.kind or "",
		transaction_id = message.transaction_id or "",
		success = result.success,
		reason = result.success and "" or result.reason,
	})
end

return M
