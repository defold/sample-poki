-- Applies progression rules for rewards, unlocks and upgrades.
local M = {}

local config = require("game.modules.rules.config")
local levels = require("game.modules.rules.levels")
local math_utils = require("common.math_utils")

local function upgrade_stat(upgrade_id, base, level)
	local upgrade = config.UPGRADES[upgrade_id]
	if not upgrade then
		return base
	end
	level = math_utils.non_negative_integer(level)
	if upgrade.is_inverted then
		return math.max(config.MIN_FIRE_COOLDOWN, base - level * upgrade.amount_per_level)
	end
	return base + level * upgrade.amount_per_level
end

local function integer(value, default, minimum, maximum)
	if not math_utils.is_finite_number(value) then
		return default
	end
	value = math.floor(value)
	if minimum then
		value = math.max(minimum, value)
	end
	if maximum then
		value = math.min(maximum, value)
	end
	return value
end

local function boolean(value, default)
	if type(value) == "boolean" then
		return value
	end
	return default
end

local function copy_known_ownership(saved, known)
	local result = {}
	if type(saved) == "table" then
		for id in pairs(known) do
			if saved[id] == true then
				result[id] = true
			end
		end
	end
	return result
end

---Create a normalized player profile from saved data.
---@param saved table|nil
---@return table
function M.new(saved)
	saved = type(saved) == "table" and saved or {}

	local owned_ships = copy_known_ownership(saved.owned_ships, config.SHIPS)
	local owned_skins = copy_known_ownership(saved.owned_skins, config.SKINS)
	owned_ships.scout = true
	owned_skins.standard = true

	local equipped_ship = saved.equipped_ship
	if type(equipped_ship) ~= "string" or not owned_ships[equipped_ship] then
		equipped_ship = "scout"
	end
	local equipped_skin = saved.equipped_skin
	if type(equipped_skin) ~= "string" or not owned_skins[equipped_skin] then
		equipped_skin = "standard"
	end

	local saved_upgrades = type(saved.upgrades) == "table" and saved.upgrades or {}
	local saved_tutorials = type(saved.tutorials) == "table" and saved.tutorials or {}
	local saved_settings = type(saved.settings) == "table" and saved.settings or {}

	return {
		mission = integer(saved.mission, 1, 1),
		credits = integer(saved.credits, 0, 0),
		owned_ships = owned_ships,
		equipped_ship = equipped_ship,
		owned_skins = owned_skins,
		equipped_skin = equipped_skin,
		upgrades = {
			damage = integer(saved_upgrades.damage, 0, 0),
			ammo = integer(saved_upgrades.ammo, 0, 0),
			hull = integer(saved_upgrades.hull, 0, 0),
			firerate = integer(saved_upgrades.firerate, 0, 0),
		},
		tutorials = {
			ammo = boolean(saved_tutorials.ammo, false),
			health = boolean(saved_tutorials.health, false),
			gold = boolean(saved_tutorials.gold, false),
			enemy = boolean(saved_tutorials.enemy, false),
		},
		settings = {
			muted = boolean(saved_settings.muted, false),
			language = type(saved_settings.language) == "string" and saved_settings.language or "",
		},
	}
end

---Combine base ship stats with the profile's upgrades.
---@param profile table
---@param ship_id string
---@return table|nil stats
function M.get_ship_stats(profile, ship_id)
	local ship = config.SHIPS[ship_id]
	if not ship then
		return nil
	end

	return {
		id = ship.id,
		health = upgrade_stat("hull", ship.health, profile.upgrades.hull),
		ammo = upgrade_stat("ammo", ship.ammo, profile.upgrades.ammo),
		damage = upgrade_stat("damage", ship.damage, profile.upgrades.damage),
		fire_cooldown = upgrade_stat("firerate", ship.fire_cooldown, profile.upgrades.firerate),
		move_speed = ship.move_speed,
	}
end

---Unlock progress after completing a mission.
---@param profile table
---@param level_id integer
---@return boolean has_changed
function M.advance_mission(profile, level_id)
	if not levels.get(level_id) then
		return false
	end
	local previous = profile.mission
	profile.mission = math.max(profile.mission, level_id + 1)
	return profile.mission ~= previous
end

---Describe the next purchasable rank of an upgrade.
---@param profile table
---@param upgrade_id string
---@return table|nil offer
function M.get_upgrade_offer(profile, upgrade_id)
	local upgrade = config.UPGRADES[upgrade_id]
	if not upgrade then
		return nil
	end
	local current_level = profile.upgrades[upgrade_id]
	return {
		id = upgrade_id,
		level = current_level,
		next_level = current_level + 1,
		price = config.UPGRADE_PRICE_BASE
			+ math_utils.non_negative_integer(current_level) * config.UPGRADE_PRICE_STEP,
		amount = upgrade.amount_per_level,
		stat = upgrade.stat,
	}
