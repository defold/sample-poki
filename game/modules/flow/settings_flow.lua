-- Settings handling - audio volume control and language switching.
local M = {}

local progress = require("game.modules.profile.progress")
local languages = require("game.modules.content.languages")
local druid = require("druid.druid")
local addresses = require("common.addresses")
local app_state = require("game.modules.runtime.app_state")
local client = require("common.audio.client")

local function notify_language_download(self, language_id, status, reason)
	local popup_gui = addresses.POPUP_GUI[self.ui.popup]
	if popup_gui then
		msg.post(popup_gui, "language_download", {
			language = language_id,
			status = status,
			reason = reason,
		})
	end
end

local function commit_language(self, language_id)
	local is_applied = progress.set_language(language_id)
	if is_applied then M.propagate_language(self) end
	return is_applied
end

---Apply a requested language when its font becomes available.
---@param self table
---@param message table
function M.on_deferred_font_ready(self, message)
	local asset_id = message and message.pack
	if not asset_id then return end
	msg.post(addresses.FONT_SUPPORT, "font_pack_ready", { pack = asset_id })
	local pending = self.pending_language
	if pending and languages.font_asset_id(pending) == asset_id then
		self.pending_language = nil
		local is_applied = commit_language(self, pending)
		notify_language_download(self, pending, is_applied and "ready" or "failed")
		return
	end
	if languages.font_asset_id(self.app.language) == asset_id then
		msg.post(addresses.FONT_SUPPORT, "language_changed", {
			language = self.app.language,
		})
	end
end

---Recover the previous language after font loading fails.
---@param self table
---@param message table
function M.on_deferred_font_failed(self, message)
	local asset_id = message and message.pack
	if not asset_id then return end
	local reason = message and message.reason or "unknown"
	local pending = self.pending_language
	if pending and languages.font_asset_id(pending) == asset_id then
		self.pending_language = nil
		notify_language_download(self, pending, "failed", reason)
	end
end

---Send the selected language to every visible screen.
---@param self table
function M.propagate_language(self)
	self.app.language = progress.snapshot().language
	druid.on_language_change()
	msg.post(addresses.FONT_SUPPORT, "language_changed", { language = self.app.language })
	local popup_gui = addresses.POPUP_GUI[self.ui.popup]
	if popup_gui then msg.post(popup_gui, "language_changed", { language = self.app.language }) end
	if self.app.screen == "gameplay" and self.is_gameplay_ready then
		msg.post(addresses.GAMEPLAY_HUD, "language_changed", { language = self.app.language })
	elseif self.app.screen == "mothership" and self.is_mothership_ready then
		msg.post(addresses.MOTHERSHIP_GUI, "language_changed", { language = self.app.language })
	end
	app_state.sync(self)
end

---Update saved mute state and the live audio service.
---@param self table
---@param is_muted boolean
---@return table result
function M.apply_muted(self, is_muted)
	is_muted = is_muted == true
	local result = progress.set_muted(is_muted)
	if not result.success then
		return { is_accepted = false, reason = result.reason or "invalid_muted",
			is_muted = self.app.is_muted == true }
	end
	self.app.is_muted = is_muted
	client.set_muted(is_muted)
	client.set_focused(true)
	if self.ui.popup == "pause" then
		msg.post(addresses.POPUP_GUI.pause, "audio_state", { muted = is_muted })
	end
	client.play("ui_click")
	app_state.sync(self)
	return { is_accepted = true, is_muted = is_muted }
end

---Toggle the player's sound preference.
---@param self table
function M.on_mute_toggle(self)
	M.apply_muted(self, not (self.app.is_muted == true))
end

---Handle a language selection message from the UI.
---@param self table
---@param message table
function M.on_set_language(self, message)
	local language_id = message and message.language
	if language_id then M.request_language(self, language_id) end
end

---Apply a language immediately or request its font download.
---@param self table
---@param language_id string
---@return boolean is_accepted Whether the language was applied, unchanged, or queued for download.
function M.request_language(self, language_id)
	if not language_id or not languages.is_known(language_id) then
		return false
	end
	if language_id == self.app.language and not self.pending_language then
		return true
	end

	self.pending_language = nil
	local asset_id = languages.font_asset_id(language_id)
	if not asset_id or self.deferred_assets:is_ready(asset_id) then
		return commit_language(self, language_id)
	end

	self.pending_language = language_id
	notify_language_download(self, language_id, "pending")
	self.deferred_assets:request(asset_id)
	return true
end

return M
