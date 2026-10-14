-- Validates and provides predefined mission definitions.
local M = {}

local level_config = require("game.modules.rules.level_config")

local PREDEFINED = level_config.PREDEFINED
local OBJECTIVE_MISS_FRACTION = level_config.OBJECTIVE_MISS_FRACTION

local function total_spawns(level)
	return level.spawn.asteroids + level.spawn.enemies + (level.is_boss and 1 or 0)
end

local function mixed_rank(id)
	return id - math.floor((id - 1) / 10)
end

local function generated_kill_quota(id)
	if id % 10 == 0 then
		return { asteroids = 0, enemies = 0, bosses = 1 }
	end
	local rank = mixed_rank(id)
	return {
		asteroids = rank + 4,
		enemies = rank + 4,
		bosses = 0,
	}
end

local function generated_spawns(id, quota)
	if quota.bosses > 0 then
		local cycle = math.floor(id / 10)
		return {
			asteroids = math.max(9, 8 + cycle),
			enemies = math.min(24, 5 + cycle * 3),
		}
	end
	return {
		asteroids = math.floor(quota.asteroids / (1 - OBJECTIVE_MISS_FRACTION)),
		enemies = math.floor(quota.enemies / (1 - OBJECTIVE_MISS_FRACTION)),
	}
end

local function generated_times(count, wave_size)
	local result = {}
	wave_size = wave_size or (count <= 14 and 4 or 5)
	local wave_gap = math.max(2.45, 3.65 - math.max(0, wave_size - 5) * 0.35)
	local intra_wave_gap = 0.16
	for index = 1, count do
		local zero_index = index - 1
		local wave = math.floor(zero_index / wave_size)
		local slot = zero_index % wave_size
		result[index] = wave * wave_gap + slot * intra_wave_gap
	end
	return result
end

local function generated_gold_slots(spawn, is_boss)
	if is_boss then
		return { 5 }
	end
	if spawn.asteroids >= 28 then
		return { 4, 9, 14, 22 }
	end
	if spawn.asteroids >= 20 then
		return { 4, 9, 14 }
	end
	return { 4, 9 }
end

local function generated_level(id)
	local is_boss = id % 10 == 0
	local quota = generated_kill_quota(id)
	local spawn = generated_spawns(id, quota)
	local total = spawn.asteroids + spawn.enemies + (is_boss and 1 or 0)
	local wave_size = math.min(6, 5 + math.floor((id - 11) / 8))
	local level = {
		id = id,
		spawn = spawn,
		objective = quota,
		speed = is_boss and math.min(10.0, 8.4 + (math.floor(id / 10) - 1) * 0.18)
			or math.min(10.4, 9.2 + (id - 9) * 0.035),
		enemy_health_multiplier = is_boss
			and math.min(2.00, 1.25 + (math.floor(id / 10) - 1) * 0.10)
			or math.min(3.20, 2.00 + (id - 9) * 0.05),
		asteroid_health_multiplier = 1.00,
		damage_multiplier = math.min(2.40, 1.50 + (id - 10) * 0.04),
		asteroid_heavy_period = math.max(3, 6 - math.floor(math.max(0, id - 9) / 10)),
		gold_slots = generated_gold_slots(spawn, is_boss),
		is_boss = is_boss,
		credits = math.min(400, 120 + (id - 9) * 12),
		wave_size = wave_size,
	}
	if is_boss then
		level.asteroid_heavy_period = math.max(4, level.asteroid_heavy_period)
	end
	level.spawn_times = generated_times(total, wave_size)
	return level
end

local function ensure_schedule(level)
	if level.spawn_times then
		return level
	end
	-- Missions 4-10 define spawn counts and balance parameters.
	-- Derive a deterministic schedule from those values for each request.
	local copy = {}
	for key, value in pairs(level) do
		copy[key] = value
	end
	copy.spawn_times = generated_times(total_spawns(copy))
	return copy
end

---Look up a mission level by its numeric ID.
---@param id string|integer
---@return table|nil
function M.get(id)
	if type(id) ~= "number" or id ~= math.floor(id) or id < 1 then
		return nil
	end
	if PREDEFINED[id] then
		return ensure_schedule(PREDEFINED[id])
	end
	return generated_level(id)
end

---Check a level definition before starting a mission.
---@param level table
---@return string|nil error
function M.validation_error(level)
	if type(level) ~= "table" or type(level.id) ~= "number" then
		return "invalid_level"
	end
	if type(level.spawn) ~= "table" or type(level.objective) ~= "table" then
		return "invalid_level_counts"
	end
	for _, key in ipairs({ "asteroids", "enemies" }) do
		local spawned = level.spawn[key]
		local required = level.objective[key]
		if type(spawned) ~= "number" or spawned ~= math.floor(spawned) or spawned < 0
			or type(required) ~= "number" or required ~= math.floor(required) or required < 0 then
			return "invalid_level_counts"
		end
		if required > spawned then
			return "objective_exceeds_spawns"
		end
	end
	local required_bosses = level.objective.bosses
	if type(required_bosses) ~= "number" or required_bosses ~= math.floor(required_bosses)
		or required_bosses < 0 or required_bosses > (level.is_boss and 1 or 0) then
		return "objective_exceeds_spawns"
	end
	if type(level.enemy_health_multiplier) ~= "number" or level.enemy_health_multiplier <= 0 then
		return "invalid_enemy_health_multiplier"
	end
	if type(level.asteroid_health_multiplier) ~= "number" or level.asteroid_health_multiplier <= 0 then
		return "invalid_asteroid_health_multiplier"
	end
	if type(level.spawn_times) ~= "table" or #level.spawn_times ~= total_spawns(level) then
		return "spawn_schedule_count_mismatch"
	end
	if level.lanes and #level.lanes ~= #level.spawn_times then
		return "lane_schedule_count_mismatch"
	end
	if level.kinds then
		if #level.kinds ~= #level.spawn_times then
			return "kind_schedule_count_mismatch"
		end
		local counts = { asteroid = 0, enemy = 0, boss = 0 }
		for _, kind in ipairs(level.kinds) do
			if counts[kind] == nil then
				return "invalid_spawn_kind"
			end
			counts[kind] = counts[kind] + 1
		end
		if counts.asteroid ~= level.spawn.asteroids
			or counts.enemy ~= level.spawn.enemies
			or counts.boss ~= (level.is_boss and 1 or 0) then
			return "spawn_kind_count_mismatch"
		end
	end
	local previous = -math.huge
	for index, spawn_at in ipairs(level.spawn_times) do
		if type(spawn_at) ~= "number" or spawn_at < previous or spawn_at < 0 then
			return "invalid_spawn_schedule"
		end
		local lane = level.lanes and level.lanes[index]
		if lane ~= nil and (type(lane) ~= "number" or lane ~= math.floor(lane)
			or lane < -3 or lane > 3) then
			return "invalid_lane_schedule"
		end
		previous = spawn_at
	end
	return nil
end

return M
