-- Tracks Poki gameplay sessions and ad requests.
-- Converts Poki SDK and Ads Wrapper responses into the same result format.
local M = {}

local ad_state = require("common.ad_state")
local ads_wrapper = require("ads_wrapper.ads_wrapper")
local events = require("ads_wrapper.events")
local poki = require("ads_wrapper.ads_networks.poki")

M.RESULT_SUCCESS = "success"
M.RESULT_ERROR = "error"
M.RESULT_CANCEL = "cancel"

M.AD_COMMERCIAL = "commercial"
M.AD_REWARDED = "rewarded"

local state = {
	is_initialized = false,
	is_playing = false,
	has_started_once = false,
	ad_kind = nil,
	is_ad_started = false,
	is_ads_initialized = false,
	lifecycle_sequence = 0,
	ad_sequence = 0,
	last_reward = nil,
}

local config = {
	is_debug = false,
	on_event = nil,
	is_ads_available = false,
	backend_name = "unavailable",
	fallback_device_category = "desktop",
}

local function emit(event_name, data)
	if event_name == "ad_requested" then ad_state.set_busy(true)
	elseif event_name == "ad_finished" then ad_state.set_busy(false) end
	config.on_event(event_name, data)
end

local function has_html5()
	return rawget(_G, "html5") ~= nil and rawget(_G, "html5") ~= false
end

local function platform_sdk()
	if not has_html5() then
		return nil
	end
	return rawget(_G, "poki_sdk")
end

local function call_sdk(method_name, ...)
	local sdk = platform_sdk()
	local method = sdk and sdk[method_name]
	if type(method) ~= "function" then
		return false
	end

	method(...)
	return true
end

local function init_ads()
	if not has_html5() or not rawget(_G, "poki_sdk") then
		return nil
	end

	local ads = ads_wrapper
	local sdk_events = events
	local poki_network = poki

	local network_id = ads.register_network(poki_network, {
		is_debug = config.is_debug,
	})
	if not network_id then
		return nil
	end

	ads.setup_video({ { id = network_id } })

	ads.init(true, false, function(response)
		state.is_ads_initialized = response and response.result == sdk_events.SUCCESS or false
		emit("ads_initialized", {
			success = state.is_ads_initialized,
			response = response,
		})
	end)

	return true
end

local function wrapper_outcome(response)
	if response and response.result == events.SUCCESS then return M.RESULT_SUCCESS end
	if response and (response.result == events.ABORT
		or (response.result == events.ERROR and response.code == events.C_SKIPPED)) then
		return M.RESULT_CANCEL
	end
	return M.RESULT_ERROR
end

local function valid_text(value)
	return type(value) == "string" and value ~= ""
end

local function valid_placement(value)
	return valid_text(value) and #value <= 64 and not string.find(value, "[/%^]")
end

local function lifecycle_call(method_name, event_name, reason)
	state.lifecycle_sequence = state.lifecycle_sequence + 1
	local is_sent = call_sdk(method_name)
	emit(event_name, {
		reason = reason,
		sequence = state.lifecycle_sequence,
		sent = is_sent,
	})
	return true
end

local function finish_ad(ad_id, kind, placement, callback, outcome, raw_response)
	if not ad_state.is_busy() or state.ad_sequence ~= ad_id or state.ad_kind ~= kind then
		return
	end
	if config.is_debug then
		print("[poki_service] ad_result kind=" .. kind .. " placement=" .. placement
			.. " outcome=" .. outcome .. " started=" .. tostring(state.is_ad_started)
			.. " status=" .. tostring(raw_response))
	end

	local has_started = state.is_ad_started
	state.ad_kind = nil
	state.is_ad_started = false

	local transaction_id = nil
	local is_rewarded = false
	if kind == M.AD_REWARDED then
		transaction_id = "reward-" .. tostring(ad_id)
		is_rewarded = outcome == M.RESULT_SUCCESS
		state.last_reward = {
			id = transaction_id,
			is_successful = is_rewarded,
			is_claimed = false,
		}
	end

	local result = {
		ad_id = ad_id,
		kind = kind,
		placement = placement,
		outcome = outcome,
		started = has_started,
		rewarded = is_rewarded,
		transaction_id = transaction_id,
		raw_response = raw_response,
	}
	emit("ad_finished", result)
	callback(result)
