-- PlayerCombat.luau
-- Handles player ranged combat (shooting projectiles)

local TweenService = game:GetService("TweenService")

local PlayerCombat = {}

-- Dependencies (set via init)
local EnemyManager = nil
local Config = nil

-- Ammo stats (same as turrets but with player-specific adjustments)
local AmmoStats = {
	[1] = { -- BULLET
		damage = 15,
		fireRate = 0.3,
		color = Color3.fromRGB(255, 255, 150),
		name = "Bullet",
	},
	[2] = { -- ROCKET
		damage = 40,
		fireRate = 1.0,
		splashRadius = 8,
		color = Color3.fromRGB(255, 100, 50),
		name = "Rocket",
	},
	[3] = { -- LASER
		damage = 25,
		fireRate = 0.5,
		color = Color3.fromRGB(255, 50, 50),
		name = "Laser",
	},
	[4] = { -- ICE
		damage = 10,
		fireRate = 0.4,
		slowAmount = 0.5,
		slowDuration = 3,
		color = Color3.fromRGB(100, 200, 255),
		name = "Ice",
	},
	[5] = { -- GRENADE
		damage = 60,
		fireRate = 1.5,
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
	playerCooldowns[playerId] = now

	-- Check distance (max range 50)
	local dist = (enemyHrp.Position - hrp.Position).Magnitude
	if dist > 50 then return false end

	-- Deal damage
	local damage = stats.damage

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

	-- Create visual effect
	PlayerCombat.createProjectileEffect(hrp.Position, enemyHrp.Position, stats)

	return true
end

function PlayerCombat.createProjectileEffect(origin, targetPos, stats)
	task.spawn(function()
		local color = stats.color or Color3.fromRGB(255, 255, 150)

		-- Grenade has arc trajectory
		if stats.isGrenade then
			PlayerCombat.createGrenadeEffect(origin, targetPos, stats)
			return
		end

		-- Muzzle flash
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.new(0.5, 0.5, 0.5)
		flash.Position = origin
		flash.Anchored = true
		flash.CanCollide = false
		flash.Material = Enum.Material.Neon
		flash.Color = color
		flash.Transparency = 0.3
		flash.Parent = workspace

		local flashTween = TweenService:Create(flash, TweenInfo.new(0.1), {
			Size = Vector3.new(2, 2, 2),
			Transparency = 1
		})
		flashTween:Play()
		flashTween.Completed:Wait()
		flash:Destroy()

		-- Beam/tracer
		local dist = (targetPos - origin).Magnitude
		local midPoint = (origin + targetPos) / 2
		local direction = (targetPos - origin).Unit

		local beam = Instance.new("Part")
		beam.Name = "PlayerBeam"
		beam.Size = Vector3.new(0.3, 0.3, dist)
		beam.CFrame = CFrame.lookAt(midPoint, targetPos)
		beam.Anchored = true
		beam.CanCollide = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Transparency = 0.3
		beam.Parent = workspace

		-- Impact flash
		local impact = Instance.new("Part")
		impact.Shape = Enum.PartType.Ball
		impact.Size = Vector3.new(1, 1, 1)
		impact.Position = targetPos
		impact.Anchored = true
		impact.CanCollide = false
		impact.Material = Enum.Material.Neon
		impact.Color = color
		impact.Transparency = 0.3
		impact.Parent = workspace

		-- Fade out
		local beamTween = TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 1 })
		local impactTween = TweenService:Create(impact, TweenInfo.new(0.2), {
			Size = Vector3.new(3, 3, 3),
			Transparency = 1
		})

		beamTween:Play()
		impactTween:Play()

		task.wait(0.2)
		beam:Destroy()
		impact:Destroy()
	end)
end

