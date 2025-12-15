local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local GundamStats = {}

GundamStats.GROUND_Y = Config.PLATFORM_Y

GundamStats.BASE = {
	name = "Gundam",
	modelName = "Gundam",
	maxAmmo = 300,
	range = 40,
	cost = 100,
}

GundamStats.UpgradeTiers = {
	[1] = {
		name = "2 Hz",
		cpuHz = 2,
		tickRate = 1.0,
		damageMultiplier = 1.0,
		rangeMultiplier = 1.0,
		ammoMultiplier = 1.0,
		fireRateMultiplier = 1.0,
		color = Color3.fromRGB(200, 200, 210),
		accentColor = Color3.fromRGB(0, 255, 255),
	},
	[2] = {
		name = "5 Hz",
		cpuHz = 5,
		tickRate = 0.2,
		damageMultiplier = 1.0,
		rangeMultiplier = 1.0,
		ammoMultiplier = 1.0,
		fireRateMultiplier = 1.0,
		upgradeCost = 200,
		color = Color3.fromRGB(80, 80, 90),
		accentColor = Color3.fromRGB(255, 150, 0),
	},
	[3] = {
		name = "20 Hz",
		cpuHz = 20,
		tickRate = 0.05,
		damageMultiplier = 1.0,
		rangeMultiplier = 1.0,
		ammoMultiplier = 1.0,
		fireRateMultiplier = 1.0,
		upgradeCost = 400,
		color = Color3.fromRGB(70, 80, 60),
		accentColor = Color3.fromRGB(255, 220, 50),
	},
}

GundamStats.MAX_CPU_TIER = 3

GundamStats.RAMTiers = {
	[1] = {
		name = "32B",
		maxBytecode = 32,
		upgradeCost = nil,
		color = Color3.fromRGB(200, 200, 210),
		accentColor = Color3.fromRGB(0, 255, 255),
	},
	[2] = {
		name = "64B",
		maxBytecode = 64,
		upgradeCost = 150,
		color = Color3.fromRGB(80, 80, 90),
		accentColor = Color3.fromRGB(255, 150, 0),
	},
	[3] = {
		name = "128B",
		maxBytecode = 128,
		upgradeCost = 300,
		color = Color3.fromRGB(70, 80, 60),
		accentColor = Color3.fromRGB(255, 220, 50),
	},
}

GundamStats.MAX_RAM_TIER = 3

GundamStats.AmmoStats = {
	[1] = {
		name = "BULLET",
		damage = 15,
		ammoCost = 1,
		fireRate = 0.2,
		color = Color3.fromRGB(255, 255, 200),
	},
	[2] = {
		name = "ROCKET",
		damage = 80,
		ammoCost = 4,
		fireRate = 1.0,
		splashRadius = 12,
		color = Color3.fromRGB(255, 100, 50),
	},
	[3] = {
		name = "LASER",
		damage = 40,
		ammoCost = 2,
		fireRate = 0.1,
		color = Color3.fromRGB(255, 50, 50),
	},
	[4] = {
		name = "ICE",
		damage = 20,
		ammoCost = 2,
		fireRate = 0.4,
		slowAmount = 0.6,
		slowDuration = 4.0,
		color = Color3.fromRGB(100, 200, 255),
	},
	[5] = {
		name = "FREEZE",
		damage = 0,
		ammoCost = 1,
		fireRate = 0.1,
		slowAmount = 0.3,
		slowDuration = 3.0,
		color = Color3.fromRGB(0, 255, 255),
	},
}

GundamStats.AMMO_NAMES = {
	[1] = "BULLET",
	[2] = "ROCKET",
	[3] = "LASER",
	[4] = "ICE",
	[5] = "GRENADE",
}

GundamStats.TIER_AMMO_UNLOCKS = {
	[1] = {1},
	[2] = {1, 2},
	[3] = {1, 2, 4, 5},
}

GundamStats.DEFAULT_PROGRAM = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]]

GundamStats.TIER_PROGRAMS = {
	[1] = GundamStats.DEFAULT_PROGRAM,

	[2] = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]],

	[3] = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]],
}

GundamStats.MAX_GUNDAMS = 10
GundamStats.GUNDAM_BASE_COST = 100
GundamStats.GUNDAM_COST_MULTIPLIER = 1.5

function GundamStats.isAmmoUnlocked(tier, ammoType)
	local unlocks = GundamStats.TIER_AMMO_UNLOCKS[tier]
	if not unlocks then return ammoType == 1 end
	for _, aType in ipairs(unlocks) do
		if aType == ammoType then return true end
	end
	return false
end

function GundamStats.getUnlockedAmmo(tier)
	return GundamStats.TIER_AMMO_UNLOCKS[tier] or {1}
end

function GundamStats.getCpuHz(tier)
	local tierData = GundamStats.UpgradeTiers[tier or 1]
	return tierData and tierData.cpuHz or 1
end

function GundamStats.getTickRate(tier)
	local tierData = GundamStats.UpgradeTiers[tier or 1]
	return tierData and tierData.tickRate or 1.0
end

function GundamStats.getMaxBytecode(ramTier)
	local tierData = GundamStats.RAMTiers[ramTier or 1]
	return tierData and tierData.maxBytecode or 32
end

function GundamStats.getRAMUpgradeCost(ramTier)
	local nextTier = GundamStats.RAMTiers[(ramTier or 1) + 1]
	return nextTier and nextTier.upgradeCost or nil
end

return GundamStats
