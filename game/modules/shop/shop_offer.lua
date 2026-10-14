-- Describes the action shown by each shop control.
local M = {}

function M.get(state, kind, id)
	if kind == "continue" then
		return { enabled = state ~= nil, message = "mothership_continue" }
	end
	local offer = state and state[kind .. "_offers"][id]
	local action = {
		id = id,
		enabled = offer ~= nil,
		message = kind == "upgrade" and "purchase_upgrade" or kind .. "_shop_action",
		label = "shop_buy",
		value = offer and offer.price or 0,
		icon = "star_medium",
	}
	if kind == "upgrade" then return action end
	action.name = kind .. "_" .. id
	action.equipped = offer and offer.is_equipped == true
	action.rewarded = kind == "skin" and offer ~= nil and not offer.is_owned
	action.enabled = offer ~= nil and not action.equipped and (kind == "skin" or not offer.is_locked)
	if action.equipped then
		action.label, action.icon = "shop_active", nil
	elseif offer and offer.is_owned then
		action.label, action.icon = "shop_equip", nil
	elseif kind == "skin" then
		action.label, action.icon = "skin_watch_unlock", offer and "video" or nil
		action.message = "skin_rewarded_offer"
	elseif offer and offer.is_locked then
		action.label, action.value, action.icon = "shop_unlock_after", offer.available_after_mission, nil
	end
	return action
end

return M
