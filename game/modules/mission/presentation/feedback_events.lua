-- Defines shared events used to connect mission presentation systems.
local M = {}

local event = require("event.event")

M.player_shot = event.create()
M.target_hit = event.create()
M.target_destroyed = event.create()
M.ammo_collected = event.create()
M.target_collided = event.create()
M.ship_hit = event.create()
M.run_reset = event.create()
M.aim_position = event.create()
M.engine_changed = event.create()

return M
