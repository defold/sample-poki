-- Creates and updates the pure state model for a mission run.
local M = {}

local math_utils = require("common.math_utils")
local config = require("game.modules.rules.config")
local levels = require("game.modules.rules.levels")
local spawn_plan = require("game.modules.rules.spawn_plan")

local PROGRESS_KEY = {
	asteroid = "asteroids",
	enemy = "enemies",
	boss = "bosses",
}

---Create the mission state for a level, seed, and ship.
---@param level_id integer
---@param seed number
---@param ship_stats table
---@return table
function M.new(level_id, seed, ship_stats)
	local level = levels.get(level_id)
	assert(level, "unknown level: " .. tostring(level_id))
	ship_stats = ship_stats or config.SHIPS.scout
	seed = seed or level_id * 1000
	local spawns = spawn_plan.build(level, seed)
	local objective = {
		asteroids = level.objective.asteroids,
		enemies = level.objective.enemies,
		bosses = level.objective.bosses,
	}
	local magazine = math_utils.non_negative_integer(ship_stats.ammo)
		+ (config.EARLY_MISSION_AMMO_BONUS[level_id] or 0)

	return {
		level_id = level_id,
		status = config.STATUS.PLAYING,

		health = ship_stats.health,
		max_health = ship_stats.health,
		ammo = magazine,
		max_ammo = magazine,
		damage = ship_stats.damage,
		fire_cooldown = ship_stats.fire_cooldown,
		move_speed = ship_stats.move_speed,

		speed = level.speed,
		enemy_health_multiplier = level.enemy_health_multiplier,
		asteroid_health_multiplier = level.asteroid_health_multiplier,
		damage_multiplier = level.damage_multiplier,

		objective = objective,
		progress = { asteroids = 0, enemies = 0, bosses = 0 },
		targets_remaining = #spawns,

		elapsed = 0,
		next_spawn = 1,
		invulnerability_seconds = 0,
		is_rescue_used = false,
		shield_seconds = 0,
		spawn_plan = spawns,
	}
end

---List the mission counters in HUD order, omitting categories this mission does not require.
function M.objective_counters(state)
	local counters = {}
	for _, category in ipairs({ "asteroids", "enemies", "bosses" }) do
		local required = state.objective[category]
		if required > 0 then
			counters[#counters + 1] = {
				category = category,
				progress = math.min(state.progress[category], required),
				required = required,
			}
		end
	end
	return counters
end

---Return the next scheduled spawn when it is due and advance the queue.
---@param state table
---@return table|nil
function M.pop_due_spawn(state)
	local entry = state.spawn_plan[state.next_spawn]
	if not entry or entry.spawn_at > state.elapsed then
		return nil
	end
	state.next_spawn = state.next_spawn + 1
	return entry
end

---Spend one round when firing is allowed.
---@param state table
---@return boolean has_fired
function M.fire(state)
	if state.status ~= config.STATUS.PLAYING then
		return false
	end
	if state.ammo <= 0 then
		return false
	end
	state.ammo = state.ammo - 1
	return true
end

---Add ammunition earned from a pickup.
---@param state table
---@param amount number
---@return boolean is_collected
function M.collect_ammo(state, amount)
	if type(amount) ~= "number" or amount <= 0 then
		return false
	end
	amount = math_utils.non_negative_integer(amount)
	if amount <= 0 then
		return false
	end
	state.ammo = math.min(state.max_ammo, state.ammo + amount)
	return true
end

local function consume_target(state)
	if state.targets_remaining <= 0 then
		return false
	end
	state.targets_remaining = state.targets_remaining - 1
	return true
end

---Count a destroyed target toward the current objective.
---@param state table
---@param kind string
---@return boolean is_destroyed
function M.destroy_target(state, kind)
	local key = PROGRESS_KEY[kind]
	if not key then
		return false
	end
	local is_consumed = consume_target(state)
	if not is_consumed then
		return false
	end
	state.progress[key] = state.progress[key] + 1
	return true
end

---Record a target that escaped or was missed.
---@param state table
---@return boolean is_consumed
function M.miss_target(state)
	return consume_target(state)
end

---Advance mission timers by one scaled frame.
---@param state table
---@param dt number
function M.tick(state, dt)
	dt = math.max(0, dt or 0)
	state.elapsed = state.elapsed + dt
	state.invulnerability_seconds = math.max(0, state.invulnerability_seconds - dt)
	state.shield_seconds = math.max(0, state.shield_seconds - dt)
end

---Count all targets needed to finish the mission.
---@param state table
---@return integer
function M.objective_total(state)
	return state.objective.asteroids + state.objective.enemies + state.objective.bosses
end

---Count the targets already resolved.
---@param state table
---@return integer
function M.progress_total(state)
	-- The HUD shows `x OF y`. Each category contributes up to its required count.
	return math.min(state.progress.asteroids, state.objective.asteroids)
		+ math.min(state.progress.enemies, state.objective.enemies)
		+ math.min(state.progress.bosses, state.objective.bosses)
end

---Check whether the mission objective is finished.
---@param state table
---@return boolean
function M.objective_complete(state)
	return M.progress_total(state) == M.objective_total(state)
end

---Choose the final result once the mission has ended.
---@param state table
---@return string|nil new_status
function M.resolve(state)
	if state.status ~= config.STATUS.PLAYING then
		return nil
	end

	local next_status
	if M.objective_complete(state) then
		next_status = config.STATUS.COMPLETE
	elseif state.health <= 0 then
		next_status = config.STATUS.FAIL_HEALTH
	elseif state.ammo <= 0 then
		next_status = config.STATUS.FAIL_AMMO
	elseif state.targets_remaining <= 0 then
		next_status = config.STATUS.FAIL_OBJECTIVE
	end

	if not next_status then
		return nil
	end
	state.status = next_status
	return next_status
end

---Apply a rewarded rescue to a failed run.
---@param state table
---@param kind string
---@return table result
function M.rescue(state, kind)
	if state.is_rescue_used then
		return { success = false, reason = "rescue_already_used" }
	end
	local is_health_rescue = kind == "health" and state.status == config.STATUS.FAIL_HEALTH
	local is_ammo_rescue = kind == "ammo" and state.status == config.STATUS.FAIL_AMMO
	if not is_health_rescue and not is_ammo_rescue then
		return { success = false, reason = "rescue_not_available" }
	end
	if is_health_rescue then
		state.shield_seconds = config.RESCUE.shield_seconds
		state.invulnerability_seconds = 0
	end
	state.health = math.min(state.max_health,
		state.health + math.ceil(state.max_health * config.RESCUE.refill_fraction))
	state.ammo = math.min(state.max_ammo,
		state.ammo + math.ceil(state.max_ammo * config.RESCUE.refill_fraction))
	state.is_rescue_used = true
	state.status = config.STATUS.PLAYING
	return { success = true }
end

return M
