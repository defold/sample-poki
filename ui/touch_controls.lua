-- Touch-specific controls and input hints for gameplay UI.
local M = {}

local math_utils = require("common.math_utils")
local actions = require("common.input.actions")

local MOUSE_ID = -1
local DEADZONE = 0.18
local TRAVEL = 0.72
local SYNTHETIC_MOUSE_SECONDS = 0.45

local function pointer_id(action)
	if type(action.id) == "number" then
		return action.id
	end
	return MOUSE_ID
end

local function local_delta(self, action)
	local position = gui.screen_to_local(self.stick_nub,
		vmath.vector3(action.screen_x or action.x, action.screen_y or action.y, 0))
	return position
end

local function set_nub(self, x, y)
	self.nub_pos.x = x
	self.nub_pos.y = y
	self.nub_pos.z = 0
	gui.set_position(self.stick_nub, self.nub_pos)
end

local function release_stick(self)
	self.stick_id = nil
	self.stick_sampled = false
	self.axis = 0
	set_nub(self, 0, 0)
end

local function release_fire(self)
	self.fire_id = nil
	self.fire_sampled = false
	self.is_fire_held = false
	gui.set_color(self.fire_button, self.fire_color)
end

local function apply_stick(self, action)
	local delta = local_delta(self, action)
	local dx, dy = delta.x, delta.y
	local length = math.sqrt(dx * dx + dy * dy)
	if length > self.radius and length > 0 then
		dx = dx * self.radius / length
		dy = dy * self.radius / length
		length = self.radius
	end
	set_nub(self, dx, dy)
	local axis = self.radius > 0 and dx / self.radius or 0
	if math.abs(axis) < DEADZONE then
		axis = 0
	end
	self.axis = math_utils.clamp(axis, -1, 1)
end

---Create the virtual controls and their initial visibility.
---@param self table
function M.init(self)
	self.stick_base = gui.get_node("stick_base")
	self.stick_nub = gui.get_node("stick_nub")
	self.fire_button = gui.get_node("fire_touch")
	self.nub_pos = vmath.vector3()
	self.fire_color = gui.get_color(self.fire_button)
	self.fire_pressed_color = vmath.vector4(
		self.fire_color.x * 0.82, self.fire_color.y * 0.82,
		self.fire_color.z * 0.82, self.fire_color.w)
	self.stick_id = nil
	self.fire_id = nil
	self.axis = 0
	self.is_fire_held = false
	self.is_touch_overlay_visible = false
	self.is_force_visible = false
	self.is_device_mobile = false
	self.is_touch_detected = false
	self.ignore_mouse_until = 0
	self.radius = gui.get_size(self.stick_base).x * 0.5 * TRAVEL
	M.refresh(self)
end

---Release the virtual controls when the screen is destroyed.
---@param self table
function M.release(self)
	release_stick(self)
	release_fire(self)
end

---Show or hide virtual controls for the current input mode.
---@param self table
function M.refresh(self)
	local is_visible = self.is_device_mobile or self.is_touch_detected or self.is_force_visible
	if not is_visible then
		M.release(self)
	end
	self.is_touch_overlay_visible = is_visible
	gui.set_enabled(self.stick_base, is_visible)
	gui.set_enabled(self.fire_button, is_visible)
	gui.set_visible(self.stick_base, is_visible)
	gui.set_visible(self.fire_button, is_visible)
	if is_visible then
		gui.set_alpha(self.stick_base, 1)
		gui.set_alpha(self.stick_nub, 1)
		gui.set_alpha(self.fire_button, 1)
		self.radius = gui.get_size(self.stick_base).x * 0.5 * TRAVEL
	end
end

---Update touch controls when the device category changes.
---@param self table
---@param category string
function M.set_device_category(self, category)
	self.is_device_mobile = category == "mobile" or category == "tablet"
	M.refresh(self)
end

---Remember that the player interacted through touch.
---@param self table
---@return boolean has_become_visible
function M.note_touch(self)
	if self.is_touch_detected then return false end
	local is_overlay_already_visible = self.is_touch_overlay_visible
	self.is_touch_detected = true
	M.refresh(self)
	return not is_overlay_already_visible
end

---Toggle the development override for showing touch controls.
---@param self table
---@return boolean is_visible
function M.toggle_force(self)
	self.is_force_visible = not self.is_force_visible
	M.refresh(self)
	return self.is_touch_overlay_visible
end

---Reposition virtual controls after a layout change.
---@param self table
function M.on_layout(self)
	-- Applying a GUI layout restores serialized node properties.
	-- Both controls are disabled in the base layout, so restore their runtime visibility too.
	M.refresh(self)
end

local function handle_pointer(self, action, id, result)
	if self.fire_id == id and not action.released then
		self.fire_sampled = true
		result.consumed, result.fire_changed = true, true
		return
	end
	if self.stick_id == id and not action.released then
		self.stick_sampled = true
		apply_stick(self, action)
		result.consumed, result.steer_changed = true, true
		return
	end
	if action.pressed and not action.repeated and self.fire_id ~= id and self.stick_id ~= id then
		if self.fire_id == nil and gui.pick_node(self.fire_button, action.x, action.y) then
			self.fire_id = id
			self.fire_sampled = true
			self.is_fire_held = true
			gui.set_color(self.fire_button, self.fire_pressed_color)
			if action.released then release_fire(self) end
			result.consumed, result.fire_changed, result.fire_started = true, true, true
		elseif self.stick_id == nil and gui.pick_node(self.stick_base, action.x, action.y) then
			self.stick_id = id
			self.stick_sampled = true
			apply_stick(self, action)
			if action.released then release_stick(self) end
			result.consumed, result.steer_changed, result.steer_started = true, true, true
		end
		return
	end
	if self.stick_id == id then
		if action.released then release_stick(self) else apply_stick(self, action) end
		result.consumed, result.steer_changed = true, true
	end
	if self.fire_id == id then
		result.consumed = true
		if action.released then
			release_fire(self)
			result.fire_changed = true
		end
	end
end

-- Defold reports held touches and buttons each input frame.
-- Clear the held control when Defold stops reporting it, such as when an overlay handles the player's release.
function M.finish_frame(self)
	local stick_missing = self.stick_id ~= nil and not self.stick_sampled
	local fire_missing = self.fire_id ~= nil and not self.fire_sampled
	if stick_missing then release_stick(self) end
	if fire_missing then release_fire(self) end
	self.stick_sampled, self.fire_sampled = false, false
	return { steer_released = stick_missing, fire_released = fire_missing }
end

---Process all pointers in one input event and report which controls need updating.
function M.on_input(self, action_id, action)
	local result = {}
	if not self.is_touch_overlay_visible or type(action) ~= "table" then return result end
	if action_id == actions.touch_multi and type(action.touch) == "table" then
		self.ignore_mouse_until = socket.gettime() + SYNTHETIC_MOUSE_SECONDS
		-- Replace the emulated mouse press when the player starts using real touches.
		if self.stick_id == MOUSE_ID then
			release_stick(self)
			result.steer_changed = true
		end
		if self.fire_id == MOUSE_ID then
			release_fire(self)
			result.fire_changed = true
		end
		for _, touch in ipairs(action.touch) do
			handle_pointer(self, touch, pointer_id(touch), result)
		end
	elseif action_id == actions.touch then
		if socket.gettime() <= (self.ignore_mouse_until or 0) then
			result.consumed = true
		else
			handle_pointer(self, action, pointer_id(action), result)
		end
	elseif action_id == nil and self.stick_id == MOUSE_ID then
		apply_stick(self, action)
		result.consumed, result.steer_changed = true, true
	end
	return result
end

return M
