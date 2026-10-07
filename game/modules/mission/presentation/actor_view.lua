-- Builds and updates the visual representation of mission actors.
local M = {}

local math_utils = require("common.math_utils")
local config = require("game.modules.rules.config")
local combat_rules = require("game.modules.rules.combat_rules")
local view_config = require("game.modules.mission.presentation.view_config")

local ASTEROID_VARIATIONS = 4

local FACTORIES = {
	enemy = "#enemy_factory",
	boss = "#enemy_factory",
	ammo = "#ammo_factory",
}

local function component_url(id, component)
	return msg.url(nil, id, hash(component))
end

local function approach_warning_delay(start_z, speed)
	return math.max(0, (view_config.APPROACH_WARNING_Z - start_z) / speed)
end

local function flash_twice(url, property, tint, delay)
	go.animate(url, property, go.PLAYBACK_ONCE_PINGPONG, tint,
		go.EASING_INOUTSINE, view_config.APPROACH_WARNING_DURATION, delay, function()
			go.animate(url, property, go.PLAYBACK_ONCE_PINGPONG, tint,
				go.EASING_INOUTSINE, view_config.APPROACH_WARNING_DURATION)
		end)
end

local function animate_horizontal(actor)
	local settings = actor.kind == "boss" and config.BOSS or config.ENEMY
	local amplitude = math.min(settings.horizontal_amplitude, view_config.CORRIDOR_HALF_WIDTH)
	local center = actor.kind == "boss" and 0 or math_utils.clamp(actor.base_x,
		-view_config.CORRIDOR_HALF_WIDTH + amplitude, view_config.CORRIDOR_HALF_WIDTH - amplitude)
	local direction = actor.source_index % 2 == 0 and -1 or 1
	local first_target = center + direction * amplitude
	local other_target = center - direction * amplitude
	local half_period = math.pi / settings.horizontal_frequency
	local first_duration = math.max(0.05,
		half_period * math.abs(first_target - actor.position.x) / (2 * amplitude))
	go.animate(actor.object_url, "position.x", go.PLAYBACK_ONCE_FORWARD,
		first_target, go.EASING_OUTSINE, first_duration, 0, function()
			if actor.is_active then
				go.animate(actor.object_url, "position.x", go.PLAYBACK_LOOP_PINGPONG,
					other_target, go.EASING_INOUTSINE, half_period)
			end
		end)
end

---Flash the model when it takes damage.
---@param actor table
function M.flash_hit(actor)
	if actor.kind == "asteroid" then
		go.cancel_animations(actor.visual_url, "tint")
		go.set(actor.visual_url, "tint", view_config.ASTEROID_HIT_TINT)
		go.animate(actor.visual_url, "tint", go.PLAYBACK_ONCE_FORWARD,
			actor.base_tint or view_config.NORMAL_TINT, go.EASING_OUTQUAD,
			view_config.ACTOR_HIT_FLASH_DURATION)
		return
	end
	go.cancel_animations(actor.visual_url, "damage_flash")
	go.set(actor.visual_url, "damage_flash",
		vmath.vector4(1.0, 0.88, 0.42, view_config.ACTOR_HIT_FLASH_STRENGTH))
	go.animate(actor.visual_url, "damage_flash", go.PLAYBACK_ONCE_FORWARD,
		vmath.vector4(1.0, 0.88, 0.42, 0), go.EASING_OUTQUAD,
		view_config.ACTOR_HIT_FLASH_DURATION)
end

---Disable the model and collider, and stop movement and damage animations.
---@param actor table
function M.retire(actor)
	actor.is_active = false
	actor.is_alive = false
	msg.post(actor.collider_url, "disable")
	go.cancel_animations(actor.object_url)
	if actor.kind == "asteroid" then
		go.cancel_animations(actor.visual_url, "tint")
	end
	if actor.kind == "asteroid" or actor.kind == "enemy" or actor.kind == "boss" then
		go.cancel_animations(actor.visual_url, "damage_flash")
	end
	msg.post(actor.visual_url, "disable")
end

