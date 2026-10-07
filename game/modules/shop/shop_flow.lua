-- Shop purchases, upgrades and navigation.
local M = {}

local progress = require("game.modules.profile.progress")
local addresses = require("common.addresses")
local app_state = require("game.modules.runtime.app_state")
local shop_payload = require("game.modules.shop.shop_payload")
local rewarded = require("game.modules.flow.rewarded")
local client = require("common.audio.client")

local function can_interact_with_shop(self)
	return self.app.screen == "mothership" and not self.active_transition
		and not self.time:has_block("pause")
end

local function send_feedback(self, opts)
	local is_successful = opts.success == true
	local feedback = shop_payload.build(self, {
		kind = opts.kind,
		id = opts.id,
		success = is_successful,
		reason = is_successful and "" or tostring(opts.reason or "unknown"),
	})
	msg.post(addresses.MOTHERSHIP_GUI, opts.message or "shop_feedback", feedback)
	local success_event = (opts.kind == "ship" or opts.kind == "skin") and "unlock" or "upgrade"
	client.play(is_successful and success_event or "ui_error")
	app_state.sync(self)
end

---Apply a shop upgrade purchase and refresh the offer.
---@param self table
---@param message table
function M.on_purchase_upgrade(self, message)
	if not can_interact_with_shop(self) then
		return
	end
	local result = progress.purchase_upgrade(message.id)
	send_feedback(self, {
		message = "purchase_feedback",
		id = message.id,
		success = result.success,
		reason = result.reason,
	})
end

---Buy or equip a ship requested by the shop UI.
---@param self table
---@param message table
function M.on_ship_shop_action(self, message)
	if not can_interact_with_shop(self) then
		return
	end
	local offer = progress.get_ship_offer(message.id)
	if not offer then
		send_feedback(self, { kind = "ship", id = message.id, reason = "unknown_ship" })
		return
	end
	local result
	if offer.is_owned then
		result = progress.equip_ship(message.id)
	else
		result = progress.purchase_ship(message.id)
	end
	send_feedback(self, {
		kind = "ship",
		id = message.id,
		success = result.success,
		reason = result.reason,
	})
end

---Equip an owned skin or open its rewarded offer.
---@param self table
---@param message table
function M.on_skin_shop_action(self, message)
	if not can_interact_with_shop(self) then
		return
	end
	local offer = progress.get_skin_offer(message.id)
	local result
	if not offer then
		result = { success = false, reason = "unknown_skin" }
	elseif offer.is_owned then
		result = progress.equip_skin(message.id)
	else
		result = { success = false, reason = "reward_required" }
	end
	send_feedback(self, { kind = "skin", id = message.id, success = result.success, reason = result.reason })
end

---Open the confirmation for a rewarded skin.
---@param self table
---@param message table
function M.on_skin_rewarded_offer(self, message)
	if not can_interact_with_shop(self) or self.is_rewarded_pending then
		return
	end
	local offer = progress.get_skin_offer(message.id)
	if not offer or offer.is_owned or not offer.is_rewarded then
		return
	end
	self.pending_skin_reward = message.id
	rewarded.show(self, {
		popup = "skin_rewarded_confirm",
		screen = addresses.SCREEN_SKIN_REWARD_POPUP,
		placement = "skin_" .. message.id,
		data = { id = message.id },
	})
end

local function clear_skin_reward(self)
	self.pending_skin_reward = nil
	self.ui.popup = "none"
end

---Cancel the skin ad offer and return to the shop.
---@param self table
function M.on_skin_rewarded_cancel(self)
	if self.app.screen == "mothership" then
		rewarded.cancel(self, { apply = clear_skin_reward })
	end
end

---Start the skin's rewarded ad transaction.
---@param self table
---@param message table
function M.on_skin_rewarded_confirm(self, message)
	local skin_id = self.pending_skin_reward
	local offer = skin_id and progress.get_skin_offer(skin_id)
	if self.app.screen ~= "mothership" or self.is_rewarded_pending
		or message.id ~= skin_id or not offer or offer.is_owned or not offer.is_rewarded then
		return
	end
	rewarded.play(self, {
		screen = addresses.SCREEN_SKIN_REWARD_POPUP,
		placement = "skin_" .. skin_id,
		pending_popup = "skin_rewarded_pending",
		on_idle = clear_skin_reward,
		on_claimed = function()
			local result = progress.reward_skin(skin_id)
			if sys.get_engine_info().is_debug then
				print("[skin_reward] id=" .. skin_id .. " granted=" .. tostring(result.success)
					.. " reason=" .. tostring(result.reason))
			end
			clear_skin_reward(self)
			send_feedback(self, { kind = "skin", id = skin_id, success = result.success, reason = result.reason })
		end,
	})
end

return M
