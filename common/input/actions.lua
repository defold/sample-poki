-- Input action hashes shared by menus and gameplay.
local M = {}

M.primary = hash("primary_action")
M.rewarded = hash("rewarded_action")
M.cancel = hash("cancel_action")
M.reset_save = hash("reset_save")
M.move_left = hash("move_left")
M.move_right = hash("move_right")
M.stick_left = hash("stick_left")
M.stick_right = hash("stick_right")
M.pad_left = hash("pad_left")
M.pad_right = hash("pad_right")
M.menu_up = hash("menu_up")
M.menu_down = hash("menu_down")
M.menu_left = hash("menu_left")
M.menu_right = hash("menu_right")
M.touch = hash("touch")
M.touch_multi = hash("touch_multi")

function M.is_touch(action_id)
	return action_id == M.touch or action_id == M.touch_multi
end

function M.is_pointer(action_id)
	return M.is_touch(action_id) or action_id == nil
end

function M.is_menu_vertical(action_id)
	return action_id == M.menu_up or action_id == M.menu_down
end

function M.is_menu_horizontal(action_id)
	return action_id == M.menu_left or action_id == M.menu_right
end

return M
