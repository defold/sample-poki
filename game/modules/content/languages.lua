-- Translation catalogs and language metadata.
local M = {}

local math_utils = require("common.math_utils")

local LANGUAGE_CATALOG = {
	{ id = "en", label = "EN", path = require("resources.languages.en") },
	{ id = "pl", label = "PL", path = require("resources.languages.pl") },
	{ id = "fr", label = "FR", path = require("resources.languages.fr") },
	{ id = "es", label = "ES", path = require("resources.languages.es") },
	{ id = "it", label = "IT", path = require("resources.languages.it") },
	{ id = "de", label = "DE", path = require("resources.languages.de") },
	{ id = "pt", label = "PT", path = require("resources.languages.pt") },
	{ id = "ru", label = "RU", font_asset = "cyrillic", path = require("resources.languages.ru") },
	{ id = "zh", label = "ZH", font_asset = "cjk", path = require("resources.languages.zh") },
	{ id = "ja", label = "JA", font_asset = "cjk", path = require("resources.languages.ja") },
	{ id = "ko", label = "KO", font_asset = "cjk", path = require("resources.languages.ko") },
	{ id = "fa", label = "FA", font_asset = "fa", path = require("resources.languages.fa") },
}

local BY_ID = {}

for _, language in ipairs(LANGUAGE_CATALOG) do
	BY_ID[language.id] = language
end

---Check whether a language has a bundled translation catalog.
---@param language_id string
---@return boolean
function M.is_known(language_id)
	return BY_ID[language_id] ~= nil
end

local function supported_base_language(value)
	if type(value) ~= "string" then
		return nil
	end
	local language_id = value:lower():match("^%s*([a-z][a-z])")
	return M.is_known(language_id) and language_id or nil
end

---Choose a supported preferred system language, falling back to English.
---Regional and script variants such as `pt-BR` and `zh-Hans` use their base language.
---@param system_info table|nil Optional sys.get_sys_info() result for tests.
---@return string
function M.system_default(system_info)
	if system_info == nil and sys and sys.get_sys_info then
		system_info = sys.get_sys_info()
	end
	system_info = type(system_info) == "table" and system_info or {}
	return supported_base_language(system_info.device_language)
		or supported_base_language(system_info.language)
		or "en"
end

---Find the short language label, falling back to English.
---@param language_id string
---@return string
function M.label(language_id)
	local language = BY_ID[language_id]
	return language and language.label or "EN"
end

---Optional deferred font asset id for non-Latin scripts, or nil for Oxanium.
---@param language_id string
---@return string|nil
function M.font_asset_id(language_id)
	local language = BY_ID[language_id]
	return language and language.font_asset or nil
end

---Return the translation catalog for a known language.
---@param language_id string
---@return table|nil
function M.translations(language_id)
	local language = BY_ID[language_id]
	return language and language.path or nil
end

---Fresh `{ id, path }` rows for Lang.init.
---@return table[]
function M.available()
	local available = {}
	for index, language in ipairs(LANGUAGE_CATALOG) do
		available[index] = { id = language.id, path = language.path }
	end
	return available
end

---Cycle to the next or previous language in the player-facing order.
---@param current string
---@param delta integer|nil
---@return string
function M.step_player(current, delta)
	local count = #LANGUAGE_CATALOG
	delta = delta or 1
	for index = 1, count do
		if LANGUAGE_CATALOG[index].id == current then
			return LANGUAGE_CATALOG[math_utils.wrap(index + delta, count)].id
		end
	end
	return "en"
end

return M
