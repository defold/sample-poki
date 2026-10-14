-- Map of named gameplay sound events to their audio resources.
local M = {}

M.result_win = { url = "main:/game_sounds#result_win", gain = 0.78 }
M.result_fail = { url = "main:/game_sounds#result_fail", gain = 0.78 }
M.laser = { url = "main:/game_sounds#laser", gain = 0.72 }
M.hit = { url = "main:/game_sounds#hit", gain = 1.00 }
M.player_hit = { url = "main:/game_sounds#player_hit", gain = 0.82 }
M.engine = { url = "main:/game_sounds#engine", gain = 0.28 }
M.music = { url = "main:/game_music#music", gain = 0.36 }
M.explosion = { url = "main:/game_sounds#explosion", gain = 0.82 }
M.gold = { url = "main:/game_sounds#gold", gain = 0.88 }
M.upgrade = { url = "main:/game_sounds#upgrade", gain = 0.78 }
M.unlock = { url = "main:/game_sounds#unlock", gain = 0.78 }

return M
