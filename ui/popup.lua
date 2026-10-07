-- Shared setup, focus and input handling for popups, including rewarded confirmations.
local M = {}

local druid = require("druid.druid")
local monarch = require("monarch.monarch")
local screen_transitions = require("ui.screen_transitions")
local screen_input = require("ui.screen_input")
local actions = require("common.input.actions")
local colors = require("ui.colors")
local button = require("ui.templates.button")

local function bind_lang_text(instance, node_id, key)
	local default_text = gui.get_text(gui.get_node(node_id))
	local widget = instance:new_lang_text(node_id, key)
	if not key then
		widget:set_text(default_text)
	end
	return widget
end

---Prepare the shared Druid, motion, and input state for a popup.
---@param self table
---@param opts table
---@return table
function M.setup(self, opts)
	gui.set_render_order(opts.render_order or 10)
	local data = {}
	if opts.screen and monarch.screen_exists(opts.screen) then
		data = monarch.data(opts.screen) or {}
	end
	screen_input.init(self, data)
	self.druid = druid.new(self)
	self.motion = screen_transitions.new(opts.name)
	if opts.title then
		self.title_text = bind_lang_text(self.druid, opts.title, opts.title_key)
	end
	if opts.detail then
		self.detail_text = bind_lang_text(self.druid, opts.detail, opts.detail_key)
	end
	self.blocker = self.druid:new_blocker(opts.blocker)
	self.refresh = opts.refresh
	self.on_reset = opts.on_reset
	return data
end

---Restore button state when this popup regains Monarch focus.
---@param self table
---@param screen hash|string
---@param buttons table
---@param apply function
function M.watch_focus(self, screen, buttons, apply)
	monarch.on_focus_changed(screen, function(id)
		for index = 1, #buttons do
			buttons[index]:cancel_press()
		end
		if id == monarch.FOCUS_GAINED then
			local current = monarch.data(screen) or {}
			screen_input.restore(self, current)
			apply(self, current)
			self.refresh(self)
			self.motion:restore_focus()
		end
	end)
end

---Clean up popup widgets and input focus.
---@param self table
function M.final(self)
	self.motion:final()
	if self.druid then
		self.druid:final()
		self.druid = nil
	end
end

---Advance popup animation and widget state.
---@param self table
---@param dt number
function M.update(self, dt)
	if self.druid then
		self.druid:update(dt)
	end
end

---Dispatch engine messages to Monarch and Druid.
---@param self table
---@param id string|hash
---@param message table
---@param sender url
function M.on_message(self, id, message, sender)
	if not self.druid then
		return
	end
	if id == hash("layout_changed") then
		self.motion:resize()
		if self.title_text then
			self.title_text.text:set_size(gui.get_size(self.title_text.node))
		end
		if self.detail_text then
			self.detail_text.text:set_size(gui.get_size(self.detail_text.node))
		end
	end
	monarch.on_message(id, message, sender)
	self.druid:on_message(id, message, sender)
	if id == hash("language_changed") then
		self.refresh(self)
	end
end

---Route input through the popup and optional remapper.
---@param self table
---@param action_id hash
---@param action table
---@param remap function
---@return boolean
function M.consume_input(self, action_id, action, remap)
	if screen_input.handle_common_input(self, action_id, action, {
		blocked = not self.druid or self.motion:is_input_blocked(),
		on_reset = self.on_reset,
	}) then
		return true
	end
	local id = action_id
	local button_input = screen_input.route(self, action_id, action, {
		on_mode = function()
			self.refresh(self)
		end,
	})
	if remap then
		id = remap(id) or id
	end
	self.druid:on_input(id, button_input)
	return true
end

---Default popup input callback. Individual popups may wrap it to add their own controls.
---@type fun(self: table, action_id: hash|nil, action: table): boolean
M.on_input = M.consume_input

---Watch Video / Not Now pair used by rescue and skin rewarded confirmations.
---@param title_key string
---@param detail_key string
---@return fun(self: table)
function M.create_rewarded_refresh(title_key, detail_key)
	return function(self)
		self.title_text:translate(title_key)
		self.detail_text:translate(detail_key)
		self.watch:set_lang(self.is_pending and "rewarded_wait" or "rewarded_watch")
			:set_input_prompt("rewarded", self.input_mode)
			:set_color(colors.rewarded):set_left_icon(hash("video"))
		self.cancel:set_lang("rewarded_not_now"):set_input_prompt("cancel", self.input_mode)
	end
end

---Connect rewarded confirmation buttons and their focus lifecycle.
---@param self table
---@param opts table
function M.bind_watch_cancel(self, opts)
	local data = M.setup(self, opts)
	opts.read(self, data)
	self.is_pending = false
	self.watch = self.druid:new_widget(button, opts.watch, nil, function()
		if self.is_pending then return end
		self.is_pending = true
		self.watch:set_enabled(false)
		self.cancel:set_enabled(false)
		self.refresh(self)
		opts.on_confirm(self)
	end)
	self.watch:set_key_trigger(actions.rewarded)
	self.cancel = self.druid:new_widget(button, opts.cancel, nil, function()
		if self.is_pending then return end
		self.is_pending = true
		self.watch:set_enabled(false)
		self.cancel:set_enabled(false)
		opts.on_cancel(self)
	end)
	self.cancel:set_key_trigger(actions.cancel)
	M.watch_focus(self, opts.screen, { self.watch, self.cancel }, function(self, current)
		opts.read(self, current)
		self.is_pending = false
		self.watch:set_enabled(true)
		self.cancel:set_enabled(true)
	end)
	self.refresh(self)
	M.acquire()
end

---Request input focus for the active popup.
function M.acquire()
	msg.post(".", "acquire_input_focus")
end

return M
