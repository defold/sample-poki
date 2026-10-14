-- Spawns and animates background planets for the mission world.
local M = {}

local math_utils = require("common.math_utils")
local planet_variants = require("game.modules.rules.planet_variants")

local PAST_Z = -140
local WRAP_DISTANCE = 380
local RESET_Z = PAST_Z - WRAP_DISTANCE
local FULL_SCALE_Z = -460
local FADE_OUT_Z = -220

local PLANETS = {
	{ id = "planet_1", z = -270, y = -20, speed = 1.6, radius = 62, spin = 180, euler_z = 90 },
	{ id = "planet_2", z = -320, y = -15, speed = 1.2, radius = 57, spin = 240, euler_z = 90 },
	{ id = "planet_3", z = -490, y = -210, speed = 1.0, radius = 102, spin = 300, euler_z = 90, euler_x = 90 },
}

local PALETTE = {
	vmath.vector4(0.20, 0.58, 0.96, 1),
	vmath.vector4(0.98, 0.38, 0.13, 1),
	vmath.vector4(0.62, 0.28, 0.88, 1),
	vmath.vector4(0.18, 0.78, 0.60, 1),
	vmath.vector4(0.92, 0.66, 0.22, 1),
}

local MIN_SCALE = 0.001
local EASING_SAMPLES = 64

local function reveal_easing(start_z)
	local start_t = (start_z - RESET_Z) / (FULL_SCALE_Z - RESET_Z)
	local start_factor = math_utils.smoothstep(start_t)
	local values = {}
	for index = 0, EASING_SAMPLES do
		local t = vmath.lerp(index / EASING_SAMPLES, start_t, 1)
		values[#values + 1] = (math_utils.smoothstep(t) - start_factor) / (1 - start_factor)
	end
	return vmath.vector(values)
end

local function fade_easing()
	local values = {}
	for index = 0, EASING_SAMPLES do
		values[#values + 1] = math_utils.smoothstep(index / EASING_SAMPLES)
	end
	return vmath.vector(values)
end

local FADE_EASING = fade_easing()

local function object_url(id)
	return msg.url(nil, id, nil)
end

local function model_url(id)
	return msg.url(nil, id, hash("model"))
end

local function uniform_scale(size)
	return vmath.vector3(size, size, size)
end

local function animate_fade(body, delay)
	go.animate(body.object_url, "scale", go.PLAYBACK_ONCE_FORWARD,
		uniform_scale(MIN_SCALE), FADE_EASING,
		(PAST_Z - FADE_OUT_Z) / body.speed, delay)
end

local function animate_planet(body, start_z, start_x)
	local duration = (PAST_Z - start_z) / body.speed
	go.set_position(vmath.vector3(start_x, body.y, start_z), body.object_url)
	local initial_size = math.max(MIN_SCALE,
		body.radius * planet_variants.scale_factor(start_z, RESET_Z, FULL_SCALE_Z))
	go.set_scale(uniform_scale(initial_size), body.object_url)

	if start_z < FULL_SCALE_Z then
		go.animate(body.object_url, "scale", go.PLAYBACK_ONCE_FORWARD,
			uniform_scale(body.radius), reveal_easing(start_z),
			(FULL_SCALE_Z - start_z) / body.speed, 0,
			function()
				animate_fade(body, (FADE_OUT_Z - FULL_SCALE_Z) / body.speed)
			end)
	else
		animate_fade(body, math.max(0, (FADE_OUT_Z - start_z) / body.speed))
	end

	go.animate(body.object_url, "position", go.PLAYBACK_ONCE_FORWARD,
		vmath.vector3(start_x, body.y, PAST_Z),
		go.EASING_LINEAR, duration, 0,
		function()
			animate_planet(body, RESET_Z, body.base_x)
		end)
end

---Spawn the background planets using the preset layout and randomized variants.
---@param factory_url url|string
function M.new(factory_url)
	-- Randomize the first side, then alternate sides to keep the planets from overlapping.
	local first_side = math.random(0, 1) == 0 and -1 or 1
	for index, planet_config in ipairs(PLANETS) do
		local id = assert(factory.create(factory_url), "planet factory exhausted")
		local side = index % 2 == 1 and first_side or -first_side
		local variant = planet_variants.random_variant(index, side)
		local start_z = math.max(RESET_Z + 1, planet_config.z + variant.z_offset)
		local body = {
			object_url = object_url(id),
			base_x = variant.x,
			y = planet_config.y + variant.y,
			speed = planet_config.speed,
			radius = planet_config.radius * variant.scale_factor,
		}
		animate_planet(body, start_z, body.base_x)
		local visual_url = model_url(id)
		go.set(visual_url, "planet_tint", PALETTE[variant.palette])
		go.set(visual_url, "planet_bands", vmath.vector4(
			variant.band_frequency, 0.22, 0, 1.4))
		go.set(body.object_url, "euler.x", planet_config.euler_x or 0)
		go.set(body.object_url, "euler.z", planet_config.euler_z or 0)
		go.animate(body.object_url, "euler.y", go.PLAYBACK_LOOP_FORWARD,
			360, go.EASING_LINEAR, planet_config.spin)
	end
end

return M
