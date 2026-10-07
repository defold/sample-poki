-- Sends audio commands to the app controller.
local M = {}

local messages = require("common.audio.messages")

local app_controller

function M.configure(url)
	assert(url ~= nil, "audio client requires an app controller URL")
	app_controller = url
end

local function post(message_id, data)
	assert(app_controller ~= nil, "audio client is not configured")
	msg.post(app_controller, message_id, data)
end

function M.play(event_id, options)
	local message = { id = event_id }
	for key, value in pairs(options or {}) do message[key] = value end
	post(messages.PLAY, message)
end

function M.stop(event_id)
	post(messages.STOP, { id = event_id })
end

function M.gesture()
	post(messages.GESTURE)
end

function M.set_muted(muted)
	post(messages.SET_MUTED, { muted = muted == true })
end

function M.set_focused(focused)
	post(messages.SET_FOCUSED, { focused = focused == true })
end

function M.set_ad_active(active)
	post(messages.SET_AD_ACTIVE, { active = active == true })
end

function M.set_music(event_id)
	post(messages.SET_MUSIC, { id = event_id })
end

return M
