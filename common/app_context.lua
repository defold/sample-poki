-- Current application context for optional consumers.
local M = {}

local event = require("event.event")

M.changed = event.create()
local current = {}

---Return a shallow copy of the latest published app snapshot.
---@return table
function M.get()
	local copy = {}
	for key, value in pairs(current) do copy[key] = value end
	return copy
end

---Replace the app snapshot and notify context listeners.
---@param snapshot table
function M.publish(snapshot)
	current = {}
	for key, value in pairs(snapshot) do current[key] = value end
	M.changed:trigger(M.get())
end

return M
