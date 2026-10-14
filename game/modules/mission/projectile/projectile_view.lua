-- Spawns and animates projectile visuals for mission combat.
local M = {}

local config = require("game.modules.rules.config")
local view_config = require("game.modules.mission.presentation.view_config")

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

---Create a projectile visual for one side.
---@param side string
---@return table|nil projectile
function M.create(side)
	local id = factory.create("#projectile_factory")
	if not id then return nil end
	local collision_url = msg.url(nil, id, hash("collision_projectile"))
	physics.set_maskbit(collision_url, "player", side == "enemy")
	if side == "enemy" then
		physics.set_group(collision_url, "enemy_shot")
		physics.set_maskbit(collision_url, "actor", false)
	end
	local projectile = {
		id_hash = id,
		object_url = msg.url(nil, id, nil),
		mesh_url = msg.url(nil, id, hash("mesh")),
		position = vmath.vector3(),
		is_active = true,
	}
	if side == "enemy" then
		go.set(projectile.mesh_url, "tint", view_config.ENEMY_PROJECTILE_TINT)
		local scale = view_config.ENEMY_PROJECTILE_SCALE
		go.set_scale(vmath.vector3(scale, scale, scale), projectile.mesh_url)
	end
	return projectile
end

---Delete a resolved projectile.
---@param projectile table
function M.retire(projectile)
	projectile.is_active = false
	go.delete(projectile.id_hash)
end

local function activate(projectile, x, y, z)
	projectile.position.x = x
	projectile.position.y = y
	projectile.position.z = z
	go.set_position(projectile.position, projectile.object_url)
end

---Position and animate a player shot until it completes.
---@param projectile table
---@param x number
---@param z number
---@param finished function
function M.spawn_player(projectile, x, z, finished)
	activate(projectile, x, 0.04, z)
	local end_z = view_config.PROJECTILE_MAX_Z - 1
	go.animate(projectile.object_url, "position.z", go.PLAYBACK_ONCE_FORWARD,
		end_z, go.EASING_LINEAR, (z - end_z) / config.PLAYER.projectile_speed,
		0, finished)
end

---Position and animate an enemy shot toward its target.
---@param projectile table
---@param actor table
---@param finished function
function M.spawn_enemy(projectile, actor, finished)
	activate(projectile, actor.position.x, actor.position.y, actor.position.z + 0.7)
	local end_z = view_config.DESPAWN_Z + 1
	local duration = (end_z - projectile.position.z) / config.ENEMY.projectile_speed
	flash_twice(projectile.mesh_url, "tint", view_config.ENEMY_PROJECTILE_WARNING_TINT,
		approach_warning_delay(projectile.position.z, config.ENEMY.projectile_speed))
	go.animate(projectile.object_url, "position.z", go.PLAYBACK_ONCE_FORWARD,
		end_z, go.EASING_LINEAR, duration, 0, finished)
end

return M
