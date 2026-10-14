-- Loads and saves player progress, currency and unlocks.
local M = {}

local config = require("game.modules.rules.config")
local levels = require("game.modules.rules.levels")
local profile = require("game.modules.rules.profile")
local languages = require("game.modules.content.languages")
local math_utils = require("common.math_utils")
local saver = require("saver.saver")
local lang = require("lang.lang")

local state = {}

local function require_init()
	assert(state.profile, "progress_service.init() must be called first")
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local result = {}
	seen[value] = result
	for key, item in pairs(value) do
		result[deep_copy(key, seen)] = deep_copy(item, seen)
	end
	return result
end

local function failed_run_reward(level)
	return math.max(config.ECONOMY.minimum_fail_reward,
		math.floor((level.credits or 0) * config.ECONOMY.fail_reward_ratio))
end

local function persistent_payload()
	return {
		profile = deep_copy(state.profile),
		lang = state.is_lang_ready and deep_copy(lang.get_state()) or nil,
	}
end

local function load_saved()
	saver.init({
		-- Saver 8's extension-less serialized path depends on sys.save()'s platform return value.
		-- JSON gives a real boolean write result on native and uses the same local-storage adapter on HTML5.
		save_name = "starbreaker.json",
		autosave_timer = 3,
	})
	state.game_state = saver.get_game_state()
	return type(state.game_state.starbreaker) == "table"
		and state.game_state.starbreaker or {}
end

local function init_lang(loaded)
	if loaded and type(loaded.lang) == "table" then
		lang.set_state(loaded.lang)
	end
	local forced = state.profile.settings.language
	if forced == "" then
		forced = languages.system_default()
	end
	state.profile.settings.language = forced
	lang.init(languages.available(), forced)
	state.is_lang_ready = true
	state.profile.settings.language = lang.get_lang() or forced
end

local function save()
	local is_saved = false
	if state.game_state then
		state.game_state.starbreaker = persistent_payload()
		is_saved = saver.save_game_state() == true
	end
	if not is_saved and not state.is_save_pending then
		print("[progress] Save failed. Changes are available only in this session")
	end
	state.is_save_pending = not is_saved
	return is_saved
end

local function persist(result)
	if result.success then result.persisted = save() end
	return result
end

local function build_offers(order, getter)
	local offers = {}
	for _, id in ipairs(order) do
		offers[id] = getter(state.profile, id)
	end
	return offers
end

---Load and normalize the saved player profile.
---@return table snapshot
function M.init()
	if state.profile then
		return M.snapshot()
	end
	state = {
		run_counter = 0,
		is_save_pending = false,
	}
	local loaded = load_saved()
	loaded = type(loaded) == "table" and loaded or {}
	state.profile = profile.new(loaded.profile)
	init_lang(loaded)
	return M.snapshot()
end

---Return current progress and settings. Shop offers are added separately by shop_snapshot().
---@return table
function M.snapshot()
	require_init()
	return {
		mission = state.profile.mission,
		credits = state.profile.credits,
		equipped_ship = state.profile.equipped_ship,
		equipped_skin = state.profile.equipped_skin,
		language = state.profile.settings.language,
		is_muted = state.profile.settings.muted == true,
		is_save_pending = state.is_save_pending == true,
	}
end

---Build separate copies of shop data so UI changes leave saved progress and shared item lists intact.
function M.shop_snapshot()
	local snapshot = M.snapshot()
	snapshot.ship_order = deep_copy(config.SHIP_ORDER)
	snapshot.skin_order = deep_copy(config.SKIN_ORDER)
	snapshot.upgrade_offers = build_offers(config.UPGRADE_ORDER, profile.get_upgrade_offer)
	snapshot.ship_offers = build_offers(config.SHIP_ORDER, profile.get_ship_offer)
	snapshot.skin_offers = build_offers(config.SKIN_ORDER, profile.get_skin_offer)
	return snapshot
end

function M.get_ship_offer(id)
	require_init()
	return profile.get_ship_offer(state.profile, id)
end

function M.get_skin_offer(id)
	require_init()
	return profile.get_skin_offer(state.profile, id)
end

---@param tutorial_id string
---@return boolean
function M.is_tutorial_seen(tutorial_id)
	require_init()
	return state.profile.tutorials[tutorial_id] == true
end

---Reserve a new mission run, optionally with a fixed seed.
---@param level_id integer
---@param explicit_seed number|nil
---@return table|nil
function M.start_run(level_id, explicit_seed)
	require_init()
	local level = levels.get(level_id)
	if not level then
		return nil
	end
	state.run_counter = state.run_counter + 1
	local run_id = string.format("run-%06d", state.run_counter)
	local seed = explicit_seed or (level_id * 1009 + state.run_counter * 7919)
	local stats = profile.get_ship_stats(state.profile, state.profile.equipped_ship)
	if not stats then
		return nil
	end
	local run = {
		run_id = run_id,
		level_id = level_id,
		level = level,
		seed = seed,
		ship_stats = stats,
		skin_id = state.profile.equipped_skin,
		bonus_credits = 0,
		destroyed_targets = {},
	}
	state.active_run = run
	return {
		run_id = run_id,
		level_id = level_id,
		seed = seed,
		ship_stats = deep_copy(stats),
		skin_id = run.skin_id,
	}
