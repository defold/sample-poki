-- Shared screen identifiers and message targets for the app and game collections.
local M = {}

M.SCREEN_GAMEPLAY = hash("gameplay")
M.SCREEN_MOTHERSHIP = hash("mothership")
M.SCREEN_RESULT_POPUP = hash("result_popup")
M.SCREEN_REWARD_CONFIRM_POPUP = hash("reward_confirm_popup")
M.SCREEN_PAUSE_POPUP = hash("pause_popup")
M.SCREEN_CREDITS_POPUP = hash("credits_popup")
M.SCREEN_SKIN_REWARD_POPUP = hash("skin_reward_popup")

M.GAMEPLAY_PROXY = "main:/gameplay_screen#gameplay"
M.GAMEPLAY_CONTROLLER = "gameplay:/controller#gameplay"
M.GAMEPLAY_CAMERA = "gameplay:/camera#camera_controller"
M.GAMEPLAY_HUD = "gameplay:/ui#hud"
M.MOTHERSHIP_CONTROLLER = "mothership:/controller#mothership"
M.MOTHERSHIP_GUI = "mothership:/ui#mothership"
M.APP_CONTROLLER = "main:/app/controller#app"
M.FONT_SUPPORT = "main:/game_fonts#font_support"

M.POPUP_GUI = {
	result = "result_popup:/ui#result",
	rewarded_confirm = "reward_confirm_popup:/ui#reward_confirm",
	rewarded_pending = "reward_confirm_popup:/ui#reward_confirm",
	pause = "pause_popup:/ui#pause",
	credits = "credits_popup:/ui#credits",
	skin_rewarded_confirm = "skin_reward_popup:/ui#skin_reward",
	skin_rewarded_pending = "skin_reward_popup:/ui#skin_reward",
}

return M
