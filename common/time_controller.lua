-- Applies and synchronizes gameplay time-step changes.
local M = {}

local math_utils = require("common.math_utils")

local SLOW_FACTOR = 0.18
local RAMP_DOWN = 0.10
local HOLD = 0.75
local RAMP_UP = 0.20
local TOTAL = RAMP_DOWN + HOLD + RAMP_UP

---@class starbreaker.time_controller
---@field factor number
---@field blocks table
---@field tutorial table|nil
---@field on_factor function|nil
---@field on_tutorial function|nil
local Controller = {}
Controller.__index = Controller

function Controller:_has_block()
	return next(self.blocks) ~= nil
end

function Controller:_tutorial_factor()
	if not self.tutorial then
		return 1
	end
	local elapsed = self.tutorial.elapsed
	if elapsed < RAMP_DOWN then
		return vmath.lerp(math_utils.clamp(elapsed / RAMP_DOWN, 0, 1), 1, SLOW_FACTOR)
	elseif elapsed < RAMP_DOWN + HOLD then
		return SLOW_FACTOR
	end
	return vmath.lerp(math_utils.clamp((elapsed - RAMP_DOWN - HOLD) / RAMP_UP, 0, 1), SLOW_FACTOR, 1)
end

function Controller:_set_factor(value)
	value = math_utils.clamp(value, 0, 1)
	if math.abs(value - self.factor) < 0.000001 then
		return false
	end
	self.factor = value
	if self.on_factor then
		self.on_factor(value)
	end
	return true
end

function Controller:_refresh()
	if self:_has_block() then
		self:_set_factor(0)
	else
		self:_set_factor(self:_tutorial_factor())
	end
end

---Add or remove a named reason to freeze simulation time.
---@param self starbreaker.time_controller
---@param reason string
---@param is_enabled boolean
---@return number
function Controller:set_block(reason, is_enabled)
	assert(type(reason) == "string" and reason ~= "", "block reason is required")
	if is_enabled then
		self.blocks[reason] = true
	else
		self.blocks[reason] = nil
	end
	self:_refresh()
	return self.factor
end

---Update related pause reasons together, then recalculate the time factor once.
function Controller:set_blocks(changes)
	for reason, is_enabled in pairs(changes) do
		self.blocks[reason] = is_enabled and true or nil
	end
	self:_refresh()
	return self.factor
end

function Controller:has_block(reason)
	return self.blocks[reason] == true
end

---Start one slow-motion tutorial cue unless another is active.
---@param self starbreaker.time_controller
---@param tutorial_id string
---@return boolean is_started
function Controller:start_tutorial(tutorial_id)
	if self.tutorial then
		return false
	end
	self.tutorial = { id = tutorial_id, elapsed = 0 }
	if self.on_tutorial then
		self.on_tutorial("started", tutorial_id)
	end
	self:_refresh()
	return true
end

---Advance tutorial timing and return the effective time factor.
---@param self starbreaker.time_controller
---@param dt number
---@return number
function Controller:update(dt)
	dt = math.max(0, dt or 0)
	if self:_has_block() then
		self:_refresh()
		return self.factor
	end
	if self.tutorial then
		self.tutorial.elapsed = self.tutorial.elapsed + dt
		if self.tutorial.elapsed >= TOTAL then
			local completed_id = self.tutorial.id
			self.tutorial = nil
			self:_set_factor(1)
			if self.on_tutorial then
				self.on_tutorial("completed", completed_id)
			end
			return self.factor
		end
	end
	self:_refresh()
	return self.factor
end

---Read the current world time factor.
---@param self starbreaker.time_controller
---@return number
function Controller:get_factor()
	return self.factor
end

---Read the active tutorial's ID, if any.
---@param self starbreaker.time_controller
---@return string|nil
function Controller:get_tutorial_id()
	return self.tutorial and self.tutorial.id
end

---Create a time controller with optional factor and tutorial callbacks.
---@param options table|nil
---@return starbreaker.time_controller
function M.new(options)
	options = options or {}
	return setmetatable({
		factor = 1,
		blocks = {},
		tutorial = nil,
		on_factor = options.on_factor,
		on_tutorial = options.on_tutorial,
	}, Controller)
end

return M
