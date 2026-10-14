-- Reads gameplay controls and translates them into player actions.
local M = {}

local mode = require("common.input.mode")
local axis = require("common.input.axis")
local held_actions = require("common.input.held_actions")
local pointer_guard = require("common.input.pointer_guard")
local player_aim = require("game.modules.player.player_aim")
local view_config = require("game.modules.mission.presentation.view_config")
local actions = require("common.input.actions")
local addresses = require("common.addresses")
local ad_state = require("common.ad_state")

local active = setmetatable({}, { __mode = "v" })

local STICK_DEADZONE = 0.25

local function apply_pointer_target(self, action)
	self.target_x = player_aim.get_pointer_target(action)
	self.is_pointer_steering = true
end

---Check input permission immediately, including while focus messages are still queued.
function M.is_blocked(self)
	return self.is_input_locked or ad_state.is_busy()
		or not active.app or not active.session.can_accept_input(active.app, self.run and self.run.run_id)
end

---Start or resume the mission when the player presses a control, then apply movement or fire.
function M.begin_play_on_input(self, action)
	if M.is_blocked(self) or self.phase == view_config.PHASE_RESULT then return false end
	if action and (not action.pressed or action.repeated) then return false end
	if not self.is_awaiting_input and self.phase ~= view_config.PHASE_PREPLAY then return false end
	return active.session.start_on_input(active.app, self.run.run_id, self.input_mode)
end

---Copy the app's pause state to the active controller and clear controls when play stops.
---The gameplay script updates sound and HUD state when it receives refresh_playback.
function M.sync_session(app, session)
	active.app = app
	active.session = session
	local self = active.controller
	if not self or not self.run then return end
	local allowed = active.session.can_accept_input(app, self.run.run_id) == true
	local awaiting = allowed and (app.app.phase == "PREPLAY" or app.app.is_awaiting_resume == true)
	local playing = allowed and not awaiting and app.app.phase == "PLAYING"
	if self.is_input_locked == not allowed and self.is_awaiting_input == awaiting
		and self.is_playing == playing then return end
	if not playing then M.reset_controls(self) end
	self.is_input_locked = not allowed
	self.is_awaiting_input = awaiting
	self.is_playing = playing
	if playing then self.phase = view_config.PHASE_PLAYING end
	msg.post(addresses.GAMEPLAY_CONTROLLER, "refresh_playback")
end

-- Defold sends active buttons every frame, not just pressed/released edges.
-- true means held input was received this frame. false means waiting for the next held sample.
-- After input is cancelled or interrupted, the player must press the control again.
function M.sample_fire(self, source, held, pressed)
	self.fire_sources = self.fire_sources or {}
	if not held or (not M.is_blocked(self) and self.is_playing and not self.is_awaiting_input) then
		held_actions.sample(self.fire_sources, source, held, pressed)
	end
end

function M.is_fire_held(self)
	return held_actions.any(self.fire_sources or {})
end

-- Run after all fixed updates, even when there were none this frame.
-- Held fire must receive another input sample to stay active next frame.
function M.finish_frame(self)
	local sources = self.fire_sources or {}
	if sources.pointer ~= true then
		self.is_pointer_down = false
		self.is_pointer_steering = false
		self.is_pointer_fire_only = false
	end
	held_actions.finish_frame(sources)
end

local function is_touch_steering(self)
	return self.input_mode == mode.TOUCH
		or self.device_category == "mobile" or self.device_category == "tablet"
end

