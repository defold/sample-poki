-- Holds shared positions, sizes and timing for mission presentation.
local M = {}

local config = require("game.modules.rules.config")

M.PHASE_PREPLAY = "PREPLAY" -- Mission is waiting for the player to start.
M.PHASE_PLAYING = "PLAYING" -- Mission simulation and input are active.
M.PHASE_RESULT = "RESULT" -- Mission has ended and results are shown.

M.POINTER_FOLLOW_SPEED = 80 -- Maximum speed at which the player follows pointer steering.
M.CORRIDOR_HALF_WIDTH = config.PLAYER.corridor_half_width -- Horizontal limit of player movement from the center lane.
M.LANE_WIDTH = config.PLAYER.lane_width -- World-space distance between adjacent lanes.

M.PLAYER_Z = -0.6 -- Depth of the player model in world space.
M.FIRE_ZONE_Z = M.PLAYER_Z - 60.0 -- Depth where targets become eligible to be hit by player fire.
M.PROJECTILE_MAX_Z = M.PLAYER_Z - 60.0 - 12.0 -- Maximum travel depth for player projectiles.
M.DESPAWN_Z = M.PLAYER_Z + 3 -- Depth beyond the player where actors are removed.
M.APPROACH_WARNING_Z = M.PLAYER_Z - 12.0 -- Depth where incoming hazards briefly flash.
M.APPROACH_WARNING_DURATION = 0.22 -- Length of each of the two near-player warning pulses.
M.APPROACH_WARNING_FLASH = vmath.vector4(1.0, 0.16, 0.04, 0.68) -- Warning overlay for actors.
M.BANK_LEFT = vmath.quat_rotation_z(math.rad(12)) -- Player bank angle for left steering.
M.BANK_NEUTRAL = vmath.quat_rotation_z(0) -- Player bank angle with no steering input.
M.BANK_RIGHT = vmath.quat_rotation_z(math.rad(-12)) -- Player bank angle for right steering.
M.NORMAL_TINT = vmath.vector4(0.94, 0.98, 1.0, 1.0) -- Base actor tint before damage or other effects.
M.GOLD_TINT = vmath.vector4(1.0, 0.64, 0.10, 1.0) -- Tint used to identify gold asteroids.
M.ASTEROID_HIT_TINT = vmath.vector4(1.0, 0.93, 0.48, 1.0) -- Temporary tint shown when an asteroid is hit.
M.ACTOR_HIT_FLASH_DURATION = 0.18 -- Length of an actor's hit flash, in seconds.
M.ACTOR_HIT_FLASH_STRENGTH = 0.92 -- Tint intensity of an actor's hit flash.
M.ENEMY_PROJECTILE_TINT = vmath.vector4(1.0, 0.25, 0.05, 1.0) -- Color used for enemy projectiles.
M.ENEMY_PROJECTILE_WARNING_TINT = vmath.vector4(1.0, 0.95, 0.50, 1.0) -- Near-player projectile flash.
M.ENEMY_PROJECTILE_SCALE = 1.5 -- Visual scale of the enemy projectile mesh.
M.DAMAGE_FLASH_DURATION = 0.16 -- Length of the player's damage flash, in seconds.
M.DAMAGE_FLASH_STRENGTH = 0.76 -- Tint intensity of the player's damage flash.

-- Hit, destruction and impacts use separate camera impulses.
M.CAMERA_HIT_MAGNITUDE = 0.008 -- Camera shake strength when a target is hit.
M.CAMERA_HIT_DURATION = 0.05 -- Camera shake length for a target hit, in seconds.
M.CAMERA_PLAYER_HIT_MAGNITUDE = 0.016 -- Camera shake strength when the player is hit.
M.CAMERA_PLAYER_HIT_DURATION = 0.05 -- Camera shake length when the player is hit, in seconds.
M.CAMERA_DESTROY_MAGNITUDE = 0.022 -- Camera shake strength when an actor is destroyed.
M.CAMERA_DESTROY_FOV = 0.7 -- Field-of-view increase for a destruction impact, in degrees.
M.CAMERA_DESTROY_DURATION = 0.12 -- Destruction camera impulse length, in seconds.
M.CAMERA_GOLD_MAGNITUDE = 0.040 -- Camera shake strength when a gold asteroid is destroyed.
M.CAMERA_GOLD_FOV = 1.4 -- Field-of-view increase when a gold asteroid is destroyed, in degrees.
M.CAMERA_GOLD_DURATION = 0.14 -- Camera impulse length when a gold asteroid is destroyed, in seconds.

return M
