-- Initializes game and handles game events forwarded by the app script.
local M = {}

local druid = require("druid.druid")
local monarch = require("monarch.monarch")
local lang = require("lang.lang")
local ad_state = require("common.ad_state")
local addresses = require("common.addresses")
local audio_events = require("game.modules.audio.audio_events")
local progress = require("game.modules.profile.progress")
local deferred_pack_loader = require("app.modules.assets.deferred_pack_loader")
local deferred_assets = require("game.modules.deferred_assets.deferred_assets")
local music = require("game.modules.audio.music")
local gameplay = require("game.modules.runtime.gameplay")
local app_state = require("game.modules.runtime.app_state")
local tutorials = require("game.modules.runtime.tutorials")
local screen_flow = require("game.modules.flow.screen_flow")
local shop_flow = require("game.modules.shop.shop_flow")
local settings_flow = require("game.modules.flow.settings_flow")
local pause_flow = require("game.modules.flow.pause_flow")
local session_flow = require("game.modules.flow.session_flow")
local result_flow = require("game.modules.flow.result_flow")
local client = require("common.audio.client")

local message_handlers = {
	[hash("show_initial_gameplay")] = screen_flow.show_initial,
	[hash("screen_ready")] = screen_flow.on_screen_ready,
	[hash("mothership_continue")] = screen_flow.on_mothership_continue,

	[hash("purchase_upgrade")] = shop_flow.on_purchase_upgrade,
	[hash("ship_shop_action")] = shop_flow.on_ship_shop_action,
	[hash("skin_shop_action")] = shop_flow.on_skin_shop_action,
	[hash("skin_rewarded_offer")] = shop_flow.on_skin_rewarded_offer,
	[hash("skin_rewarded_cancel")] = shop_flow.on_skin_rewarded_cancel,
	[hash("skin_rewarded_confirm")] = shop_flow.on_skin_rewarded_confirm,

	[hash("reset_save_requested")] = session_flow.on_reset_save_requested,
	[hash("mission_result")] = result_flow.on_mission_result,
	[hash("result_continue")] = result_flow.on_result_continue,
	[hash("rewarded_offer_opened")] = result_flow.on_rewarded_offer_opened,
	[hash("rewarded_cancel")] = result_flow.on_rewarded_cancel,
	[hash("rewarded_confirm")] = result_flow.on_rewarded_confirm,
	[hash("rescue_applied")] = result_flow.on_rescue_applied,
	[hash("game_event")] = session_flow.on_game_event,

	[hash("pause_requested")] = pause_flow.on_pause_requested,
	[hash("credits_open")] = pause_flow.on_credits_open,
	[hash("credits_close")] = pause_flow.on_credits_close,

	[hash("mute_toggle")] = settings_flow.on_mute_toggle,
	[hash("set_language")] = settings_flow.on_set_language,
	[hash("deferred_font_ready")] = settings_flow.on_deferred_font_ready,
	[hash("deferred_font_failed")] = settings_flow.on_deferred_font_failed,

	[hash("input_mode")] = app_state.on_input_mode,
	[hash("deferred_audio_ready")] = music.on_deferred_audio_ready,
}

local function bind_game_audio(self)
	for id, spec in pairs(audio_events) do
		self.audio:bind_event(id, {
			url = msg.url(spec.url),
			gain = spec.gain,
		})
	end
end

---Request attachment after the bootstrap objects have initialized.
function M.init(self)
	msg.post(addresses.APP_CONTROLLER, "attach_game", { module = "game.modules.bootstrap.entry" })
end

---Initialize game services in the app controller context.
---@param self table
function M.attach(self)
	ad_state.changed:subscribe(M.on_ad_changed, self)
	bind_game_audio(self)
	self.deferred_assets = deferred_pack_loader.new(deferred_assets, {
		cache_namespace = "Starbreaker", proxy_owner = "main:/game_deferred_assets#loader",
		on_ready = function(id, spec)
			if id == "audio" then music.on_deferred_audio_ready(self, { url = spec.sound_url })
			else settings_flow.on_deferred_font_ready(self, { pack = id }) end
		end,
		on_failed = function(id, reason)
			settings_flow.on_deferred_font_failed(self, { pack = id, reason = reason })
		end,
	})

	self.is_gameplay_ready = false
	self.is_mothership_ready = false
	self.is_pill_configured = false

	local profile = progress.init()
	druid.set_text_function(function(text_id, ...)
		if select("#", ...) > 0 then return lang.txp(text_id, ...) end
		return lang.txt(text_id)
	end)
	self.app.language = profile.language
	self.app.is_muted = profile.is_muted == true
	client.set_muted(self.app.is_muted)
	tutorials.create_time_controller(self)
	monarch.on_focus_changed("gameplay", function(id)
		pause_flow.on_screen_focus(self, { focused = id == monarch.FOCUS_GAINED })
	end)
end

---Open the first mission after app startup.
---@param self table
function M.start(self)
	app_state.sync(self)
	msg.post("#", "show_initial_gameplay")
end

---Cancel controls and update mission timing when the ad block changes.
---@param self table
---@param busy boolean
function M.on_ad_changed(self, busy)
	if busy then
		client.set_ad_active(true)
		self.time:set_block("ad", true)
		gameplay.set_input_blocker(self, true)
		gameplay.cancel_ad_input(self)
	else
		gameplay.cancel_ad_input(self)
		client.set_ad_active(false)
		self.time:set_block("ad", false)
	end
	app_state.sync(self)
end

function M.on_platform_event(self)
	app_state.sync(self)
end

---@type fun(self: table)
M.on_focus_lost = pause_flow.on_focus_lost
---@type fun(self: table, was_focused: boolean)
M.on_focus_gained = pause_flow.on_focus_gained

---Forward a window resize to active runtime systems.
---@param self table
---@param data table
function M.on_resize(self, data)
	gameplay.handle_resize(self, data)
end

---Update tutorial timing and apply the resulting gameplay time factor.
---@param self table
---@param dt number
function M.update(self, dt)
	self.time:update(dt)
	gameplay.apply_world_factor(self)
end

---Release persistent services and platform listeners.
---@param self table
function M.final(self)
	ad_state.changed:unsubscribe(M.on_ad_changed, self)
	self.deferred_assets:final()
end

---Route Defold messages to the appropriate app flow.
---@param self table
---@param message_id hash
---@param message table
function M.on_message(self, message_id, message)
	monarch.on_message(message_id, message)
	self.deferred_assets:on_message(message_id, message)
	local handler = message_handlers[message_id]
	if handler then handler(self, message) end
end

return M
