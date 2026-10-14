-- A labeled count and fill bar for the player's health or ammunition.
local M = {}

local stat = require("ui.templates.stat")
local bar = require("ui.templates.bar")

function M:init(kind, label)
	self.kind = kind
	self.stat = self.druid:new_widget(stat, kind .. "_stat", nil, label)
	self.bar = self.druid:new_widget(bar, kind .. "_bar")
end

function M:set_counts(current, maximum)
	self.stat:set_counts(current, maximum)
	self.bar:set_ratio(current, maximum)
end

function M:set_result(status)
	local failed = status == "fail_" .. self.kind
	self.stat:set_emphasis(failed and "failed" or nil)
	self.bar:set_failed(failed)
end

function M:reset()
	self.bar:reset()
	self:set_result(nil)
end

function M:flash()
	self.bar:flash()
end

function M:sync_layout()
	self.bar:sync_layout()
end

return M
