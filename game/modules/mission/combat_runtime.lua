-- Creates and updates mission actors, projectiles and combat events.
local M = {}

local config = require("game.modules.rules.config")
local mission_state = require("game.modules.rules.mission_state")
local combat_rules = require("game.modules.rules.combat_rules")
local actor_view = require("game.modules.mission.presentation.actor_view")
local projectile_view = require("game.modules.mission.projectile.projectile_view")
local player_movement = require("game.modules.player.player_movement")
local player_input = require("game.modules.player.player_input")
local feedback_events = require("game.modules.mission.presentation.feedback_events")
local view_config = require("game.modules.mission.presentation.view_config")
local addresses = require("common.addresses")

local APP_URL = addresses.APP_CONTROLLER
local PLAYER_SHOT = hash("player_shot")
local ENEMY_SHOT = hash("enemy_shot")
local PLAYER = hash("player")
local ACTOR = hash("actor")
local PICKUP = hash("pickup")

local function side_with_group(a, b, group)
	if a.group == group then return a end
	if b.group == group then return b end
end

local function sync_position(actor)
	actor.position = go.get_position(actor.object_url)
end

---Initialize actor and projectile lists, collision lookups and objects waiting for deletion.
---@param self table
function M.init_objects(self)
	self.actors = {}
	self.projectiles = {}
	self.physics_actors = {}
	self.physics_projectiles = {}
	self.retiring_actors = {}
	self.actor_serial = 0
end

---Delete mission objects, including those kept alive until their effects finish.
---@param self table
function M.clear_objects(self)
	for _, actor in ipairs(self.actors) do
		actor.is_active = false
		go.delete(actor.id_hash)
	end
	for _, projectile in ipairs(self.projectiles) do
		projectile.is_active = false
		go.delete(projectile.id_hash)
	end
	for id in pairs(self.retiring_actors) do
		go.delete(id)
	end
	self.actors = {}
	self.projectiles = {}
	self.physics_actors = {}
	self.physics_projectiles = {}
	self.retiring_actors = {}
end