---Apply the player's movement input. The player must press a control again to start or resume the mission.
---@param self table
---@param action_id hash
---@param action table
function M.handle_move(self, action_id, action)
	if M.is_blocked(self) then
		return
	end
	if self.is_virtual_controls_visible and (action_id == nil
		or actions.is_pointer(action_id)) then
		return
	elseif action_id == nil then
		if self.is_pointer_down and not self.is_pointer_fire_only then
			apply_pointer_target(self, action)
		end
	elseif action_id == actions.move_left then
		self.is_pointer_steering = false
		self.left_value = action.released and 0 or (action.pressed and 1 or self.left_value)
		if action.pressed then
			self.is_directional_steering = true
			if self.is_pointer_down then self.is_pointer_fire_only = true end
			M.begin_play_on_input(self, action)
		end
	elseif action_id == actions.move_right then
		self.is_pointer_steering = false
		self.right_value = action.released and 0 or (action.pressed and 1 or self.right_value)
		if action.pressed then
			self.is_directional_steering = true
			if self.is_pointer_down then self.is_pointer_fire_only = true end
			M.begin_play_on_input(self, action)
		end
	elseif action_id == actions.pad_left or action_id == actions.pad_right then
		self.is_pointer_steering = false
		local value = action.released and 0 or (action.pressed and 1 or nil)
		if action_id == actions.pad_left then
			self.pad_left_value = value or self.pad_left_value
		else
			self.pad_right_value = value or self.pad_right_value
		end
		if action.pressed then
			self.is_directional_steering = true
			if self.is_pointer_down then self.is_pointer_fire_only = true end
			M.begin_play_on_input(self, action)
		end
	elseif action_id == actions.stick_left or action_id == actions.stick_right then
		local strength = action.released and 0 or axis.strength(action.value, STICK_DEADZONE)
		local direction = action_id == actions.stick_left and -1 or 1
		-- Ignore the release for the previous direction if the player has already pushed the stick in the opposite direction.
		if strength > 0 or self.stick_axis == nil or self.stick_axis * direction >= 0 then
			self.stick_axis = direction * strength
			self.stick_age = 0
		end
		if strength > 0 then
			self.is_pointer_steering = false
			self.is_directional_steering = true
			if self.is_pointer_down then self.is_pointer_fire_only = true end
			if action.pressed then
				M.begin_play_on_input(self, action)
			end
		end
	elseif action_id == actions.touch then
		if is_touch_steering(self) and not self.is_pointer_down then return end
		local just_pressed = action.pressed and not action.repeated and not self.is_pointer_down
		if just_pressed then
			self.is_pointer_down = true
			self.is_pointer_fire_only = self.is_directional_steering and not is_touch_steering(self)
			if not self.is_pointer_fire_only then
				apply_pointer_target(self, action)
			end
			M.begin_play_on_input(self, action)
			self.is_fire_pending = true
		end
		M.sample_fire(self, "pointer", not action.released
			and (action.pressed or (action.value or 0) > 0), just_pressed)
		if action.released then
			self.is_pointer_down = false
			self.is_pointer_fire_only = false
			self.is_pointer_steering = false
		end
		if self.is_pointer_down and not self.is_pointer_fire_only then
			apply_pointer_target(self, action)
		end
	end
end

---Register the active controller and choose its initial input mode.
---@param self table
---@param screen_data table
function M.init(self, screen_data)
	active.controller = self
	self.device_category = screen_data and screen_data.device_category or "desktop"
	self.input_mode = screen_data and screen_data.input_mode ~= ""
		and screen_data.input_mode or mode.initial_mode(self.device_category)
end

---Initialize pointer controls and filter mouse events generated by touch.
---@param self table
function M.init_pointer_guards(self)
	self.pointer_guard = pointer_guard.new()
	self.is_virtual_controls_visible = false
	self.virtual_axis = 0
	self.is_pointer_steering = false
	self.is_directional_steering = false
	self.is_pointer_fire_only = false
end

---Clear held controls when input is interrupted and keep the ship at its current position.
---@param self table
function M.reset_controls(self)
	self.left_value = 0
	self.right_value = 0
	self.pad_left_value = 0
	self.pad_right_value = 0
	self.stick_axis = 0
	self.stick_age = 0
	self.is_pointer_steering = false
	self.is_pointer_down = false
	self.is_directional_steering = false
	self.is_pointer_fire_only = false
	self.fire_sources = {}
	self.is_fire_pending = false
	self.virtual_axis = 0
end

