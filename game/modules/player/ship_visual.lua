-- Maps saved and used ship and skin ids to model components and color palettes.
local M = {}

local COMPONENT = {
	scout = "model",
	interceptor = "model_interceptor",
	comet = "model_comet",
}

local SKIN = {
	standard = vmath.vector4(1, 1, 1, 0),
	solar = vmath.vector4(1.00, 0.34, 0.06, 0.48),
	nebula = vmath.vector4(0.62, 0.18, 1.00, 0.52),
}

local ORDER = { "scout", "interceptor", "comet" }

---Find the model component corresponding to an equipped ship.
---@param object_path string
---@param ship_id string
---@return string component_url
function M.component_url(object_path, ship_id)
	return object_path .. "#" .. (COMPONENT[ship_id] or COMPONENT.scout)
end

---Show the equipped ship and skin on a game object.
---@param object_path string
---@param ship_id string
---@param skin_id string
---@return string selected_component_url
function M.apply(object_path, ship_id, skin_id)
	ship_id = COMPONENT[ship_id] and ship_id or "scout"
	local selected_url = M.component_url(object_path, ship_id)
	for _, id in ipairs(ORDER) do
		msg.post(M.component_url(object_path, id), id == ship_id and "enable" or "disable")
		msg.post(object_path .. "#collision_" .. id, id == ship_id and "enable" or "disable")
	end
	go.set(selected_url, "skin_tint", SKIN[skin_id] or SKIN.standard)
	return selected_url
end

---Clear temporary damage tint on the ship model.
---@param object_path string
function M.reset_damage(object_path)
	local off = vmath.vector4(1.0, 0.05, 0.02, 0.0)
	for _, id in ipairs(ORDER) do
		local url = M.component_url(object_path, id)
		go.cancel_animations(url, "damage_flash")
		go.set(url, "damage_flash", off)
	end
end

return M
