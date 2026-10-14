-- Manages keyboard, gamepad and touch focus across shop controls.
local M = {}

local math_utils = require("common.math_utils")
local config = require("game.modules.rules.config")

M.SHIP = 1
M.SKIN = 2
M.CONTINUE = #config.UPGRADE_ORDER + 3
M.FIRST_UPGRADE = 3
M.UPGRADE_IDS = config.UPGRADE_ORDER

---Start shop navigation at its default focus target.
---@return table
function M.new()
	return {
		focus = M.CONTINUE,
		selected_ship_id = "scout",
		selected_skin_id = "standard",
	}
end

---Find the upgrade represented by the current focus entry.
---@param focus integer
---@return string|nil
function M.upgrade_id(focus)
	if focus >= M.FIRST_UPGRADE and focus < M.CONTINUE then
		return M.UPGRADE_IDS[focus - M.FIRST_UPGRADE + 1]
	end
end

local function index_of(items, value)
	for index, item in ipairs(items or {}) do
		if item == value then
			return index
		end
	end
	return 1
end

---Wrap shop focus forward or backward through its rows.
---@param focus integer
---@param delta integer
---@return integer
function M.step(focus, delta)
	return math_utils.wrap(focus + delta, M.CONTINUE)
end

---Select an item relative to the current value, wrapping at either end.
---@param order string[]|nil
---@param current string|integer
---@param delta integer
---@return string|integer
function M.cycle(order, current, delta)
	order = order or { current }
	return order[math_utils.wrap(index_of(order, current) + delta, #order)]
end

---Move focus.
---Leaving the ship or skin row restores the equipped preview id.
---@return boolean has_preview_changed
---@param nav table
---@param index integer
---@param state table
function M.set_focus(nav, index, state)
	local previous = nav.focus
	nav.focus = math_utils.clamp(index, 1, M.CONTINUE)
	local has_preview_changed = false
	if state and previous == M.SHIP and nav.focus ~= M.SHIP then
		nav.selected_ship_id = state.equipped_ship or "scout"
		has_preview_changed = true
	elseif state and previous == M.SKIN and nav.focus ~= M.SKIN then
		nav.selected_skin_id = state.equipped_skin or "standard"
		has_preview_changed = true
	end
	return has_preview_changed
end

return M