end

---Apply a completed run to persistent progress once.
---@param run_id string|number
---@param status string
---@return table result
function M.finish_run(run_id, status)
	require_init()
	if state.last_result and state.last_result.run_id == run_id then
		return { success = false, reason = "already_finished", previous_result = deep_copy(state.last_result) }
	end
	local run = state.active_run
	if not run or run.run_id ~= run_id then
		return { success = false, reason = "unknown_run" }
	end
	local is_accepted = status == config.STATUS.COMPLETE
		or status == config.STATUS.FAIL_HEALTH
		or status == config.STATUS.FAIL_AMMO
		or status == config.STATUS.FAIL_OBJECTIVE
	if not is_accepted then
		return { success = false, reason = "invalid_status" }
	end

	local base_reward
	if status == config.STATUS.COMPLETE then
		base_reward = run.level.credits
		profile.advance_mission(state.profile, run.level_id)
	else
		base_reward = failed_run_reward(run.level)
	end
	local bonus_reward = math_utils.non_negative_integer(run.bonus_credits)
	local reward = base_reward + bonus_reward
	state.profile.credits = state.profile.credits + reward
	local result = {
		run_id = run_id,
		level_id = run.level_id,
		status = status,
		reward = reward,
		base_reward = base_reward,
		bonus_reward = bonus_reward,
		credits = state.profile.credits,
	}
	state.last_result = result
	state.active_run = nil
	result.persisted = save()
	local response = deep_copy(result)
	response.success = true
	return response
end

---Buy an upgrade and persist the revised profile.
---@param upgrade_id string
---@return table result
function M.purchase_upgrade(upgrade_id)
	require_init()
	return persist(profile.purchase_upgrade(state.profile, upgrade_id))
end

---Buy and equip a ship.
---@return table result
function M.purchase_ship(ship_id)
	require_init()
	return persist(profile.purchase_ship(state.profile, ship_id))
end

---Equip an owned ship and save the choice.
---@return table result
function M.equip_ship(ship_id)
	require_init()
	local result = profile.equip_ship(state.profile, ship_id)
	result.id = ship_id
	return persist(result)
end

---Grant and equip a skin earned from an ad.
---@return table result
function M.reward_skin(skin_id)
	require_init()
	return persist(profile.reward_skin(state.profile, skin_id))
end

---Equip an owned skin and save the choice.
---@return table result
function M.equip_skin(skin_id)
	require_init()
	local result = profile.equip_skin(state.profile, skin_id)
	result.id = skin_id
	return persist(result)
end

---Record that the player has seen a tutorial cue.
---@return table result
function M.set_tutorial_seen(tutorial_id)
	require_init()
	return persist(profile.set_tutorial_seen(state.profile, tutorial_id))
end

---Persist a supported display language.
---@param language_id string
---@return boolean
function M.set_language(language_id)
	require_init()
	-- Apply language tables before committing the persistent choice.
	if not languages.is_known(language_id) then
		return false
	end
	if state.is_lang_ready then
		lang.set_lang(language_id)
		if lang.get_lang() ~= language_id then return false end
	end
	state.profile.settings.language = language_id
	save()
	return true
end

---Persist the player's mute setting.
---@param is_muted boolean
---@return table result
function M.set_muted(is_muted)
	require_init()
	return persist(profile.set_muted(state.profile, is_muted))
end

---Award credits for one unique destroyed mission target.
---@param run_id string|number
---@param target_id string|number
---@param credit_bonus number
---@return table result
function M.record_target_destroyed(run_id, target_id, credit_bonus)
	require_init()
	local run = state.active_run
	if state.last_result and state.last_result.run_id == run_id then
		return { success = false, reason = "already_finished" }
	elseif not run or run.run_id ~= run_id then
		return { success = false, reason = "unknown_run" }
	elseif target_id == nil or target_id == "" then
		return { success = false, reason = "target_id_required" }
	elseif run.destroyed_targets[target_id] then
		return { success = false, reason = "target_already_recorded" }
	end

	run.destroyed_targets[target_id] = true
	credit_bonus = math_utils.non_negative_integer(credit_bonus)
	run.bonus_credits = run.bonus_credits + credit_bonus
	return {
		success = true,
		target_id = target_id,
		credit_bonus = credit_bonus,
		bonus_credits = run.bonus_credits,
	}
end

---Replace saved progress with a fresh player profile.
---@return table snapshot
function M.reset_profile()
	require_init()
	state.profile = profile.new()
	state.active_run = nil
	state.last_result = nil
	if state.is_lang_ready then
		lang.set_lang("en")
	end
	state.profile.settings.language = "en"
	save()
	return M.snapshot()
end

return M