-- Reset all inputs after ad.
function M.cancel_active_controls()
	if active.controller then M.reset_controls(active.controller) end
end

function M.detach(self)
	if active.controller == self then active.controller = nil end
end

-- Apply touch fire directly, just like keyboard and mouse input.
-- Queuing it with msg.post could delay the shot until after a fixed update.
function M.virtual_fire(held, pressed)
	local self = active.controller
	if not self then return end
	if not held then
		M.sample_fire(self, "virtual", false)
		if not pressed then return end
	end
	if M.is_blocked(self) then return end
	if pressed then
		M.begin_play_on_input(self)
	end
	M.sample_fire(self, "virtual", held, pressed)
	if pressed and self.is_playing and not self.is_awaiting_input then
		self.is_fire_pending = true
	end
end

---Touch steering follows the same synchronous path as keyboard movement.
function M.virtual_steer(axis, pressed)
	local self = active.controller
	if not self or M.is_blocked(self) then return end
	if pressed then M.begin_play_on_input(self) end
	if not self.is_playing then return end
	self.virtual_axis = axis or 0
	if self.virtual_axis ~= 0 then self.is_pointer_steering = false end
end

---Center the ship and clear controls when resetting a run.
function M.reset_move_state(self)
	self.player_x = 0
	self.target_x = 0
	M.reset_controls(self)
end

local function route_inactive_input(self, action_id, action)
	if self.phase == view_config.PHASE_RESULT then
		if actions.is_touch(action_id) or action_id == actions.touch_multi
			or action_id == actions.primary or action_id == actions.rewarded
			or action_id == actions.cancel then return "pass" end
		return "consumed"
	end
	if self.is_input_locked then
		if action.pressed and (action_id == actions.cancel or action_id == actions.primary) then
			return "pause_locked"
		end
		return "pass"
	end
end

local function handle_primary(self, action_id, action)
	if action_id ~= actions.primary then return end
	local pressed = action.pressed and not action.repeated
	if pressed then
		M.begin_play_on_input(self, action)
	end
	-- Keyboard and each gamepad are independent, even with the same action id.
	M.sample_fire(self, action.gamepad or "primary", not action.released
		and (pressed or (action.value or 0) > 0), pressed)
	if pressed then
		return self.is_awaiting_input and "consumed" or "fire"
	end
end

---Classify and, when allowed, apply movement and fire.
---Returns:
---`"reset_save"`, `"pause"`, `"fire"`, `"pass"` (let the action continue down the stack), or `"consumed"`.
---@param self table
---@param action_id hash
---@param action table
---@return 'reset_save'|'pause'|'fire'|'pass'|'consumed'|string
function M.process(self, action_id, action)
	-- Releases must clear controls even during pointer suppression or UI focus.
	if action.released then
		if action_id == actions.touch then
			self.is_pointer_down = false
			self.is_pointer_steering = false
			self.is_pointer_fire_only = false
			M.sample_fire(self, "pointer", false)
		elseif action_id == actions.primary then
			M.sample_fire(self, action.gamepad or "primary", false)
		end
	end
	if ad_state.is_busy() then
		M.reset_controls(self)
		return "consumed"
	end
	if action_id == actions.reset_save and action.pressed then
		return "reset_save"
	end
	local wall_now = socket.gettime()
	if pointer_guard.is_blocked(self.pointer_guard, action_id, wall_now) then
		return "consumed"
	end
	local inactive_result = route_inactive_input(self, action_id, action)
	if inactive_result then return inactive_result end
	if M.is_blocked(self) then
		M.reset_controls(self)
		return "consumed"
	end
	M.handle_move(self, action_id, action)
	local primary_result = handle_primary(self, action_id, action)
	if primary_result then return primary_result end
	if action_id == actions.cancel and action.pressed then
		return "pause"
	end
	if self.is_fire_pending then
		self.is_fire_pending = false
		if self.is_awaiting_input then
			return "consumed"
		end
		return "fire"
	end
	return "consumed"
end

return M
