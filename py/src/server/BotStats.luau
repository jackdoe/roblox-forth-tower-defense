local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local BotStats = {}

BotStats.GROUND_Y = Config.PLATFORM_Y

BotStats.DEFAULT_PROGRAM = [[
while True:
    if self.collect():
        if self.carrying() >= 3:
            self.teleport([0, 0])
            self.deposit()
]]

BotStats.BASE = {
	name = "SupplyBot",
	speed = 14,
	maxCapacity = 3,
	pickupRange = 5,
	transferRange = 8,
	cost = 75,
	cpuHz = 2,
	maxBytecode = 32,
}

BotStats.UpgradeTiers = {
	[1] = {
		name = "Mk. I",
		maxCapacity = 3,
		speed = 14,
		cpuHz = 2,
		upgradeCost = 0,
		color = Color3.fromRGB(215, 135, 70),
	},
	[2] = {
		name = "Mk. II",
		maxCapacity = 8,
		speed = 18,
		cpuHz = 15,
		upgradeCost = 200,
		color = Color3.fromRGB(180, 180, 190),
	},
	[3] = {
		name = "Mk. III",
		maxCapacity = 15,
		speed = 24,
		cpuHz = 25,
		upgradeCost = 500,
		color = Color3.fromRGB(255, 215, 0),
	},
	[4] = {
		name = "Mk. IV",
		maxCapacity = 30,
		speed = 32,
		cpuHz = 50,
		upgradeCost = 1200,
		color = Color3.fromRGB(0, 255, 255),
	},
}

BotStats.MAX_TIER = 4
BotStats.MAX_CPU_TIER = 4

BotStats.RAMTiers = {
	[1] = {
		name = "32B",
		maxBytecode = 32,
	},
	[2] = {
		name = "64B",
		maxBytecode = 64,
		upgradeCost = 100,
	},
	[3] = {
		name = "128B",
		maxBytecode = 128,
		upgradeCost = 250,
	},
}

BotStats.MAX_RAM_TIER = 3

BotStats.BOT_BASE_COST = 75
BotStats.BOT_COST_MULTIPLIER = 1.3

BotStats.BOT_RADIUS = 2
BotStats.TURRET_RADIUS = 3

BotStats.SHOCK_RANGE = 10
BotStats.SHOCK_DAMAGE = 30
BotStats.SHOCK_STUN_TIME = 2

BotStats.MAX_BOTS_PER_PLAYER = 4
BotStats.RESPAWN_TIME = 30
BotStats.SHIELD_COOLDOWN = 60

BotStats.COLORS = {
	RUST_ORANGE = Color3.fromRGB(215, 135, 70),
	DARK_METAL  = Color3.fromRGB(45, 50, 55),
	JOINT_GREY  = Color3.fromRGB(80, 85, 90),
	NEON_CYAN   = Color3.fromRGB(0, 255, 255),
	GOLD_SCRAP  = Color3.fromRGB(255, 215, 0),
}

BotStats.COLOR_MAP = {
	red = Color3.fromRGB(255, 80, 80),
	blue = Color3.fromRGB(80, 150, 255),
	green = Color3.fromRGB(80, 255, 80),
	yellow = Color3.fromRGB(255, 255, 80),
	cyan = Color3.fromRGB(80, 255, 255),
	purple = Color3.fromRGB(180, 80, 255),
	pink = Color3.fromRGB(255, 150, 200),
	orange = Color3.fromRGB(255, 180, 80),
	white = Color3.fromRGB(240, 240, 240),
	black = Color3.fromRGB(50, 50, 50),
}

return BotStats
