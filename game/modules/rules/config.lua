-- Defines shared gameplay constants, limits and progression values.
local M = {}

M.STATUS = {
	PLAYING = "playing",
	COMPLETE = "complete",
	FAIL_HEALTH = "fail_health",
	FAIL_AMMO = "fail_ammo",
	FAIL_OBJECTIVE = "fail_objective",
}

M.PLAYER = {
	projectile_speed = 55,
	corridor_half_width = 9.6,
	lane_width = 2.9,
	min_lane = -3,
	max_lane = 3,
	invulnerability_seconds = 0.75,
}

M.ASTEROID = {
	health = 20,
	collision_damage = 18,
	tiers = {
		{ health = 20, scale = 0.94, credit_bonus = 5, collision_damage = 18 },
		{ health = 40, scale = 1.34, credit_bonus = 10, collision_damage = 28 },
		{ health = 60, scale = 1.72, credit_bonus = 15, collision_damage = 40 },
	},
}

M.ENEMY = {
	health = 40,
	approach_speed_factor = 0.75,
	credit_per_stock_hit = 3,
	model_scale = 1.6,
	projectile_damage = 15,
	contact_damage = 15,
	projectile_speed = 18,
	initial_fire_delay = 1.25, 	-- Regular enemies shoot less frequently at the beginning
	minimum_initial_fire_delay = 0.35,
	initial_fire_delay_level_step = 0.06,
	fire_interval = 3.4,
	minimum_fire_interval = 1.2,
	fire_interval_level_step = 0.10,
	horizontal_amplitude = 2.55,
	horizontal_frequency = 0.8,
}

M.BOSS = {
	health = 2200,
	credit_per_stock_hit = 4,
	model_scale = 3.6,
	initial_fire_delay = 0.25,
	fire_interval = 0.55,
	horizontal_amplitude = 4.3,
	horizontal_frequency = 0.42,
}

M.GOLD = {
	credit_multiplier = 2,
}

M.RESCUE = {
	refill_fraction = 0.5,
	shield_seconds = 2.5,
}

-- Missions 1-5 add more ammo cells on pickup.
M.EARLY_MISSION_AMMO_BONUS = {
	[1] = 16,
	[2] = 12,
	[3] = 10,
	[4] = 8,
	[5] = 8,
}
M.AMMO_PICKUP = {
	amount = 5,
	maximum_count = 3,
}

-- After a failed run we should still give some credits to player, to allow to buy upgrades.
-- This prevents an upgrade deadlock, and one can replay the failed mission to earn more.
M.ECONOMY = {
	fail_reward_ratio = 0.25,
	minimum_fail_reward = 10,
}

M.SHIPS = {
	scout = {
		id = "scout",
		health = 50,
		ammo = 48,
		damage = 10,
		fire_cooldown = 0.28,
		move_speed = 13,
		price = 0,
	},
	interceptor = {
		id = "interceptor",
		health = 100,
		ammo = 82,
		damage = 22,
		fire_cooldown = 0.24,
		move_speed = 15,
		price = 700,
		available_after_mission = 1,
	},
	comet = {
		id = "comet",
		health = 200,
		ammo = 108,
		damage = 30,
		fire_cooldown = 0.18,
		move_speed = 18,
		price = 1400,
		available_after_mission = 5,
	},
}

M.SHIP_ORDER = { "scout", "interceptor", "comet" }

-- Skins use color palettes and we map these ids to shader constants for every supported player model.
M.SKINS = {
	standard = { id = "standard" },
	solar = { id = "solar", is_rewarded = true },
	nebula = { id = "nebula", is_rewarded = true },
}

M.SKIN_ORDER = { "standard", "solar", "nebula" }

-- Next purchase costs base + current_level * step (80, 160, 240, ...).
-- Each level adds the same step bonus.
M.UPGRADE_PRICE_BASE = 80
M.UPGRADE_PRICE_STEP = 80
M.MIN_FIRE_COOLDOWN = 0.08

M.UPGRADE_ORDER = { "damage", "ammo", "hull", "firerate" }

M.UPGRADES = {
	damage = {
		stat = "damage",
		amount_per_level = 5,
	},
	ammo = {
		stat = "ammo",
		amount_per_level = 12,
	},
	hull = {
		stat = "health",
		amount_per_level = 20,
	},
	firerate = {
		stat = "fire_cooldown",
		amount_per_level = 0.04,
		is_inverted = true,
	},
}

return M