end

local function begin_ad(kind, placement, params, callback)
	if not state.is_initialized then
		return false
	elseif ad_state.is_busy() then
		return false
	elseif state.is_playing then
		return false
	elseif not state.has_started_once then
		return false
	end

	state.ad_sequence = state.ad_sequence + 1
	local ad_id = state.ad_sequence
	state.ad_kind = kind
	state.is_ad_started = false
	emit("ad_requested", {
		ad_id = ad_id,
		kind = kind,
		placement = placement,
	})

	local function on_start()
		if not ad_state.is_busy() or state.ad_sequence ~= ad_id or state.is_ad_started then
			return
		end
		state.is_ad_started = true
		emit("ad_started", {
			ad_id = ad_id,
			kind = kind,
			placement = placement,
		})
	end

	local function on_finish(response)
		finish_ad(ad_id, kind, placement, callback, wrapper_outcome(response), response)
	end
	if kind == M.AD_REWARDED then
		local sdk = platform_sdk()
		if config.is_debug then
			print("[poki_service] rewarded_request placement=" .. placement
				.. " size=" .. tostring(params.size))
		end
		if not sdk or type(sdk.rewarded_break) ~= "function" then
			finish_ad(ad_id, kind, placement, callback, M.RESULT_ERROR, "rewarded_unavailable")
			return true
		end
		sdk.rewarded_break(params.size, function(_, status)
			if sdk.REWARDED_BREAK_START and status == sdk.REWARDED_BREAK_START then
				on_start()
			elseif sdk.REWARDED_BREAK_SUCCESS and status == sdk.REWARDED_BREAK_SUCCESS then
				finish_ad(ad_id, kind, placement, callback, M.RESULT_SUCCESS, status)
			else
				finish_ad(ad_id, kind, placement, callback, M.RESULT_ERROR, status)
			end
		end)
		return true
	end
	if not config.is_ads_available then
		on_finish({ message = "ads_unavailable" })
		return true
	end
	local is_accepted, error_message = ads_wrapper.show_interstitial(on_finish, {
		size = params.size, start_callback = on_start,
	})

	if is_accepted == false then
		on_finish({
			message = error_message,
		})
	end
	return true
end

---Initialize once from the persistent app collection.
---@param options table Must include an on_event function.
---@return boolean is_accepted
function M.init(options)
	if state.is_initialized then
		return false
	end

	config.is_debug = options.debug
	if config.is_debug == nil then
		config.is_debug = sys.get_engine_info().is_debug == true
	end
	config.on_event = options.on_event
	config.fallback_device_category = options.fallback_device_category or "desktop"
	config.is_ads_available = init_ads() == true
	config.backend_name = config.is_ads_available and "ads_wrapper_poki" or "unavailable"

	state.is_initialized = true
	emit("service_initialized", {
		backend = config.backend_name,
		debug = config.is_debug,
		poki_available = M.is_poki_available(),
	})
	return true
end

---Report the first gameplay start to Poki. Reject the request during an ad or before initialization.
---@param reason string|nil
---@return boolean is_accepted
function M.start_on_first_input(reason)
	if not state.is_initialized then
		return false
	elseif ad_state.is_busy() then
		return false
	elseif state.has_started_once then
		return false
	end

	state.has_started_once = true
	state.is_playing = true
	return lifecycle_call("gameplay_start", "gameplay_started", reason or "first_input")
end

---Report gameplay starting again after a pause or between missions.
---@param reason string|nil
---@return boolean is_accepted
function M.gameplay_start(reason)
	if not state.is_initialized then
		return false
	elseif ad_state.is_busy() then
		return false
	elseif not state.has_started_once then
		return false
	elseif state.is_playing then
		return false
	end

	state.is_playing = true
	return lifecycle_call("gameplay_start", "gameplay_started", reason or "resume")
end

