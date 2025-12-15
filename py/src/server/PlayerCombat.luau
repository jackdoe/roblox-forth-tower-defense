local TweenService = game:GetService("TweenService")
local ProjectileEffects = require(script.Parent.ProjectileEffects)

local PlayerCombat = {}

-- Dependencies (set via init)
local EnemyManager = nil
local Config = nil
local WaveManager = nil

-- Ammo stats for player (2x scrap cost compared to turret ammoCost)
-- Turret costs: BULLET=1, ROCKET=4, LASER=2, ICE=2, GRENADE=5
local AmmoStats = {
	[1] = { -- BULLET
		damage = 15,
		fireRate = 0.3,
		scrapCost = 2,  -- 2x turret cost (1*2)
		color = Color3.fromRGB(255, 255, 150),
		name = "Bullet",
	},
	[2] = { -- ROCKET
		damage = 40,
		fireRate = 1.0,
		scrapCost = 8,  -- 2x turret cost (4*2)
		splashRadius = 8,
		color = Color3.fromRGB(255, 100, 50),
		name = "Rocket",
	},
	[3] = { -- LASER
		damage = 25,
		fireRate = 0.5,
		scrapCost = 4,  -- 2x turret cost (2*2)
		color = Color3.fromRGB(255, 50, 50),
		name = "Laser",
	},
	[4] = { -- ICE
		damage = 10,
		fireRate = 0.4,
		scrapCost = 4,  -- 2x turret cost (2*2)
		slowAmount = 0.5,
		slowDuration = 3,
		color = Color3.fromRGB(100, 200, 255),
		name = "Ice",
	},
	[5] = { -- GRENADE
		damage = 60,
		fireRate = 1.5,
		scrapCost = 10,  -- 2x turret cost (5*2)
		splashRadius = 12,
		isGrenade = true,  -- Special flag for arc trajectory
		color = Color3.fromRGB(100, 255, 100),
		name = "Grenade",
	},
}

-- Player fire cooldowns (per player)
local playerCooldowns = {}

function PlayerCombat.init(deps)
	EnemyManager = deps.EnemyManager
	Config = deps.Config
	WaveManager = deps.WaveManager
end

-- Get the scrap cost for a weapon type
function PlayerCombat.getScrapCost(ammoType)
	local stats = AmmoStats[ammoType] or AmmoStats[1]
	return stats.scrapCost or 2
end

function PlayerCombat.fire(interp, enemy, ammoType)
	if not interp or not enemy then return false end

	local character = interp.character
	if not character then return false end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local enemyChar = enemy.character
	local enemyHrp = enemyChar and enemyChar:FindFirstChild("HumanoidRootPart")
	if not enemyHrp then return false end

	-- Get ammo stats
	ammoType = ammoType or 1
	local stats = AmmoStats[ammoType] or AmmoStats[1]

	-- Check cooldown
	local playerId = interp.player and interp.player.UserId or 0
	local now = tick()
	local lastFire = playerCooldowns[playerId] or 0
	if now - lastFire < stats.fireRate then
		return false
	end

	-- Check and deduct scrap cost
	local scrapCost = stats.scrapCost or 2
	if WaveManager then
		local currentScrap = WaveManager.getScrap()
		if currentScrap < scrapCost then
			return false  -- Not enough scrap to fire
		end
		WaveManager.removeScrap(scrapCost)
	end

	playerCooldowns[playerId] = now

	-- Check distance (max range 50)
	local dist = (enemyHrp.Position - hrp.Position).Magnitude
	if dist > 50 then return false end

	-- Deal damage (apply power multiplier from interpreter)
	local power = interp.power or 1
	local damage = stats.damage * power

	if stats.splashRadius and stats.splashRadius > 0 then
		-- AOE damage (rocket)
		local allEnemies = EnemyManager.getAll and EnemyManager.getAll() or {}
		for _, e in pairs(allEnemies) do
			if e.hp > 0 and e.character then
				local eHrp = e.character:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local eDist = (eHrp.Position - enemyHrp.Position).Magnitude
					if eDist <= stats.splashRadius then
						local falloff = 1 - (eDist / stats.splashRadius) * 0.5
						EnemyManager.damage(e.id, math.floor(damage * falloff))
						-- Apply oiled status for rockets
						if EnemyManager.applyOiled then
							EnemyManager.applyOiled(e.id, 5)
						end
					end
				end
			end
		end
	else
		-- Single target
		EnemyManager.damage(enemy.id, damage)
	end

	-- Apply slow for ice/freeze
	if stats.slowAmount and stats.slowDuration then
		EnemyManager.applySlow(enemy.id, stats.slowAmount, stats.slowDuration)
	end

	-- Apply burning for laser
	if ammoType == 3 and EnemyManager.applyBurning then
		EnemyManager.applyBurning(enemy.id, 3, 5)
	end

	ProjectileEffects.shot(hrp.Position, enemyHrp.Position, stats)

	return true
end

return PlayerCombat
