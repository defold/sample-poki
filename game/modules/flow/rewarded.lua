-- Shared rewarded confirmation, ad and claim flow for rescue and skin grants.
local M = {}

local monarch = require("monarch.monarch")
local poki_service = require("app.modules.platform.poki_service")
local gameplay = require("game.modules.runtime.gameplay")
local app_state = require("game.modules.runtime.app_state")
local client = require("common.audio.client")

local function popup_data(self, data)
	local payload = {
		input_mode = self.app.input_mode,
		device_category = self.app.device_category,
	}
	if data then
		for key, value in pairs(data) do
			payload[key] = value
		end
	end
	return payload
end

local function dismiss_confirm(self, screen, on_closed)
	local function complete()
		gameplay.set_input_blocker(self, false)
		app_state.sync(self)
		on_closed()
	end
	if monarch.is_top(screen) then
		monarch.back({ sequential = true }, nil, complete)
	else
		complete()
	end
end

---Open a rewarded confirmation popup for the current offer.
---@param self table
---@param opts table
function M.show(self, opts)
	self.ui.popup = opts.popup
	client.play("ui_rewarded")
	if opts.placement then
		poki_service.measure("rewarded", opts.placement, "visible")
	end
	app_state.sync(self)
	gameplay.cancel_ui_input(self)
	monarch.show(opts.screen, { sequential = true }, popup_data(self, opts.data))
end

---Dismiss an offer and clear its pending transaction.
---@param self table
---@param opts table
function M.cancel(self, opts)
	if self.is_rewarded_pending then
		return
	end
	monarch.back({ sequential = true })
	if opts and opts.apply then
		opts.apply(self)
	end
	client.play("ui_click")
	app_state.sync(self)
end

---Play the rewarded break.
---`on_claimed` runs after SDK success and a one-use transaction claim.
---`on_idle` restores the pre-ad popup when the player cancels or the request is rejected.
---@param self table
---@param opts table
function M.play(self, opts)
	if self.is_rewarded_pending then
		return
	end
	self.is_rewarded_pending = true
	self.ui.popup = opts.pending_popup
	client.play("ui_rewarded")
	poki_service.measure("rewarded", opts.placement, "interact")
	app_state.sync(self)

	local is_finished = false
	local function finish(result)
		-- Ignore repeated callbacks, including a callback after rejection.
		if is_finished then return end
		is_finished = true
		local claim = { success = false, reason = "ad_" .. tostring(result.outcome) }
		if result.rewarded and result.outcome == poki_service.RESULT_SUCCESS then
			claim = poki_service.claim_reward(result.transaction_id)
		end
		if not claim.success and sys.get_engine_info().is_debug then
			print("[rewarded_flow] placement=" .. opts.placement
				.. " outcome=" .. tostring(result.outcome)
				.. " claim_reason=" .. tostring(claim.reason))
		end
		dismiss_confirm(self, opts.screen, function()
			self.is_rewarded_pending = false
			if claim.success then
				opts.on_claimed(result)
				return
			end
			if opts.on_idle then opts.on_idle(self) end
			client.play(result.outcome == poki_service.RESULT_CANCEL and "ui_click" or "ui_error")
			app_state.sync(self)
		end)
	end

	local is_accepted = poki_service.rewarded_break({
		placement = opts.placement,
		size = opts.size or "medium",
	}, finish)

	if not is_accepted then
		finish({ outcome = poki_service.RESULT_ERROR, rewarded = false })
	end
end

return M
