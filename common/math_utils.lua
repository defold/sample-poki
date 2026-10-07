-- Math helpers
local M = {}

---Return whether value is a real, finite number.
---@param value any
---@return boolean
function M.is_finite_number(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

---Round a non-negative value and keep it above minimum.
---@param value number
---@param minimum integer
---@return integer
function M.round_at_least(value, minimum)
	return math.max(minimum, math.floor(value + 0.5))
end

---Convert a value to a non-negative integer.
---@param value number|nil
---@return integer
function M.non_negative_integer(value)
	value = M.is_finite_number(value) and value or 0
	return math.max(0, math.floor(value))
end

---Keep a number inside the inclusive minimum/maximum range.
---@param value number
---@param minimum number
---@param maximum number
---@return number
function M.clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

---Wrap a 1-based index through count entries.
---@param index integer
---@param count integer
---@return integer
function M.wrap(index, count)
	return ((index - 1) % count) + 1
end

---Apply cubic easing. The caller is responsible for keeping the amount in the 0–1 range.
---@param amount number
---@return number
function M.smoothstep(amount)
	return amount * amount * (3 - 2 * amount)
end

return M