-- Grenade effect with arc trajectory and explosion
function PlayerCombat.createGrenadeEffect(origin, targetPos, stats)
	local color = stats.color or Color3.fromRGB(100, 255, 100)
	local dist = (targetPos - origin).Magnitude
	local flightTime = math.min(0.6, dist / 50)  -- Faster for closer targets
	local arcHeight = math.min(dist * 0.3, 10)   -- Arc height based on distance

	-- Create grenade projectile
	local grenade = Instance.new("Part")
	grenade.Name = "Grenade"
	grenade.Shape = Enum.PartType.Ball
	grenade.Size = Vector3.new(0.8, 0.8, 0.8)
	grenade.Position = origin + Vector3.new(0, 1, 0)
	grenade.Anchored = true
	grenade.CanCollide = false
	grenade.Material = Enum.Material.Metal
	grenade.Color = Color3.fromRGB(60, 80, 60)
	grenade.Parent = workspace

	-- Add glow indicator
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Brightness = 2
	glow.Range = 4
	glow.Parent = grenade

	-- Arc trajectory animation
	local startPos = origin + Vector3.new(0, 1, 0)
	local endPos = targetPos
	local steps = math.floor(flightTime / 0.02)

	task.spawn(function()
		for i = 1, steps do
			local t = i / steps
			-- Parabolic arc: lerp horizontal, add sin curve for height
			local currentPos = startPos:Lerp(endPos, t)
			local heightOffset = math.sin(t * math.pi) * arcHeight
			grenade.Position = currentPos + Vector3.new(0, heightOffset, 0)

			-- Spin the grenade
			grenade.CFrame = grenade.CFrame * CFrame.Angles(0.3, 0.2, 0.1)

			task.wait(0.02)
		end

		-- EXPLOSION at target
		grenade:Destroy()

		-- Explosion flash
		local explosion = Instance.new("Part")
		explosion.Shape = Enum.PartType.Ball
		explosion.Size = Vector3.new(2, 2, 2)
		explosion.Position = endPos
		explosion.Anchored = true
		explosion.CanCollide = false
		explosion.Material = Enum.Material.Neon
		explosion.Color = Color3.fromRGB(255, 200, 50)
		explosion.Transparency = 0
		explosion.Parent = workspace

		-- Explosion ring
		local ring = Instance.new("Part")
		ring.Name = "ExplosionRing"
		ring.Size = Vector3.new(2, 0.3, 2)
		ring.Position = endPos
		ring.Anchored = true
		ring.CanCollide = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 150, 50)
		ring.Transparency = 0.3
		ring.Parent = workspace

		-- Expand explosion
		local explosionTween = TweenService:Create(explosion, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(stats.splashRadius or 12, stats.splashRadius or 12, stats.splashRadius or 12),
			Transparency = 1,
			Color = Color3.fromRGB(255, 100, 50)
		})

		local ringTween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new((stats.splashRadius or 12) * 2, 0.1, (stats.splashRadius or 12) * 2),
			Transparency = 1
		})

		explosionTween:Play()
		ringTween:Play()

		-- Debris particles
		for i = 1, 12 do
			local debris = Instance.new("Part")
			debris.Size = Vector3.new(0.3, 0.3, 0.3)
			debris.Position = endPos
			debris.Anchored = true
			debris.CanCollide = false
			debris.Material = Enum.Material.Neon
			debris.Color = Color3.fromRGB(255, 150 + math.random(50), 50)
			debris.Transparency = 0
			debris.Parent = workspace

			local angle = (i / 12) * math.pi * 2
			local spread = (stats.splashRadius or 12) * 0.8
			local debrisTarget = endPos + Vector3.new(
				math.cos(angle) * spread,
				math.random() * 4,
				math.sin(angle) * spread
			)

			local debrisTween = TweenService:Create(debris, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = debrisTarget,
				Size = Vector3.new(0.1, 0.1, 0.1),
				Transparency = 1
			})
			debrisTween:Play()

			task.delay(0.5, function()
				debris:Destroy()
			end)
		end

		task.wait(0.5)
		explosion:Destroy()
		ring:Destroy()
	end)
end

return PlayerCombat
