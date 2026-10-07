-- Persistent Defold audio service class.
-- Owned by the app controller.
local M = {}

local math_utils = require("common.math_utils")

local Audio = {}
Audio.__index = Audio

local FADE = 0.8

local function clamp(value, minimum, maximum)
	value = type(value) == "number" and value or minimum
	return math_utils.clamp(value, minimum, maximum)
end

local function output_gain(self)
	return (self.user_muted or self.ad_active or not self.focused) and 0 or 1
end

local function apply_output(self)
	local gain = output_gain(self)
	if gain == self.applied_gain then return true end
	local applied = sound.set_group_gain(self.master_group, gain) ~= false
	if applied then self.applied_gain = gain end
	return applied
end

local function fade_to(self, event_id, gain, duration, done)
	local url = self.events[event_id].url
	self.fade = nil
	if duration <= 0 then
		self.music_gain = gain
		sound.set_gain(url, gain)
		if done then done() end
	else
		self.fade = { url = url, from = self.music_gain or 0, to = gain,
			duration = duration, elapsed = 0, done = done }
	end
end

local function stop_music(self)
	self.fade, self.music_fading = nil, false
	if self.current_music then
		self:stop_event(self.current_music)
		self.current_music = nil
	end
end

local function fade_in(self, event_id)
	fade_to(self, event_id, 0, 0)
	fade_to(self, event_id, self.events[event_id].gain, FADE)
end

local function duck_music(self)
	self.music_fading = false
	if self.current_music then fade_to(self, self.current_music, 0, 0) end
end

local function apply_music(self, resume)
	if self.user_muted then stop_music(self); return true end
	if self.ad_active or not self.focused then duck_music(self); return true end
	local desired = self.desired_music
	if self.music_fading then return true end
	if desired == self.current_music then
		if resume and desired then fade_in(self, desired) end
		return true
	end
	if self.current_music then
		local previous, transition = self.current_music, {}
		self.music_fading = transition
		fade_to(self, previous, 0, FADE, function()
			if self.music_fading ~= transition then return end
			self.music_fading = false
			if self.current_music == previous then
				self:stop_event(previous)
				self.current_music = nil
			end
			apply_music(self)
		end)
		return true
	end
	if desired then
		self.current_music = desired
		self:play_event(desired)
		fade_in(self, desired)
	end
	return true
end

local function set_output_flag(self, key, value)
	value = value == true
	if self[key] == value then return false end
	local was_audible = output_gain(self) > 0
	self[key] = value
	apply_output(self)
	apply_music(self, not was_audible and output_gain(self) > 0)
	return true
end

function Audio:update(dt)
	local fade = self.fade
	if not fade then return end
	fade.elapsed = math.min(fade.elapsed + dt, fade.duration)
	self.music_gain = vmath.lerp(fade.elapsed / fade.duration, fade.from, fade.to)
	sound.set_gain(fade.url, self.music_gain)
	if fade.elapsed == fade.duration then
		self.fade = nil
		if fade.done then fade.done() end
	end
end

function Audio:play_event(event_id, options)
	local definition = self.events[event_id]
	if not definition then return false end
	if self.user_muted then return false end
	if not self.focused then return false end
	if self.ad_active then return false end
	options = options or {}
	local scale = type(options.gain) == "number" and options.gain or 1
	local properties = {
		gain = clamp(scale * definition.gain, 0, 1),
		pan = clamp(options.pan or 0, -1, 1),
		speed = clamp(options.speed or 1, 0.25, 4),
	}
	return sound.play(definition.url, properties) ~= false
end

function Audio:stop_event(event_id)
	local definition = self.events[event_id]
	if not definition then return false end
	return sound.stop(definition.url) ~= false
end

function Audio:stop_all()
	self.desired_music = nil
	stop_music(self)
	for _, definition in pairs(self.events) do sound.stop(definition.url) end
end

function Audio:set_user_muted(muted) return set_output_flag(self, "user_muted", muted) end
function Audio:set_ad_active(active) return set_output_flag(self, "ad_active", active) end
function Audio:set_focused(focused) return set_output_flag(self, "focused", focused) end
function Audio:wanted_music() return self.desired_music end
function Audio:has_event(event_id) return self.events[event_id] ~= nil end

function Audio:bind_event(event_id, definition)
	assert(type(definition) == "table", "Audio event definition required: " .. tostring(event_id))
	assert(definition.url ~= nil, "Audio event URL required: " .. tostring(event_id))
	self.events[event_id] = {
		url = definition.url,
		gain = clamp(definition.gain or 1, 0, 1),
	}
end

function Audio:set_music(event_id)
	if event_id ~= nil and not self.events[event_id] then return false end
	if event_id == self.desired_music then return true end
	self.desired_music = event_id
	return apply_music(self)
end

function M.new(options)
	options = options or {}
	local audio = setmetatable({
		events = {}, master_group = options.master_group or hash("master"),
		user_muted = options.user_muted == true, focused = options.focused ~= false,
		ad_active = options.ad_active == true, desired_music = nil,
		current_music = nil, music_fading = false,
	}, Audio)
	for event_id, definition in pairs(options.events or {}) do
		audio:bind_event(event_id, definition)
	end
	apply_output(audio)
	return audio
end

return M
