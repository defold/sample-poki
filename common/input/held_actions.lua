-- Track held controls across Defold frames, including missing release events.
local M = {}

function M.sample(sources, source, held, pressed)
	if not held then
		sources[source] = nil
	elseif pressed or sources[source] ~= nil then
		sources[source] = true
	end
end

function M.any(sources)
	for _, sampled in pairs(sources) do
		if sampled then return true end
	end
	return false
end

-- Keep each source for one more frame so the next held sample can renew it.
-- Clearing the table on interruption requires the player to press again.
function M.finish_frame(sources)
	for source, sampled in pairs(sources) do
		if sampled then sources[source] = false else sources[source] = nil end
	end
end

return M
