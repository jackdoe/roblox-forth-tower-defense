local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local GolemStats = {}

GolemStats.GROUND_Y = Config.PLATFORM_Y

GolemStats.BASE = {
	name = "Golem",
	modelName = "Turret",
	maxAmmo = 300,
	range = 40,
	cost = 100,
}

GolemStats.UpgradeTiers = {
	[1] = {
		name = "Basic",
		maxBytecode = 64,
		damageMultiplier = 1.0,
		rangeMultiplier = 1.0,
		ammoMultiplier = 1.0,
		fireRateMultiplier = 1.0,
		color = Color3.fromRGB(200, 200, 210),
		accentColor = Color3.fromRGB(0, 255, 255),
	},
	[2] = {
		name = "Enhanced",
		maxBytecode = 128,
		damageMultiplier = 1.0,
		rangeMultiplier = 1.0,
		ammoMultiplier = 1.0,
		fireRateMultiplier = 1.0,
		upgradeCost = 200,
		color = Color3.fromRGB(80, 80, 90),
		accentColor = Color3.fromRGB(255, 150, 0),
	},
	[3] = {
		name = "Advanced",
		maxBytecode = 256,
		damageMultiplier = 1.0,
		rangeMultiplier = 1.0,
		ammoMultiplier = 1.0,
		fireRateMultiplier = 1.0,
		upgradeCost = 400,
		color = Color3.fromRGB(70, 80, 60),
		accentColor = Color3.fromRGB(255, 220, 50),
	},
}

GolemStats.MAX_TIER = 3

GolemStats.AmmoStats = {
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

GolemStats.AMMO_NAMES = {
	[1] = "BULLET",
	[2] = "ROCKET",
	[3] = "LASER",
	[4] = "ICE",
	[5] = "GRENADE",
}

GolemStats.TIER_AMMO_UNLOCKS = {
	[1] = {1},
	[2] = {1, 2},
	[3] = {1, 2, 4, 5},
}

GolemStats.DEFAULT_PROGRAM = [[
# Shoot nearest, reload when low
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]]

GolemStats.TIER_PROGRAMS = {
	[1] = GolemStats.DEFAULT_PROGRAM,

	[2] = [[
# ARACHNID - Rockets unlocked!
while True:
    if self.ammo() < 80:
        self.reload(150)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]],

	[3] = [[
# DREADNOUGHT - Full arsenal!
while True:
    if self.ammo() < 100:
        self.reload(200)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]],
}

GolemStats.MAX_TURRETS = 10
GolemStats.TURRET_BASE_COST = 100
GolemStats.TURRET_COST_MULTIPLIER = 1.5

function GolemStats.isAmmoUnlocked(tier, ammoType)
	local unlocks = GolemStats.TIER_AMMO_UNLOCKS[tier]
	if not unlocks then return ammoType == 1 end
	for _, aType in ipairs(unlocks) do
		if aType == ammoType then return true end
	end
	return false
end

function GolemStats.getUnlockedAmmo(tier)
	return GolemStats.TIER_AMMO_UNLOCKS[tier] or {1}
end

function GolemStats.getMaxBytecode(tier)
	local tierData = GolemStats.UpgradeTiers[tier or 1]
	return tierData and tierData.maxBytecode or 64
end

return GolemStats
