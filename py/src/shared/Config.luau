-- Config.luau
-- Shared game configuration for Python Tower Defense

local Config = {
	--============================================================================
	-- GAME MODE
	--============================================================================
	GAME_MODE = "TowerDefense",
	LANGUAGE = "Python",

	--============================================================================
	-- MAP SETTINGS
	--============================================================================
	MAP_SIZE = 180,
	CELL_SIZE = 6,
	WALL_HEIGHT = 6,
	FLOOR_HEIGHT = 0,
	PLATFORM_Y = 50, -- Ground level Y coordinate (elevated platform)
	WALL_MATERIAL = Enum.Material.Concrete,
	FLOOR_MATERIAL = Enum.Material.Slate,

	--============================================================================
	-- PLAYER SETTINGS
	--============================================================================
	DEFAULT_HP = 200,
	DEFAULT_MAX_STACK = 10,
	MANUAL_WALKING_SPEED = 16,
	PLAYER_SPEED = 1.0,
	STARTING_AMMO = 500,

	--============================================================================
	-- COMBAT SETTINGS
	--============================================================================
	ATTACK_RANGE = 6,
	ATTACK_DAMAGE = 30,

	--============================================================================
	-- TOWER DEFENSE SETTINGS
	--============================================================================
	STARTING_SCRAP = 600,
	SCRAP_PER_KILL = 15,
	WAVE_BONUS_BASE = 200,
	CORE_HP = 1000,
	BUILD_PHASE_TIME = 30,

	-- Golem tick rates
	GOLEM_TICK_RATE = 0.1,
	GOLEM_TICKS_PER_UPDATE = 1,

	REFILL_RANGE = 8,

	--============================================================================
	-- ENEMY SETTINGS
	--============================================================================
	ENEMY_TYPES = {
		Zombie = { hp = 50, speed = 6, damage = 10, scrap = 5 },
		Runner = { hp = 30, speed = 12, damage = 5, scrap = 3 },
		Tank = { hp = 200, speed = 4, damage = 30, scrap = 15 },
		Boss = { hp = 1000, speed = 5, damage = 100, scrap = 100 },
	},

	--============================================================================
	-- INTERPRETER TIMING
	--============================================================================
	PLAYER_TICK_RATE = 0.1,
	MONSTER_TICK_RATE = 0.5,
	BOT_TICK_RATE = 0.1,
	BOT_TICKS_PER_UPDATE = 1,
	BOT_FREE_STEPS_PER_TICK = 8,
	PLAYER_TICKS_PER_UPDATE = 1,
	MONSTER_TICKS_PER_UPDATE = 1,
	PLAYER_FREE_STEPS_PER_TICK = 1,
	MONSTER_FREE_STEPS_PER_TICK = 500,
	GOLEM_FREE_STEPS_PER_TICK = 8,
	SCRAP_ASSIST_BONUS = 2,

	--============================================================================
	-- CO-OP SETTINGS
	--============================================================================
	REVIVE_RANGE = 6,
	GIVE_RANGE = 8,
	RESPAWN_TIME = 10,

	--============================================================================
	-- SENSING
	--============================================================================
	SENSE_RANGE = 50,
	MONSTER_SENSE_RANGE = 40,

	--============================================================================
	-- LIGHTING
	--============================================================================
	LIGHTING = {
		FOG_COLOR = Color3.fromRGB(50, 60, 80),
		FOG_START = 100,
		FOG_END = 400,
		AMBIENT = Color3.fromRGB(80, 85, 100),
		OUTDOOR_AMBIENT = Color3.fromRGB(100, 105, 120),
		BRIGHTNESS = 2.5,
		START_TIME = 10,
	},

	DAY_NIGHT_CYCLE = {
		ENABLED = false,
		SECONDS_PER_HOUR = 300,
		NIGHT_BRIGHTNESS = 0.6,
		DAWN_BRIGHTNESS = 0.8,
		DAY_BRIGHTNESS = 1.0,
		DUSK_BRIGHTNESS = 0.8,
		NIGHT_AMBIENT = Color3.fromRGB(40, 40, 60),
		DAWN_AMBIENT = Color3.fromRGB(80, 70, 90),
		DAY_AMBIENT = Color3.fromRGB(80, 85, 100),
		DUSK_AMBIENT = Color3.fromRGB(90, 70, 70),
	},
}

return Config
