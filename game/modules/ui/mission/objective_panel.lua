-- Mission objectives, their opening animation and the boss health bar.
local M = {}

local stat = require("ui.templates.stat")
local bar = require("ui.templates.bar")

local PHASE_PREPLAY, PHASE_PLAYING, PHASE_RESULT = "PREPLAY", "PLAYING", "RESULT"
local ICON_ENEMY = hash("enemy_A")
local ICON_BOSS = hash("station_C")

local OBJECTIVE_SETTLE_SECONDS = 0.42
local OBJECTIVE_START_POSITION = vmath.vector3(0, -100, 0)
local OBJECTIVE_REST_POSITION = vmath.vector3(0, 0, 0)
local SCALE_REST = vmath.vector3(1, 1, 1)
local SCALE_FOCUS_LANDSCAPE = vmath.vector3(1.42, 1.42, 1)
local SCALE_FOCUS_PORTRAIT = vmath.vector3(1.12, 1.12, 1)

local function apply_objective_pose(self, should_animate)
	local panel = gui.get_node("objective_panel")
	local objective_group = gui.get_node("objective_group")
	local position = self.is_objective_focused and OBJECTIVE_START_POSITION or OBJECTIVE_REST_POSITION
	local scale = self.is_objective_focused
		and (self.layout == "portrait" and SCALE_FOCUS_PORTRAIT or SCALE_FOCUS_LANDSCAPE)
		or SCALE_REST
	gui.cancel_animations(objective_group, gui.PROP_POSITION)
	gui.cancel_animations(panel, gui.PROP_SCALE)
	if should_animate then
		gui.animate(objective_group, gui.PROP_POSITION, position, gui.EASING_INOUTQUAD, OBJECTIVE_SETTLE_SECONDS)
		gui.animate(panel, gui.PROP_SCALE, scale, gui.EASING_INOUTQUAD, OBJECTIVE_SETTLE_SECONDS)
	else
		gui.set_position(objective_group, position)
		gui.set_scale(panel, scale)
	end
end

local function set_objective_focused(self, is_focused, should_animate)
	if self.is_objective_focused == is_focused then
		if not should_animate then
			apply_objective_pose(self, false)
		end
		return
	end
	self.is_objective_focused = is_focused
	apply_objective_pose(self, should_animate)
end

local function apply_objective_stat(self, stat_instance, key, progress, required, icon, is_mixed)
	stat_instance:set_visible(true)
	local is_cleared = required > 0 and progress >= required
	if self.result_status == "complete" and required > 0 then
		is_cleared = true
	end
	local is_failed = self.result_status == "fail_objective" and not is_cleared
	local mode = is_failed and "failed" or (is_cleared and "cleared" or nil)
	-- Animate completion once. Regular HUD refreshes must not replay it.
	local should_animate = mode == "cleared" and self.objective_pair_cleared[key] ~= true
		and self.phase ~= PHASE_RESULT
	self.objective_pair_cleared[key] = is_cleared
	if icon then
		stat_instance:set_icon(icon)
	end
	stat_instance:set_counts(progress, required)
	stat_instance:place(not is_mixed)
	stat_instance:set_emphasis(mode, should_animate)
end

local function refresh_objective(self)
	gui.set_enabled(gui.get_node("objective"), false)
	gui.set_enabled(gui.get_node("objective_target_label"), true)
	self.objective_rock:set_visible(false)
	self.objective_enemy:set_visible(false)
	for _, counter in ipairs(self.objectives) do
		local widget = counter.category == "asteroids" and self.objective_rock or self.objective_enemy
		local icon = counter.category == "bosses" and ICON_BOSS or ICON_ENEMY
		apply_objective_stat(self, widget, counter.category,
			counter.progress, counter.required, counter.category ~= "asteroids" and icon or nil,
			#self.objectives > 1)
	end
end

local function refresh_boss_health(self)
	local health, maximum = self.boss_health or 0, self.boss_max_health or 0
	local is_visible = self.phase == PHASE_PLAYING
		and maximum > 0 and health > 0
	gui.set_enabled(gui.get_node("boss_health_icon"), is_visible)
	gui.set_enabled(self.boss_bar.root, is_visible)
	if is_visible then self.objective_enemy:set_visible(false) end
	if not is_visible then return end
	self.boss_bar:set_ratio(health, maximum)
end


function M:init()
	self.objective_text = self.druid:new_lang_text("objective")
	self.objective_target_label = self.druid:new_lang_text("objective_target_label", "hud_target")
	self.objective_rock = self.druid:new_widget(stat, "objective_rock")
	self.objective_enemy = self.druid:new_widget(stat, "objective_enemy")
	self.boss_bar = self.druid:new_widget(bar, "boss_health_bar")
end

function M:refresh()
	refresh_objective(self)
	refresh_boss_health(self)
end

function M:reset()
	self.phase, self.result_status = PHASE_PREPLAY, nil
	self.is_objective_focused = true
	self.objectives = { { category = "asteroids", progress = 0, required = 1 } }
	self.objective_pair_cleared = {}
	self.boss_health, self.boss_max_health = nil, nil
	self.boss_bar:reset()
	self:refresh()
end

function M:set_state(message)
	self.objectives = message.objectives
	self.boss_health, self.boss_max_health = message.boss_health, message.boss_max_health
	self:refresh()
end

function M:set_phase(phase, status)
	self.phase = phase
	self.result_status = phase == PHASE_RESULT and status or nil
	set_objective_focused(self, phase == PHASE_PREPLAY, phase == PHASE_PLAYING)
	self.is_objective_start_pose_pending = phase == PHASE_PREPLAY
	self:refresh()
end

function M:sync_layout()
	self.layout = gui.get_layout() == hash("Portrait") and "portrait" or "landscape"
	self.boss_bar:sync_layout()
	apply_objective_pose(self, false)
	self.is_objective_start_pose_pending = self.phase == PHASE_PREPLAY
	self:refresh()
end

function M:update()
	if self.is_objective_start_pose_pending then
		-- Defold can apply the initial layout after init and on_message.
		self.is_objective_start_pose_pending = false
		apply_objective_pose(self, false)
	end
end

return M