end

---Buy the next upgrade rank and deduct its price.
function M.purchase_upgrade(profile, upgrade_id)
	local offer = M.get_upgrade_offer(profile, upgrade_id)
	if not offer then return { success = false, reason = "unknown_upgrade" } end
	if profile.credits < offer.price then
		return { success = false, reason = "not_enough_credits", required_credits = offer.price }
	end
	profile.credits = profile.credits - offer.price
	profile.upgrades[upgrade_id] = offer.next_level
	return { success = true, id = upgrade_id, level = offer.next_level,
		price = offer.price, credits = profile.credits }
end

---Describe price and ownership state for a ship.
---@param profile table
---@param ship_id string
---@return table|nil offer
function M.get_ship_offer(profile, ship_id)
	local ship = config.SHIPS[ship_id]
	if not ship then
		return nil
	end
	return {
		id = ship_id,
		price = ship.price or 0,
		is_owned = profile.owned_ships[ship_id] == true,
		is_equipped = profile.equipped_ship == ship_id,
		is_locked = profile.owned_ships[ship_id] ~= true and ship.available_after_mission ~= nil
			and profile.mission <= ship.available_after_mission,
		available_after_mission = ship.available_after_mission or 0,
	}
end

---Buy and equip a ship after checking its unlock requirement and price.
---@param profile table
---@param ship_id string
---@return table result
function M.purchase_ship(profile, ship_id)
	local offer = M.get_ship_offer(profile, ship_id)
	if not offer then
		return { success = false, reason = "unknown_ship" }
	elseif offer.is_owned then
		return { success = false, reason = "already_owned" }
	elseif offer.is_locked then
		return { success = false, reason = "locked" }
	end
	if profile.credits < offer.price then
		return { success = false, reason = "not_enough_credits", required_credits = offer.price }
	end
	profile.credits = profile.credits - offer.price
	profile.owned_ships[ship_id] = true
	profile.equipped_ship = ship_id
	return { success = true, id = ship_id, price = offer.price, credits = profile.credits }
end

local function equip(profile, owned, field, id, catalog, unknown_reason)
	if not catalog[id] then
		return { success = false, reason = unknown_reason }
	elseif not owned[id] then
		return { success = false, reason = "not_owned" }
	end
	profile[field] = id
	return { success = true }
end

---Select an owned ship for future runs.
---@param profile table
---@param ship_id string
---@return table result
function M.equip_ship(profile, ship_id)
	return equip(profile, profile.owned_ships, "equipped_ship", ship_id, config.SHIPS, "unknown_ship")
end

---Describe ownership and unlock state for a skin.
---@param profile table
---@param skin_id string
---@return table|nil offer
function M.get_skin_offer(profile, skin_id)
	local skin = config.SKINS[skin_id]
	if not skin then
		return nil
	end
	return {
		id = skin_id,
		is_rewarded = skin.is_rewarded == true,
		is_owned = profile.owned_skins[skin_id] == true,
		is_equipped = profile.equipped_skin == skin_id,
	}
end

---Unlock and equip a skin granted by a rewarded ad.
---@param profile table
---@param skin_id string
---@return table result
function M.reward_skin(profile, skin_id)
	local offer = M.get_skin_offer(profile, skin_id)
	if not offer then
		return { success = false, reason = "unknown_skin" }
	elseif offer.is_owned then
		return { success = false, reason = "already_owned" }
	end
	profile.owned_skins[skin_id] = true
	profile.equipped_skin = skin_id
	return { success = true, id = skin_id, credits = profile.credits }
end

---Select an unlocked skin for the current ship.
---@param profile table
---@param skin_id string
---@return table result
function M.equip_skin(profile, skin_id)
	return equip(profile, profile.owned_skins, "equipped_skin", skin_id, config.SKINS, "unknown_skin")
end

---Record a tutorial cue so it does not appear again.
---@param profile table
---@param tutorial_id string
---@return table result
function M.set_tutorial_seen(profile, tutorial_id)
	if profile.tutorials[tutorial_id] == nil then
		return { success = false, reason = "unknown_tutorial" }
	end
	profile.tutorials[tutorial_id] = true
	return { success = true }
end

---Persist the player's mute preference.
---@param profile table
---@param is_muted boolean
---@return table result
function M.set_muted(profile, is_muted)
	if type(is_muted) ~= "boolean" then
		return { success = false, reason = "invalid_muted" }
	end
	profile.settings.muted = is_muted
	return { success = true }
end

return M
