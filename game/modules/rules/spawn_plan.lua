-- Builds a seeded, balanced schedule of mission actors and pickups.
local M = {}

local math_utils = require("common.math_utils")
local config = require("game.modules.rules.config")
local levels = require("game.modules.rules.levels")

local MIN_LANE = config.PLAYER.min_lane
local MAX_LANE = config.PLAYER.max_lane

---Lay out deterministic pickups for a level and seed.
---@param level_id integer
---@param seed number
---@return table
function M.build_pickups(level_id, seed)
	level_id = math.max(1, math_utils.non_negative_integer(tonumber(level_id)))
	seed = math_utils.is_finite_number(seed) and math.floor(math.abs(seed)) or 1

	local plan = {}
	local count = math.min(config.AMMO_PICKUP.maximum_count,
		2 + math.floor((level_id - 1) / 4))
	for index = 1, count do
		local sample = math.abs(math.sin(seed * 0.017 + index * 7.31))
		plan[index] = {
			id = string.format("ammo_%02d", index),
			kind = "ammo",
			source_index = 100 + index,
			spawn_at = 2.6 + (index - 1) * 7.4 + (sample - 0.5) * 0.8,
			lane = (math.floor(sample * 1000) % (MAX_LANE - MIN_LANE + 1)) + MIN_LANE,
			lane_offset = math.sin(seed * 0.011 + index * 2.7) * 0.16,
			offset_y = math.cos(seed * 0.013 + index) * 0.42,
			depth_offset = -sample * 1.8,
			rotation_y = sample * math.pi * 2,
		}
	end
	return plan
end

local function lookup(values)
	local result = {}
	for _, value in ipairs(values or {}) do
		result[value] = true
	end
	return result
end

-- Expose required enemies before a base ship can spend its magazine on rocks.
local function bring_enemies_forward(result, required_enemies)
	for required_index = 1, required_enemies do
		local early_limit = math.min(1 + required_index * 2, #result)
		local early_count = 0
		for index = 1, early_limit do
			if result[index] == "enemy" then
				early_count = early_count + 1
			end
		end
		if early_count < required_index then
			local next_enemy
			for index = early_limit + 1, #result do
				if result[index] == "enemy" then
					next_enemy = index
					break
				end
			end
			if next_enemy then
				result[next_enemy], result[early_limit] = result[early_limit], result[next_enemy]
			end
		end
	end
end

local function spawn_kinds(level)
	if level.kinds then
		return level.kinds
	end

	local result = {}
	for _ = 1, level.spawn.asteroids do
		result[#result + 1] = "asteroid"
	end
	for _ = 1, level.spawn.enemies do
		result[#result + 1] = "enemy"
	end

	for index = #result, 3, -1 do
		local other = math.random(2, index)
		result[index], result[other] = result[other], result[index]
	end
	bring_enemies_forward(result, level.objective.enemies)

	if level.is_boss then
		table.insert(result, math.min(3, #result + 1), "boss")
	end
	return result
end

local function adjacent_lane(lane)
	if lane >= MAX_LANE then
		return lane - 1
	elseif lane <= MIN_LANE then
		return lane + 1
	end
	return lane + (math.random(0, 1) == 0 and -1 or 1)
end

---Build the enemy and pickup schedule for a mission.
---@param level table
---@param seed number
---@return table
function M.build(level, seed)
	assert(type(level) == "table", "level is required")
	local error = levels.validation_error(level)
	assert(error == nil, error)

	seed = math_utils.is_finite_number(seed) and math.floor(math.abs(seed)) or 1
	math.randomseed(seed)
	local kinds = spawn_kinds(level)
	local gold_opportunities = lookup(level.gold_opportunities)
	local gold_slots = lookup(level.gold_slots)
	local cluster_orders = {}
	for _, pair in ipairs(level.cluster_pairs or {}) do
		cluster_orders[pair[1]] = true
		cluster_orders[pair[2]] = true
	end

	local source_counts = { asteroid = 0, enemy = 0, boss = 0 }
	local plan = {}
	local asteroid_period = level.asteroid_heavy_period or 6
	local asteroid_tier_offset = math.random(0, asteroid_period - 1)
	local medium_tier_at = math.max(2, math.floor(asteroid_period / 2))

	for order, scheduled_spawn_at in ipairs(level.spawn_times) do
		local kind = kinds[order]
		source_counts[kind] = source_counts[kind] + 1
		local source_index = source_counts[kind]
		local is_gold = kind == "asteroid"
			and (gold_opportunities[order] == true or gold_slots[source_index] == true)
		local tier = 1
		if kind == "asteroid" and not is_gold then
			local tier_position = ((source_index + asteroid_tier_offset - 1) % asteroid_period) + 1
			if tier_position == asteroid_period then
				tier = 3
			elseif tier_position == medium_tier_at then
				tier = 2
			end
		end

		local spawn_at = scheduled_spawn_at
		if order > 1 and not cluster_orders[order] then
			spawn_at = math.max(0, scheduled_spawn_at + (math.random() * 0.22 - 0.11))
			spawn_at = math.max(spawn_at, plan[order - 1].spawn_at + 0.035)
		end

		local configured_lane = level.lanes and level.lanes[order]
		local lane
		if order == 1 then
			lane = 0
		elseif configured_lane then
			lane = math_utils.clamp(configured_lane + math.random(-2, 2), MIN_LANE, MAX_LANE)
		else
			lane = math.random(MIN_LANE, MAX_LANE)
		end
		if order > 1 and lane == plan[order - 1].lane then
			lane = lane == MAX_LANE and lane - 1 or lane + 1
		end

		plan[order] = {
			id = string.format("%s_%02d", kind, source_index),
			kind = kind,
			source_index = source_index,
			order = order,
			spawn_at = spawn_at,
			lane = lane,
			lane_offset = math.random() * 0.44 - 0.22,
			offset_y = math.random() * 1.30 - 0.65,
			depth_offset = -math.random() * 2.6,
			scale_variation = 0.92 + math.random() * 0.16,
			rotation_y = math.random() * math.pi * 2,
			spin_seconds = 4.3 + math.random() * 3.2,
			is_gold = is_gold,
			tier = tier,
		}
	end

	-- Gold clusters share one lane and depth.
	for _, pair in ipairs(level.cluster_pairs or {}) do
		local origin = plan[pair[1]]
		local neighbour = plan[pair[2]]
		if origin and neighbour then
			neighbour.lane = adjacent_lane(origin.lane)
			neighbour.lane_offset = origin.lane_offset
			neighbour.depth_offset = origin.depth_offset
		end
	end

	return plan
end

return M
