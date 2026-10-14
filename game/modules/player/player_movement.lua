-- Animates player movement, damage reactions and transitions.
local M = {}

local math_utils = require("common.math_utils")
local view_config = require("game.modules.mission.presentation.view_config")

local PLAYER = "/player"

---Restore the ship's neutral visual pose.
---@param self table
function M.reset_pose(self)
	go.cancel_animations(PLAYER)
	go.set_position(vmath.vector3(0, -0.07, view_config.PLAYER_Z), PLAYER)
	go.set_rotation(view_config.BANK_NEUTRAL, PLAYER)
	go.animate(PLAYER, "position.y", go.PLAYBACK_LOOP_PINGPONG,
		0.07, go.EASING_INOUTSINE, math.pi / 2.1)
	self.movement_target = nil
	self.movement_speed = nil
	self.bank = 0
	self.player_x = 0
end

---Add a brief recoil impulse after firing.
---@param self table
function M.kick(self)
	go.cancel_animations(PLAYER, "position.z")
	go.set(PLAYER, "position.z", view_config.PLAYER_Z)
	go.animate(PLAYER, "position.z", go.PLAYBACK_ONCE_PINGPONG,
		view_config.PLAYER_Z + 0.1, go.EASING_OUTQUAD, 0.1)
end

---Ease ship position and recoil toward their targets.
---@param self table
---@param dt number
function M.update_movement(self, dt)
	local position = go.get_position(PLAYER)
	self.player_x = position.x
	self.stick_age = (self.stick_age or 0) + (dt or 0)
	if self.stick_age > 0.15 then self.stick_axis = 0 end
	local digital = (self.right_value or 0) - (self.left_value or 0)
		+ (self.pad_right_value or 0) - (self.pad_left_value or 0)
	local axis = math_utils.clamp(digital ~= 0 and digital
		or ((self.virtual_axis or 0) ~= 0 and self.virtual_axis or (self.stick_axis or 0)), -1, 1)
	local target, speed
	if math.abs(axis) > 0.01 then
		self.is_pointer_steering = false
		target = axis < 0 and -view_config.CORRIDOR_HALF_WIDTH or view_config.CORRIDOR_HALF_WIDTH
		speed = self.state.move_speed * math.abs(axis)
	elseif self.is_pointer_steering then
		target = math_utils.clamp(self.target_x, -view_config.CORRIDOR_HALF_WIDTH, view_config.CORRIDOR_HALF_WIDTH)
		speed = view_config.POINTER_FOLLOW_SPEED
	end

	if target ~= self.movement_target or speed ~= self.movement_speed then
		go.cancel_animations(PLAYER, "position.x")
		self.movement_target, self.movement_speed = target, speed
		if target and math.abs(target - position.x) > 0.001 then
			go.animate(PLAYER, "position.x", go.PLAYBACK_ONCE_FORWARD,
				target, go.EASING_LINEAR, math.abs(target - position.x) / speed)
		end
	end

	local bank = target and math.abs(target - position.x) > 0.001
		and (target < position.x and -1 or 1) or 0
	if bank ~= self.bank then
		self.bank = bank
		go.animate(PLAYER, "rotation", go.PLAYBACK_ONCE_FORWARD,
			bank < 0 and view_config.BANK_LEFT
				or (bank > 0 and view_config.BANK_RIGHT or view_config.BANK_NEUTRAL),
			go.EASING_OUTQUAD, 0.12)
	end
end

return M
