-- Chooses background planet positions and appearance values.
local M = {}

local math_utils = require("common.math_utils")

local RINGS = {
	{ min = 160, span = 30 },
	{ min = 175, span = 30 },
	{ min = 320, span = 40 },
}

---Pick a random planet variant for its position, size, colour and belt width.
---@param index integer
---@param side number|nil Optional side, normalized to -1 or 1.
---@return table variant
function M.random_variant(index, side)
	index = math.max(1, math_utils.non_negative_integer(index))
	local ring = RINGS[math.min(index, #RINGS)]
	side = side and (side < 0 and -1 or 1)
		or (math.random(0, 1) == 0 and -1 or 1)
	local distance_x = ring.min + math.random() * ring.span
	local variant = {
		x = side * distance_x,
		y = -25 + math.random() * 50,
		z_offset = -20 + math.random() * 40,
		scale_factor = 0.90 + math.random() * 0.28,
		palette = math.random(1, 5),
		band_frequency = 1.5 + math.random() * 6.5,
	}
	return variant
end

---Scale a planet by its depth along the approach path.
---@param z number
---@param reset_z number
---@param full_scale_z number
---@return number
function M.scale_factor(z, reset_z, full_scale_z)
	if full_scale_z <= reset_z then
		return 1
	end
	local t = math_utils.clamp((z - reset_z) / (full_scale_z - reset_z), 0, 1)
	return math_utils.smoothstep(t)
end

return M
