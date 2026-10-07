-- Resolves combat outcomes and damage using mission state and rules.
local M = {}

local math_utils = require("common.math_utils")
local config = require("game.modules.rules.config")
local mission_state = require("game.modules.rules.mission_state")

local TARGET_KIND = { asteroid = true, enemy = true, boss = true }

local function mission_progress(level_id)
	level_id = math.max(1, math.floor(tonumber(level_id) or 1))
	return level_id - 1
end

---Calculate the delay before a newly spawned hostile fires.
---@param level_id integer
---@param kind "enemy"|"boss"
---@return number seconds
function M.enemy_initial_fire_delay(level_id, kind)
	if kind == "boss" then
		return config.BOSS.initial_fire_delay
	end
	return math.max(config.ENEMY.minimum_initial_fire_delay,
		config.ENEMY.initial_fire_delay
			- mission_progress(level_id) * config.ENEMY.initial_fire_delay_level_step)
end

---Calculate the delay between hostile shots for the current mission.
---@param level_id integer
---@param kind "enemy"|"boss"
---@return number seconds
function M.enemy_fire_interval(level_id, kind)
	if kind == "boss" then
		return config.BOSS.fire_interval
	end
	return math.max(config.ENEMY.minimum_fire_interval,
		config.ENEMY.fire_interval
			- mission_progress(level_id) * config.ENEMY.fire_interval_level_step)
end

---Calculate a target's health from its kind and mission tier.
---@param state table
---@param kind "asteroid"|"enemy"|"boss"
---@param tier integer|nil
---@return number|nil health
function M.target_health(state, kind, tier)
	if kind == "asteroid" then
		local asteroid = config.ASTEROID.tiers[tier or 1]
		local health = asteroid and asteroid.health or config.ASTEROID.health
		return math_utils.round_at_least(health * (state.asteroid_health_multiplier or 1), 1)
	end
	local settings
	if kind == "enemy" then
		settings = config.ENEMY
	elseif kind == "boss" then
		settings = config.BOSS
	else
		return nil
	end
	return settings.health * state.enemy_health_multiplier
end

local function target_credit_bonus(state, actor)
	if actor.kind == "asteroid" then
		local asteroid = config.ASTEROID.tiers[actor.tier or 1]
		local bonus = asteroid and asteroid.credit_bonus or 1
		return actor.is_gold and bonus * config.GOLD.credit_multiplier or bonus
	elseif actor.kind == "enemy" or actor.kind == "boss" then
		local settings = actor.kind == "boss" and config.BOSS or config.ENEMY
		local health = assert(M.target_health(state, actor.kind))
		local stock_hits = math.ceil(health / config.SHIPS.scout.damage)
		return stock_hits * settings.credit_per_stock_hit
	end
	return 0
end

---Apply a hit and return the updated target, including destruction and credit data.
---@param state table
---@param actor table
---@param amount number
---@return table|nil hit
function M.apply_target_damage(state, actor, amount)
	if type(actor) ~= "table" or not TARGET_KIND[actor.kind] then
		return nil
	elseif actor.is_destroyed or actor.is_alive == false then
		return nil
	elseif type(amount) ~= "number" or amount <= 0 then
		return nil
	end

	local hp = math.max(0, (actor.hp or M.target_health(state, actor.kind, actor.tier)) - amount)
	local is_destroyed = hp <= 0
	local credit_bonus = 0
	if is_destroyed then
		local retired = mission_state.destroy_target(state, actor.kind)
		if not retired then
			return nil
		end
		credit_bonus = target_credit_bonus(state, actor)
		actor.is_destroyed = true
		actor.is_alive = false
	end
	actor.hp = hp
	return {
		id = actor.id,
		actor = actor,
		kind = actor.kind,
		gold = actor.is_gold == true,
		damage = amount,
		hp = actor.hp,
		is_destroyed = is_destroyed,
		credit_bonus = credit_bonus,
	}
end

local function apply_ship_damage(state, amount)
	if state.shield_seconds > 0 then
		return false
	elseif state.invulnerability_seconds > 0 then
		return false
	elseif type(amount) ~= "number" or amount <= 0 then
		return false
	end
	state.health = math.max(0, state.health - amount)
	state.invulnerability_seconds = config.PLAYER.invulnerability_seconds
	return true
end

---Apply collision or projectile damage unless the player is protected.
---@param state table
---@param source string
---@param tier integer|nil
---@return boolean is_applied
function M.apply_source_damage(state, source, tier)
	local base_damage
	if source == "asteroid" then
		local asteroid = config.ASTEROID.tiers[tier or 1]
		base_damage = asteroid and asteroid.collision_damage
			or config.ASTEROID.collision_damage
	elseif source == "enemy_projectile" then
		base_damage = config.ENEMY.projectile_damage
	elseif source == "enemy_contact" then
		base_damage = config.ENEMY.contact_damage
	else
		return false
	end
	return apply_ship_damage(state, base_damage * state.damage_multiplier)
end

return M