local function configure_actor(self, entry)
	local actor = actor_view.configure(self, entry)
	self.actors[#self.actors + 1] = actor
	self.physics_actors[actor.id_hash] = actor
	local kind = actor.kind
	if kind == "enemy" or kind == "boss" then
		msg.post(APP_URL, "game_event", { id = "tutorial_trigger",
			run_id = self.run.run_id, tutorial_id = "enemy" })
		if kind == "boss" then self:publish_hud_state() end
	end
	if entry.is_gold then
		msg.post(APP_URL, "game_event", { id = "tutorial_trigger",
			run_id = self.run.run_id, tutorial_id = "gold" })
	end
end

---Spawn all scheduled actors whose spawn time has been reached.
---@param self table
function M.activate_due_spawns(self)
	local entry = mission_state.pop_due_spawn(self.state)
	while entry do
		configure_actor(self, entry)
		entry = mission_state.pop_due_spawn(self.state)
	end
end

---Spawn pickups when their scheduled time is reached.
---@param self table
function M.activate_due_pickups(self)
	local entry = self.pickup_plan[self.next_pickup]
	while entry and entry.spawn_at <= self.state.elapsed do
		self.next_pickup = self.next_pickup + 1
		configure_actor(self, entry)
		entry = self.pickup_plan[self.next_pickup]
	end
end

local function remove_active(items, item)
	for index = #items, 1, -1 do
		if items[index] == item then
			table.remove(items, index)
			return
		end
	end
end

local function retire_actor(self, actor, keep_for_effect)
	actor_view.retire(actor)
	self.physics_actors[actor.id_hash] = nil
	remove_active(self.actors, actor)
	if not keep_for_effect then
		go.delete(actor.id_hash)
		return
	end
	self.retiring_actors[actor.id_hash] = actor
	return function()
		if self.retiring_actors[actor.id_hash] == actor then
			self.retiring_actors[actor.id_hash] = nil
			go.delete(actor.id_hash)
		end
	end
end

local function retire_projectile(self, projectile)
	if not projectile.is_active then return end
	self.physics_projectiles[projectile.id_hash] = nil
	remove_active(self.projectiles, projectile)
	projectile_view.retire(projectile)
end

local function fire_player(self)
	local projectile = projectile_view.create("player")
	if not projectile then
		return false
	end
	local fired = mission_state.fire(self.state)
	if not fired then
		projectile_view.retire(projectile)
		return false
	end
	self.projectiles[#self.projectiles + 1] = projectile
	self.physics_projectiles[projectile.id_hash] = projectile
	projectile_view.spawn_player(projectile, self.player_x, view_config.PLAYER_Z - 1.0,
		function()
			retire_projectile(self, projectile)
		end)
	player_movement.kick(self)
	feedback_events.player_shot:trigger({ speed = 0.97 + (self.state.ammo % 4) * 0.02 })
	msg.post(APP_URL, "game_event", { id = "shot_fired", run_id = self.run.run_id })
	self:publish_hud_state()
	return true
end

local function fire_cooldown(self)
	return math.max(config.MIN_FIRE_COOLDOWN, self.state.fire_cooldown or config.MIN_FIRE_COOLDOWN)
end

---Fire when ammunition and cooldown permit.
---@param self table
---@return boolean
function M.try_fire(self)
	if player_input.is_blocked(self)
		or self.is_awaiting_input
		or self.phase ~= view_config.PHASE_PLAYING or not self.is_playing then
		return false
	elseif self.fire_timer > 0 then
		return false
	end
	local fired = fire_player(self)
	self.fire_timer = fire_cooldown(self)
	return fired
end

local function destroyed_feedback(self, actor, source, credit_bonus)
	local position = vmath.vector3(actor.position)
	local is_gold = actor.is_gold == true
	local on_complete = retire_actor(self, actor, true)
	feedback_events.target_destroyed:trigger({ position = position, is_gold = is_gold,
		vfx_url = actor.explosion_url,
		on_complete = on_complete,
		source = source, credit_bonus = credit_bonus or 0 })
	msg.post(APP_URL, "game_event", { id = "target_destroyed",
		run_id = self.run.run_id,
		target_id = actor.id,
		credit_bonus = credit_bonus or 0,
	})
end

local function collect_ammo(self, actor)
	if not actor.is_active or not actor.is_alive then
		return false
	end
	local collected = mission_state.collect_ammo(self.state, config.AMMO_PICKUP.amount)
	if not collected then
		return false
	end
	particlefx.stop(msg.url(nil, actor.id_hash, hash("particlefx")), { clear = true })
	particlefx.play(msg.url(nil, actor.id_hash, hash("pickup_particlefx")))
	retire_actor(self, actor)
	feedback_events.ammo_collected:trigger()
	self:publish_hud_state()
	return true
end

local function report_target_hit(self, actor, result, source)
	if result.is_destroyed then
		destroyed_feedback(self, actor, source, result.credit_bonus)
		self:publish_hud_state()
	else
		actor_view.flash_hit(actor)
		feedback_events.target_hit:trigger({ vfx_url = actor.explosion_url, should_shake_camera = true })
		if actor.kind == "boss" then self:publish_hud_state() end
	end
	return true
end

local function damage_actor(self, actor, amount, source)
	local result = combat_rules.apply_target_damage(self.state, actor, amount)
	return result and report_target_hit(self, actor, result, source) or false
end

local function miss_actor(self, actor, has_collided)
	if not actor.is_active or not actor.is_alive then
		return false
	end
	if actor.kind == "ammo" then
		retire_actor(self, actor)
		return true
	end
	actor.is_alive = false
	mission_state.miss_target(self.state)
	local on_complete = retire_actor(self, actor, has_collided)
	if has_collided then
		feedback_events.target_collided:trigger({ vfx_url = actor.explosion_url, on_complete = on_complete })
	end
	self:publish_hud_state()
	return true
end

local function apply_ship_hit(self, source, tier)
	local is_applied = combat_rules.apply_source_damage(self.state, source, tier)
	if not is_applied then
		return false
	end
	feedback_events.ship_hit:trigger({ vfx_url = "/player#explosion" })
	msg.post(APP_URL, "game_event", { id = "ship_damaged", run_id = self.run.run_id })
	self:publish_hud_state()
	return true
end

local function fire_enemy(self, actor)
	local projectile = projectile_view.create("enemy")
	if not projectile then
		return false
	end
	self.projectiles[#self.projectiles + 1] = projectile
	self.physics_projectiles[projectile.id_hash] = projectile
	projectile_view.spawn_enemy(projectile, actor,
		function()
			retire_projectile(self, projectile)
		end)
	return true
end

---Update actor positions, fire enemy shots when due, and remove actors that pass the player.
---@param self table
function M.update_actors(self)
	for index = #self.actors, 1, -1 do
		local actor = self.actors[index]
		if actor.is_active and actor.is_alive then
			actor_view.start_movement(self, actor)
			sync_position(actor)
			if (actor.kind == "enemy" or actor.kind == "boss")
				and self.state.elapsed >= actor.fire_at then
				actor.fire_at = actor.fire_at
					+ combat_rules.enemy_fire_interval(self.state.level_id, actor.kind)
				fire_enemy(self, actor)
			end
			if actor.position.z > view_config.DESPAWN_Z then
				miss_actor(self, actor, false)
			end
		end
	end
end

local function active_actor(self, id)
	local actor = self.physics_actors[id]
	return actor and actor.is_active and actor.is_alive and actor or nil
end

local function on_player_shot_hit(self, shot_id, actor_id)
	local projectile = self.physics_projectiles[shot_id]
	local actor = active_actor(self, actor_id)
	if not projectile or not projectile.is_active or not actor then return end
	sync_position(actor)
	retire_projectile(self, projectile)
	damage_actor(self, actor, self.state.damage, "player_projectile")
end

local function on_enemy_shot_hit(self, shot_id)
	local projectile = self.physics_projectiles[shot_id]
	if not projectile or not projectile.is_active then return end
	retire_projectile(self, projectile)
	apply_ship_hit(self, "enemy_projectile")
end

local function on_player_touch(self, actor_id)
	local actor = active_actor(self, actor_id)
	if not actor then return end
	sync_position(actor)
	if actor.kind == "ammo" then return collect_ammo(self, actor) end
	if actor.kind == "asteroid" then
		apply_ship_hit(self, "asteroid", actor.tier)
	else
		apply_ship_hit(self, "enemy_contact")
	end
	miss_actor(self, actor, true)
end

---Handle a collision between mission objects.
---@param self table
---@param a table
---@param b table
function M.on_trigger_enter(self, a, b)
	if not self.is_playing or self.phase ~= view_config.PHASE_PLAYING then return end
	local own = side_with_group(a, b, PLAYER_SHOT)
	local other = own == a and b or a
	if own and other.group == ACTOR then
		on_player_shot_hit(self, own.id, other.id)
		return
	end
	own = side_with_group(a, b, ENEMY_SHOT)
	other = own == a and b or a
	if own and other.group == PLAYER then
		on_enemy_shot_hit(self, own.id)
		return
	end
	own = side_with_group(a, b, PLAYER)
	other = own == a and b or a
	if own and (other.group == ACTOR or other.group == PICKUP) then
		on_player_touch(self, other.id)
	end
end

---Advance shot cooldowns and projectile effects.
---@param self table
---@param dt number
function M.update_fire(self, dt)
	self.fire_timer = math.max(0, self.fire_timer - dt)
	local requested = self.is_fire_pending or player_input.is_fire_held(self)
	self.is_fire_pending = false
	if requested then
		M.try_fire(self)
	end
end


return M
