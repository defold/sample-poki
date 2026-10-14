-- List of collections packed into the shared deferred-assets ZIP.
local M = {}

M.archive = {
	mount_name = "deferred_liveupdate_v5",
	remote_url = "./deferred_liveupdate.zip",
	cache_filename = "deferred_liveupdate_v5.zip",
	priority = 20,
}

M.packs = {
	fa = {
		proxy = "main:/game_deferred_assets#fa_font",
	},
	cyrillic = {
		proxy = "main:/game_deferred_assets#cyrillic_font",
	},
	cjk = {
		proxy = "main:/game_deferred_assets#cjk_font",
	},
	audio = {
		proxy = "main:/game_deferred_assets#deferred_audio",
		sound_url = "deferred_audio:/audio#audio",
	},
}

return M