---Animate a newly spawned actor into the mission.
---@param self table
---@param actor table
function M.start_movement(self, actor)
	if actor.has_movement_started then return end
	actor.has_movement_started = true
	if actor.kind == "enemy" or actor.kind == "boss" then
		animate_horizontal(actor)
	elseif actor.kind == "ammo" or actor.kind == "asteroid" then
		if actor.kind == "ammo" then
			msg.post(component_url(actor.id_hash, "autoplay_particlefx"),
				"set_playing", { playing = true })
		end
		go.animate(actor.object_url, "euler.z", go.PLAYBACK_LOOP_FORWARD,
			360, go.EASING_LINEAR,
			actor.kind == "ammo" and 3.2 or actor.spin_seconds)
	end
	if actor.kind ~= "boss" then
		local approach_speed = self.state.speed
		if actor.kind == "enemy" then
			approach_speed = approach_speed * config.ENEMY.approach_speed_factor
		end
		if actor.kind == "asteroid" or actor.kind == "enemy" then
			flash_twice(actor.visual_url, "damage_flash", view_config.APPROACH_WARNING_FLASH,
				approach_warning_delay(actor.position.z, approach_speed))
		end
		go.animate(actor.object_url, "position.z", go.PLAYBACK_ONCE_FORWARD,
			view_config.DESPAWN_Z + 1, go.EASING_LINEAR,
			(view_config.DESPAWN_Z + 1 - actor.position.z) / approach_speed)
	end
end

---Create the object for a scheduled spawn and set its model, position and combat properties.
---@param self table
---@param entry table
---@return table actor
function M.configure(self, entry)
	local kind = entry.kind
	self.actor_serial = self.actor_serial + 1
	local slot = self.actor_serial
	local factory_url = kind == "asteroid"
		and "#asteroid_" .. ((slot - 1) % ASTEROID_VARIATIONS + 1) .. "_factory"
		or FACTORIES[kind]
	local id = assert(factory.create(factory_url), "actor factory exhausted")
	local actor = {
		id_hash = id,
		object_url = msg.url(nil, id, nil),
		visual_url = component_url(id, "visual"),
		explosion_url = kind ~= "ammo" and component_url(id, "explosion") or nil,
		collider_url = component_url(id, "collision_" .. kind),
		position = vmath.vector3(),
	}
	actor.slot = slot
	if kind == "enemy" or kind == "boss" then
		msg.post(component_url(id, kind == "boss" and "collision_enemy" or "collision_boss"), "disable")
	end
	actor.id = entry.id
	actor.kind = kind
	actor.is_gold = entry.is_gold
	actor.tier = entry.tier or 1
	actor.source_index = entry.source_index
	actor.is_active = true
	actor.is_alive = true
	actor.has_movement_started = false
	actor.is_destroyed = false
	if kind == "asteroid" or kind == "enemy" or kind == "boss" then
		go.set(actor.visual_url, "damage_flash", vmath.vector4(1.0, 0.88, 0.42, 0))
	end
	actor.hp = combat_rules.target_health(self.state, kind, actor.tier)
	if kind == "boss" then actor.max_hp = actor.hp end
	actor.base_x = (entry.lane + (entry.lane_offset or 0)) * view_config.LANE_WIDTH
	actor.position.x = actor.base_x
	actor.position.y = entry.offset_y or 0
	actor.position.z = view_config.FIRE_ZONE_Z + (entry.depth_offset or 0)
	go.set_position(actor.position, actor.object_url)
	go.cancel_animations(actor.object_url)

	local scale
	local rotation_y = entry.rotation_y or 0
	if kind == "ammo" then
		scale = 1.15
	elseif kind == "asteroid" then
		local tier = config.ASTEROID.tiers[actor.tier]
		local variation = entry.scale_variation or 1
		scale = (entry.is_gold and 1.12 or tier.scale) * variation
		actor.base_tint = entry.is_gold and view_config.GOLD_TINT or view_config.NORMAL_TINT
		go.set(actor.visual_url, "tint", actor.base_tint)
		actor.spin_seconds = entry.spin_seconds or 6.0
	else
		local settings = kind == "boss" and config.BOSS or config.ENEMY
		actor.fire_at = self.state.elapsed
			+ combat_rules.enemy_initial_fire_delay(self.state.level_id, kind)
		scale = settings.model_scale
		rotation_y = math.pi
	end
	go.set_scale(vmath.vector3(scale, scale, scale), actor.object_url)
	go.set_rotation(vmath.quat_rotation_y(rotation_y), actor.object_url)
	if self.is_playing then M.start_movement(self, actor) end
	return actor
end

return M
