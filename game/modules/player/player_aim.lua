-- Projects player aim between world coordinates and screen space.
local M = {}

local math_utils = require("common.math_utils")
local view_config = require("game.modules.mission.presentation.view_config")

local CAMERA_GO = "/camera"
local CAMERA_COMPONENT = "/camera#camera"
local SAMPLE_ORIGIN = vmath.vector3(0, 0, view_config.PLAYER_Z)
local SAMPLE_UNIT = vmath.vector3(1, 0, view_config.PLAYER_Z)

local function get_screen_x(action)
	return action.screen_x or action.x or 0
end

---Project horizontal pointer pixels into game-world X.
---@param pointer_screen_x number
---@param origin_screen_x number
---@param pixels_per_world number
---@return number
function M.project_screen_x_to_world(pointer_screen_x, origin_screen_x, pixels_per_world)
	if math.abs(pixels_per_world) < 0.001 then
		return 0
	end
	return math_utils.clamp((pointer_screen_x - origin_screen_x) / pixels_per_world,
		-view_config.CORRIDOR_HALF_WIDTH, view_config.CORRIDOR_HALF_WIDTH)
end

---Project a pointer action into the player's target lane.
---@param action table
---@return number|nil
function M.get_pointer_target(action)
	go.update_world_transform(CAMERA_GO)
	local origin_screen = camera.world_to_screen(SAMPLE_ORIGIN, CAMERA_COMPONENT)
	local unit_screen = camera.world_to_screen(SAMPLE_UNIT, CAMERA_COMPONENT)
	return M.project_screen_x_to_world(get_screen_x(action), origin_screen.x, unit_screen.x - origin_screen.x)
end

return M