---End active gameplay tracking for a pause or transition.
---@param reason string|nil
---@return boolean is_accepted
function M.gameplay_stop(reason)
	if not state.is_initialized then
		return false
	elseif ad_state.is_busy() then
		return false
	elseif not state.is_playing then
		return false
	end

	state.is_playing = false
	return lifecycle_call("gameplay_stop", "gameplay_stopped", reason or "pause")
end

---Request an interstitial at a named placement and finish via callback.
---@param options table|nil
---@param callback fun(result: table)
---@return boolean is_accepted
function M.commercial_break(options, callback)
	if type(options) ~= "table" or not valid_placement(options.placement) then
		return false
	end
	return begin_ad(M.AD_COMMERCIAL, options.placement, options, callback)
end

---Request a sized rewarded ad and report its outcome via callback.
---@param options table|nil
---@param callback fun(result: table)
---@return boolean is_accepted
function M.rewarded_break(options, callback)
	if type(options) ~= "table" then
		return false
	elseif not valid_placement(options.placement) then
		return false
	elseif options.size ~= "small" and options.size ~= "medium" and options.size ~= "large" then
		return false
	end
	return begin_ad(M.AD_REWARDED, options.placement, options, callback)
end

---Claim a successful reward transaction exactly once.
---@param transaction_id string|number
---@return table result
function M.claim_reward(transaction_id)
	local reward = state.last_reward
	if not reward or reward.id ~= transaction_id then
		return { success = false, reason = "unknown_transaction" }
	elseif not reward.is_successful then
		return { success = false, reason = "not_rewarded" }
	elseif reward.is_claimed then
		return { success = false, reason = "already_claimed" }
	end

	reward.is_claimed = true
	emit("reward_claimed", { transaction_id = transaction_id })
	return { success = true }
end

---Check that all three analytics labels are non-empty.
---@param category string
---@param what string
---@param action string
---@return boolean
function M.is_valid_measure(category, what, action)
	return valid_placement(category) and valid_placement(what) and valid_placement(action)
end

---Send one valid Poki measurement when the service is ready.
---@param category string
---@param what string
---@param action string
---@return boolean is_accepted
function M.measure(category, what, action)
	if not state.is_initialized then
		return false
	elseif ad_state.is_busy() then
		return false
	elseif not M.is_valid_measure(category, what, action) then
		return false
	end

	local is_sent = call_sdk("measure", category, what, action)
	emit("measure", {
		category = category,
		what = what,
		action = action,
		sent = is_sent,
	})
	return true
end

---Read Poki's category, falling back when unavailable.
---@return string
function M.get_device_category()
	local sdk = platform_sdk()
	local info = sdk and sdk.get_device_info and sdk.get_device_info()
	if type(info) == "table" then
		local category = info.category
		if category == "mobile" or category == "tablet" or category == "desktop" then
			return category
		end
	end
	return config.fallback_device_category
end

---Request a vertical Poki Pill offset.
---@param top_percent number
---@param top_pixels number
---@return boolean is_accepted
function M.move_pill(top_percent, top_pixels)
	if type(top_percent) ~= "number" or type(top_pixels) ~= "number" then
		return false
	end
	local is_sent = call_sdk("move_pill", top_percent, top_pixels)
	return is_sent
end

---Check whether the Poki SDK is accessible in this runtime.
---@return boolean
function M.is_poki_available()
	return platform_sdk() ~= nil
end

---Return a copy so callers cannot change the tracked SDK state.
---@return table
function M.get_state()
	local reward = state.last_reward
	return {
		is_initialized = state.is_initialized,
		is_playing = state.is_playing,
		has_started_once = state.has_started_once,
		is_ad_busy = ad_state.is_busy(),
		ad_kind = state.ad_kind,
		is_ad_started = state.is_ad_started,
		is_ads_initialized = state.is_ads_initialized,
		lifecycle_sequence = state.lifecycle_sequence,
		ad_sequence = state.ad_sequence,
		backend = config.backend_name,
		is_poki_available = M.is_poki_available(),
		last_reward_id = reward and reward.id or nil,
		is_last_reward_claimed = reward and reward.is_claimed or false,
	}
end

return M
