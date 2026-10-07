-- Current ad block, shared by the platform service, gameplay and UI.
local M = {}

local event = require("event.event")

M.changed = event.create()
local busy = false

function M.is_busy()
	return busy
end

-- Store the state before notifying listeners, including nested input handlers.
function M.set_busy(value)
	value = value == true
	if busy == value then return end
	busy = value
	M.changed:trigger(busy)
end

return M
