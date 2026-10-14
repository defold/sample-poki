-- Audio commands handled by the app controller.
local M = {}

M.PLAY = hash("audio_play")
M.STOP = hash("audio_stop")
M.GESTURE = hash("audio_gesture")
M.SET_MUTED = hash("audio_set_muted")
M.SET_FOCUSED = hash("audio_set_focused")
M.SET_AD_ACTIVE = hash("audio_set_ad_active")
M.SET_MUSIC = hash("audio_set_music")

return M
