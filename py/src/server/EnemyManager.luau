-- EnemyManager.luau
-- Simplified enemy system for Tower Defense
-- Enemies are DUMB - they just walk to the Core
-- No interpreter, no complex AI - just pathfinding to target

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local EnemyManager = {}

-- Ground level Y coordinate
local GROUND_Y = Config.PLATFORM_Y

local enemies = {}
local deps = nil
local WaveManager = nil
local BotRegistry = nil  -- For hunter targeting

-- Spatial partitioning grid for optimized enemy lookups
local GRID_CELL_SIZE = 20  -- studs per grid cell
local enemyGrid = {}       -- Key: "gx_gz", Value: table of enemy references

-- Max search range for unbounded queries (map diagonal ~250 studs)
-- This ensures spatial grid is ALWAYS used, avoiding O(n) full scans
local MAX_SEARCH_RANGE = 300

-- Base enemy type definitions (these get scaled per wave)
-- Buffed for "Action Strategy" - more HP, more scrap, faster pace
local EnemyTypes = {
	Zombie = {
		name = "Zombie",
		modelName = "Zombie",
		hp = 50,          -- Slight buff (was 40)
		speed = 7,        -- Faster! (was 6)
		damage = 10,      -- Damage to Core (was 8)
		scrap = 15,       -- HUGE BUFF (was 5). Pays for 300 bullets!
		size = 1,
	},
	Runner = {
		name = "Runner",
		modelName = "Runner",
		hp = 30,          -- Slight buff (was 25)
		speed = 14,       -- Zoom (was 12)
		damage = 5,
		scrap = 10,       -- Buff (was 3)
		size = 0.8,
	},
	Tank = {
		name = "Tank",
		modelName = "Tank",
		hp = 400,         -- Tankier (was 150)
		speed = 4,
		damage = 30,      -- Was 25
		scrap = 100,      -- Loot pinata (was 15)
		size = 1.5,
	},
	Boss = {
		name = "Boss",
		modelName = "Boss",
		hp = 1000,        -- Was 800
		speed = 5,
		damage = 100,     -- Was 80
		scrap = 250,      -- Big payday (was 100)
		size = 2.5,
	},
}

-- Wave scaling configuration
local WaveScaling = {
	hpPerWave = 0.15,      -- +15% HP per wave
	damagePerWave = 0.10,  -- +10% damage per wave
	sizePerWave = 0.03,    -- +3% size per wave
	speedPerWave = 0.02,   -- +2% speed per wave (capped)
	maxSpeedMult = 1.5,    -- Max speed multiplier
}

-- Current wave (set by WaveManager)
local currentWave = 1
local newGamePlusMultiplier = 1  -- Doubles after all 8 gates unlocked

-- Spawn gates (set from map)
local spawnGates = {}

-- Enemy path waypoints (set from map)
local enemyPath = {}

--============================================================================
-- INITIALIZATION
--============================================================================

function EnemyManager.init(dependencies)
	deps = dependencies
	BotRegistry = dependencies.BotRegistry
	print("EnemyManager: Initialized")
end

function EnemyManager.setWaveManager(waveMgr)
	WaveManager = waveMgr
end

function EnemyManager.setSpawnGates(gates)
	spawnGates = gates
	print("EnemyManager: Set", #gates, "spawn gates")
end

function EnemyManager.setEnemyPath(path)
	enemyPath = path or {}
	print("EnemyManager: Set enemy path with", #enemyPath, "waypoints")
end

function EnemyManager.setWave(wave)
	currentWave = wave
end

function EnemyManager.setNewGamePlusMultiplier(mult)
	newGamePlusMultiplier = mult
	print("EnemyManager: NG+ multiplier set to", mult)
end

-- Calculate scaled stats for current wave
local function getScaledStats(enemyType)
	local base = EnemyTypes[enemyType]
	if not base then return nil end

	local waveMult = 1 + (currentWave - 1) * WaveScaling.hpPerWave
	local damageMult = 1 + (currentWave - 1) * WaveScaling.damagePerWave
	local sizeMult = 1 + (currentWave - 1) * WaveScaling.sizePerWave
	local speedMult = math.min(WaveScaling.maxSpeedMult, 1 + (currentWave - 1) * WaveScaling.speedPerWave)

	return {
		name = base.name,
		modelName = base.modelName,
		hp = math.floor(base.hp * waveMult * newGamePlusMultiplier),
		speed = base.speed * speedMult,
		damage = math.floor(base.damage * damageMult * newGamePlusMultiplier),
		scrap = math.floor(base.scrap * (1 + (currentWave - 1) * 0.1)),  -- Scrap also scales
		size = base.size * sizeMult,
	}
end

--============================================================================
-- HELPERS
--============================================================================

local function getEnemyModelsFolder()
	return ServerStorage:FindFirstChild("Enemies") or ServerStorage:FindFirstChild("Monsters")
end

local function findModelInFolder(folder)
	local model = folder:FindFirstChild("Model")
	if model and model:IsA("Model") then return model end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") then
			return child
		end
	end

	if folder:FindFirstChild("HumanoidRootPart") then return folder end
	return nil
end

local function createSimpleEnemy(typeName, position, scaledType)
	-- Use scaled stats if provided, otherwise get base type
	local enemyType = scaledType or EnemyTypes[typeName]
	if not enemyType then
		warn("EnemyManager: Unknown enemy type:", typeName)
		return nil
	end

	local modelsFolder = getEnemyModelsFolder()
	local character = nil

	if modelsFolder then
		local modelFolder = modelsFolder:FindFirstChild(enemyType.modelName)
		if modelFolder then
			local sourceModel = findModelInFolder(modelFolder)
			if sourceModel then
				character = sourceModel:Clone()
			end
		end
	end

	-- Fallback: create simple part if no model
	if not character then
		character = Instance.new("Model")
		character.Name = typeName

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 4, 2) * enemyType.size
		hrp.Position = position
		hrp.Anchored = true
		hrp.CanCollide = false
		hrp.Material = Enum.Material.SmoothPlastic

		-- Color by type
		if typeName == "Zombie" then
			hrp.Color = Color3.fromRGB(100, 150, 100)
		elseif typeName == "Runner" then
			hrp.Color = Color3.fromRGB(150, 100, 150)
		elseif typeName == "Tank" then
			hrp.Color = Color3.fromRGB(100, 100, 150)
		elseif typeName == "Boss" then
			hrp.Color = Color3.fromRGB(200, 50, 50)
		end

		hrp.Parent = character
		character.PrimaryPart = hrp
	end

	return character
end

--============================================================================
-- SPAWNING
--============================================================================

function EnemyManager.spawn(typeName, gateIndex, dependencies)
	local gate = spawnGates[gateIndex]
	if not gate then
		warn("EnemyManager: Invalid gate index:", gateIndex)
		-- Fallback to first gate
		gate = spawnGates[1]
		if not gate then return nil end
	end

	-- Get scaled stats for current wave
	local enemyType = getScaledStats(typeName)
	if not enemyType then
		warn("EnemyManager: Unknown enemy type:", typeName)
		return nil
	end

	-- Randomize spawn position slightly
	local spawnX = gate.x + (math.random() - 0.5) * 6
	local spawnZ = gate.z + (math.random() - 0.5) * 6
	local spawnPos = Vector3.new(spawnX, GROUND_Y + 3, spawnZ)

	local character = createSimpleEnemy(typeName, spawnPos, enemyType)
	if not character then return nil end

	-- Position the model
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		character:PivotTo(CFrame.new(spawnPos))
	end

	-- Anchor all parts
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	character.Parent = workspace

	-- 20% chance to be a Bot Hunter (purple enemies that target bots)
	local isHunter = math.random() < 0.20

	-- Create enemy data
	local id = game:GetService("HttpService"):GenerateGUID()
	local enemy = {
		id = id,
		character = character,
		typeData = enemyType,
		typeName = typeName, -- Store type name for wave preview
		hp = enemyType.hp,
		maxHp = enemyType.hp,
		speed = enemyType.speed,
		damage = enemyType.damage,
		scrap = enemyType.scrap,

		-- Movement
		targetPos = nil,      -- Will be set to Core position
		velocityX = 0,
		velocityZ = 0,

		-- Waypoint pathfinding
		currentWaypoint = 1,  -- Index into enemyPath

		-- Animation
		time = math.random() * 10,
		baseY = GROUND_Y + 3,

		-- Hunter behavior
		isHunter = isHunter,
		targetBotId = nil,
		lastAttackTime = 0,
		attackCooldown = 1.0,
	}

	-- Visual indication for hunters: Purple tint
	if isHunter then
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(150, 50, 200)
			end
		end
	end

	enemies[id] = enemy

	-- Register with EntityRegistry for targeting
	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = id,
			isEnemy = true,
			isMonster = true,  -- For compatibility with existing targeting code
			character = character,
			hp = enemy.hp,
			maxHp = enemy.maxHp,
		})
	end

	-- Create HP bar billboard
	EnemyManager.createHpBar(enemy)

	return id
end

--============================================================================
-- HP BAR BILLBOARD
--============================================================================

function EnemyManager.createHpBar(enemy)
	local character = enemy.character
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	-- Billboard GUI
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyHpBar"
	billboard.Size = UDim2.new(0, 60, 0, 10)
	billboard.StudsOffset = Vector3.new(0, 3 * (enemy.typeData.size or 1), 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 50
	billboard.Parent = hrp

	-- Background bar
	local bgBar = Instance.new("Frame")
	bgBar.Name = "Background"
	bgBar.Size = UDim2.new(1, 0, 1, 0)
	bgBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bgBar.BorderSizePixel = 0
	bgBar.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 3)
	bgCorner.Parent = bgBar

	-- HP fill bar
	local hpBar = Instance.new("Frame")
	hpBar.Name = "HpBar"
	hpBar.Size = UDim2.new(1, 0, 1, 0)
	hpBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	hpBar.BorderSizePixel = 0
	hpBar.Parent = bgBar

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 3)
	hpCorner.Parent = hpBar

	-- Enemy name label (small, above bar)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 12)
	nameLabel.Position = UDim2.new(0, 0, 0, -14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 10
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Parent = billboard

	-- Hunter enemies get special label
	if enemy.isHunter then
		nameLabel.Text = "⚔ HUNTER"
		nameLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
	else
		nameLabel.Text = enemy.typeData.name or "Enemy"
		nameLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
	end

	enemy.hpBillboard = billboard
end

function EnemyManager.updateHpBar(enemy)
	if not enemy.hpBillboard then return end

	local bgBar = enemy.hpBillboard:FindFirstChild("Background")
	if not bgBar then return end

	local hpBar = bgBar:FindFirstChild("HpBar")
	if not hpBar then return end

	local ratio = math.max(0, enemy.hp / enemy.maxHp)
	hpBar.Size = UDim2.new(ratio, 0, 1, 0)

	-- Color based on HP percentage
	if ratio > 0.5 then
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	elseif ratio > 0.25 then
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	else
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end
end

--============================================================================
-- DAMAGE
--============================================================================

function EnemyManager.damage(enemyId, amount, sourceGolemId)
	local enemy = enemies[enemyId]
	if not enemy then return false end

	enemy.hp = enemy.hp - amount

	-- Update EntityRegistry
	if deps.EntityRegistry then
		local entity = deps.EntityRegistry.get(enemyId)
		if entity then
			entity.hp = enemy.hp
		end
	end

	-- Update HP bar
	EnemyManager.updateHpBar(enemy)

	-- Damage number visual
	if enemy.character then
		local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if hrp and deps.attackHitEvent then
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				deps.attackHitEvent:FireClient(player, {
					targetPos = hrp.Position,
					damage = amount,
					hitCount = 1,
				})
			end
		end
	end

	if enemy.hp <= 0 then
		EnemyManager.kill(enemyId, sourceGolemId)
		return true
	end

	return false
end

function EnemyManager.applySlow(enemyId, slowAmount, duration)
	local enemy = enemies[enemyId]
	if not enemy then return end

	-- Apply slow effect (stacks refresh duration, doesn't stack intensity)
	enemy.slowAmount = slowAmount
	enemy.slowExpires = tick() + duration

	-- Visual indicator - tint the enemy blue
	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color:ToHex())
			end
			if part:IsA("BasePart") then
				-- Blend toward ice blue
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					local orig = Color3.fromHex(origHex)
					part.Color = orig:Lerp(Color3.fromRGB(100, 200, 255), 0.5)
				end
			end
		end
	end
end

function EnemyManager.clearSlow(enemy)
	enemy.slowAmount = nil
	enemy.slowExpires = nil

	-- Restore original colors
	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					part.Color = Color3.fromHex(origHex)
				end
			end
		end
	end
end

--============================================================================
-- STATUS EFFECT SYSTEM (Combos!)
--============================================================================

-- Apply "oiled" status (from ROCKET) - takes 2x shock damage
function EnemyManager.applyOiled(enemyId, duration)
	local enemy = enemies[enemyId]
	if not enemy then return end

	enemy.oiled = true
	enemy.oiledExpires = tick() + (duration or 5)

	-- Visual: Orange tint
	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color:ToHex())
			end
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					local orig = Color3.fromHex(origHex)
					part.Color = orig:Lerp(Color3.fromRGB(255, 140, 0), 0.6) -- Orange
				end
			end
		end
	end
end

-- Apply "burning" status (from LASER) - DoT damage
function EnemyManager.applyBurning(enemyId, duration, damagePerTick)
	local enemy = enemies[enemyId]
	if not enemy then return end

	enemy.burning = true
	enemy.burningExpires = tick() + (duration or 3)
	enemy.burningDamage = damagePerTick or 5
	enemy.burningLastTick = tick()

	-- Visual: Red/orange fire tint
	if enemy.character then
		for _, part in ipairs(enemy.character:GetDescendants()) do
			if part:IsA("BasePart") and not part:GetAttribute("OriginalColor") then
				part:SetAttribute("OriginalColor", part.Color:ToHex())
			end
			if part:IsA("BasePart") then
				local origHex = part:GetAttribute("OriginalColor")
				if origHex then
					local orig = Color3.fromHex(origHex)
					part.Color = orig:Lerp(Color3.fromRGB(255, 80, 20), 0.5) -- Fire red
				end
			end
		end

		-- Add fire particles
		local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if hrp and not hrp:FindFirstChild("FireEffect") then
			local fire = Instance.new("ParticleEmitter")
			fire.Name = "FireEffect"
			fire.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 0))
			fire.Size = NumberSequence.new(0.5, 0)
			fire.Lifetime = NumberRange.new(0.3, 0.6)
			fire.Rate = 30
			fire.Speed = NumberRange.new(2, 4)
			fire.SpreadAngle = Vector2.new(30, 30)
			fire.Parent = hrp
		end
	end
end

-- Shock an enemy (from Bot) - bonus damage if oiled, chain if burning
function EnemyManager.shock(enemyId, baseDamage, sourceX, sourceZ)
	local enemy = enemies[enemyId]
	if not enemy then return 0 end

	baseDamage = baseDamage or 30
	local totalDamage = baseDamage

	-- Combo: Oiled + Shock = 2x damage explosion!
	if enemy.oiled then
		totalDamage = baseDamage * 2
		enemy.oiled = nil
		enemy.oiledExpires = nil
		-- Explosion visual
		EnemyManager.createShockExplosion(enemy)
	end

	-- Combo: Burning + Shock = chain lightning to nearby enemies
	if enemy.burning then
		enemy.burning = nil
		enemy.burningExpires = nil
		-- Remove fire particles
		if enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local fire = hrp:FindFirstChild("FireEffect")
				if fire then fire:Destroy() end
			end
		end
		-- Chain to nearby enemies
		EnemyManager.chainLightning(enemyId, baseDamage * 0.5, sourceX, sourceZ)
	end

	-- Apply damage
	EnemyManager.damage(enemyId, totalDamage)

	-- Electric spark visual on enemy
	EnemyManager.createShockSparks(enemy)

	return totalDamage
end

-- Shatter combo: Frozen + ROCKET = bonus damage
function EnemyManager.checkShatterCombo(enemyId, rocketDamage)
	local enemy = enemies[enemyId]
	if not enemy then return rocketDamage end

	-- If frozen (slowed by ICE), shatter for 1.5x damage
	if enemy.slowAmount and enemy.slowAmount >= 0.5 then
		-- Clear the freeze
		EnemyManager.clearSlow(enemy)
		-- Shatter visual
		EnemyManager.createShatterEffect(enemy)
		return rocketDamage * 1.5
	end

	return rocketDamage
end

-- Visual: Shock explosion (oiled combo)
function EnemyManager.createShockExplosion(enemy)
	if not enemy.character then return end
	local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Bright flash sphere
	local explosion = Instance.new("Part")
	explosion.Shape = Enum.PartType.Ball
	explosion.Size = Vector3.new(1, 1, 1)
	explosion.Position = hrp.Position
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 200, 50) -- Yellow/orange
	explosion.Transparency = 0.3
	explosion.Parent = workspace

	-- Expand and fade
	task.spawn(function()
		for i = 1, 15 do
			explosion.Size = Vector3.new(i * 1.5, i * 1.5, i * 1.5)
			explosion.Transparency = 0.3 + (i / 15) * 0.7
			task.wait(0.02)
		end
		explosion:Destroy()
	end)
end

-- Visual: Electric sparks
function EnemyManager.createShockSparks(enemy)
	if not enemy.character then return end
	local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Brief electric particle burst
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255), Color3.fromRGB(255, 255, 100))
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.Lifetime = NumberRange.new(0.1, 0.3)
	sparks.Rate = 100
	sparks.Speed = NumberRange.new(5, 15)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = hrp

	task.delay(0.2, function()
		sparks.Enabled = false
		task.delay(0.3, function() sparks:Destroy() end)
	end)
end

-- Visual: Shatter effect (frozen + rocket)
function EnemyManager.createShatterEffect(enemy)
	if not enemy.character then return end
	local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Ice shards burst
	for i = 1, 8 do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(0.3, 0.6, 0.2)
		shard.Position = hrp.Position
		shard.Anchored = false
		shard.CanCollide = false
		shard.Material = Enum.Material.Ice
		shard.Color = Color3.fromRGB(150, 220, 255)
		shard.Transparency = 0.3
		shard.Parent = workspace

		-- Random velocity outward
		local angle = (i / 8) * math.pi * 2
		local vel = Instance.new("BodyVelocity")
		vel.Velocity = Vector3.new(math.cos(angle) * 20, 10, math.sin(angle) * 20)
		vel.MaxForce = Vector3.new(10000, 10000, 10000)
		vel.Parent = shard

		task.delay(0.5, function()
			shard:Destroy()
		end)
	end
end

-- Chain lightning (burning + shock combo)
function EnemyManager.chainLightning(sourceEnemyId, chainDamage, sourceX, sourceZ)
	local sourceEnemy = enemies[sourceEnemyId]
	if not sourceEnemy or not sourceEnemy.character then return end

	local sourceHrp = sourceEnemy.character:FindFirstChild("HumanoidRootPart")
	if not sourceHrp then return end

	-- Find up to 3 nearby enemies to chain to
	local nearbyEnemies = EnemyManager.findInRange(sourceHrp.Position.X, sourceHrp.Position.Z, 15)
	local chainCount = 0

	for _, nearbyEnemy in ipairs(nearbyEnemies) do
		if nearbyEnemy.id ~= sourceEnemyId and chainCount < 3 then
			-- Draw lightning bolt visual
			EnemyManager.createLightningBolt(sourceHrp.Position, nearbyEnemy.character)
			-- Apply chain damage
			EnemyManager.damage(nearbyEnemy.id, chainDamage)
			EnemyManager.createShockSparks(nearbyEnemy)
			chainCount = chainCount + 1
		end
	end
end

-- Visual: Lightning bolt between two points
function EnemyManager.createLightningBolt(startPos, targetChar)
	if not targetChar then return end
	local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetHrp then return end

	local endPos = targetHrp.Position

	-- Simple beam effect
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(100, 200, 255)

	local distance = (endPos - startPos).Magnitude
	beam.Size = Vector3.new(0.2, 0.2, distance)
	beam.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = workspace

	task.delay(0.15, function()
		beam:Destroy()
	end)
end

-- Clear status effects (called in update loop)
function EnemyManager.updateStatusEffects(enemy)
	local now = tick()

	-- Clear expired oiled
	if enemy.oiledExpires and now > enemy.oiledExpires then
		enemy.oiled = nil
		enemy.oiledExpires = nil
		-- Restore color handled by next tint or clearSlow
	end

	-- Process burning DoT
	if enemy.burning then
		if enemy.burningExpires and now > enemy.burningExpires then
			enemy.burning = nil
			enemy.burningExpires = nil
			enemy.burningDamage = nil
			-- Remove fire particles
			if enemy.character then
				local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local fire = hrp:FindFirstChild("FireEffect")
					if fire then fire:Destroy() end
				end
			end
		elseif enemy.burningLastTick and now - enemy.burningLastTick >= 0.5 then
			-- Tick damage every 0.5s
			enemy.burningLastTick = now
			EnemyManager.damage(enemy.id, enemy.burningDamage or 5)
		end
	end
end

function EnemyManager.kill(enemyId, killerGolemId)
	local enemy = enemies[enemyId]
	if not enemy then return end

	-- Store position before death effect destroys character
	local deathPosition = nil
	local scrapAmount = enemy.scrap or 10

	-- Death effect
	if enemy.character then
		local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if hrp then
			deathPosition = hrp.Position

			-- Quick shrink animation
			task.spawn(function()
				for i = 1, 10 do
					if enemy.character and enemy.character.Parent then
						local scale = 1 - (i / 10)
						enemy.character:ScaleTo(math.max(0.1, scale))
					end
					task.wait(0.03)
				end
				if enemy.character then
					enemy.character:Destroy()
				end
			end)
		end
	end

	-- DROP PHYSICAL SCRAP (for Supply Bots to collect!)
	if deps.ScrapManager and deathPosition then
		deps.ScrapManager.spawn(deathPosition, scrapAmount)
	end

	-- Unregister
	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(enemyId)
	end

	-- Notify WaveManager (no longer gives scrap directly)
	if WaveManager then
		WaveManager.onEnemyKilled(enemyId, killerGolemId)
	end

	enemies[enemyId] = nil
end

--============================================================================
-- SPATIAL PARTITIONING (Grid-based enemy lookups)
--============================================================================

-- Convert world position to grid key
local function getGridKey(x, z)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)
	return gx .. "_" .. gz
end

-- Rebuild the spatial grid from current enemy positions
-- Called once per frame in update loop
local function rebuildGrid()
	table.clear(enemyGrid)

	for id, enemy in pairs(enemies) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local pos = hrp.Position
				local key = getGridKey(pos.X, pos.Z)
				if not enemyGrid[key] then
					enemyGrid[key] = {}
				end
				table.insert(enemyGrid[key], enemy)
			end
		end
	end
end

-- Get all grid cells that could contain enemies within range of (x, z)
-- Returns enemies in those cells
local function getEnemiesNearPoint(x, z, range)
	local cellsToCheck = math.ceil(range / GRID_CELL_SIZE)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)

	local results = {}

	for i = -cellsToCheck, cellsToCheck do
		for j = -cellsToCheck, cellsToCheck do
			local key = (gx + i) .. "_" .. (gz + j)
			local cell = enemyGrid[key]
			if cell then
				for _, enemy in ipairs(cell) do
					table.insert(results, enemy)
				end
			end
		end
	end

	return results
end

--============================================================================
-- UPDATE LOOP
--============================================================================

function EnemyManager.update(dt)
	if not WaveManager then return end

	local corePos = WaveManager.getCorePosition()
	if not corePos then return end

	-- Rebuild spatial grid for optimized enemy lookups
	rebuildGrid()

	local toRemove = {}

	-- BulkMoveTo optimization: collect all parts and CFrames
	local partList = {}
	local cframeList = {}

	-- Pre-calculate core reach distance squared (avoid sqrt in loop)
	local CORE_REACH_DIST_SQ = 4 * 4  -- 16

	for id, enemy in pairs(enemies) do
		local character = enemy.character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")

		if not hrp then
			table.insert(toRemove, id)
			continue
		end

		-- Already dead?
		if enemy.hp <= 0 then
			continue
		end

		local myX, myZ = hrp.Position.X, hrp.Position.Z
		local targetX, targetZ = corePos.x, corePos.z
		local isAttackingBot = false

		-- WAYPOINT PATHFINDING: Follow the path instead of beelining to core
		if #enemyPath > 0 and enemy.currentWaypoint then
			local waypoint = enemyPath[enemy.currentWaypoint]
			if waypoint then
				targetX, targetZ = waypoint.x, waypoint.z

				-- Check if reached current waypoint (within 3 studs)
				local waypointDx = targetX - myX
				local waypointDz = targetZ - myZ
				local waypointDistSq = waypointDx * waypointDx + waypointDz * waypointDz
				if waypointDistSq < 9 then -- 3^2 = 9
					-- Move to next waypoint
					enemy.currentWaypoint = enemy.currentWaypoint + 1
					if enemy.currentWaypoint > #enemyPath then
						-- Reached end of path, target core directly
						targetX, targetZ = corePos.x, corePos.z
					else
						local nextWp = enemyPath[enemy.currentWaypoint]
						if nextWp then
							targetX, targetZ = nextWp.x, nextWp.z
						end
					end
				end
			end
		end

		-- HUNTER LOGIC: Target bots instead of core (overrides waypoints)
		if enemy.isHunter and BotRegistry then
			local bot, botDist = BotRegistry.findNearest(myX, myZ, 40)

			if bot and bot.character and not bot.shieldActive then
				local botHrp = bot.character:FindFirstChild("HumanoidRootPart")
				if botHrp then
					targetX = botHrp.Position.X
					targetZ = botHrp.Position.Z

					-- Attack bot if close enough
					if botDist < 4 then
						isAttackingBot = true
						if tick() - enemy.lastAttackTime > enemy.attackCooldown then
							BotRegistry.damage(bot.id, enemy.damage)
							enemy.lastAttackTime = tick()
						end
					end
				end
			end
		end

		-- Calculate direction to target
		local dx = targetX - myX
		local dz = targetZ - myZ
		local distSq = dx * dx + dz * dz  -- Squared distance (no sqrt!)

		-- Check if reached Core (only if not attacking a bot)
		if not isAttackingBot and distSq < CORE_REACH_DIST_SQ then
			-- Deal damage to Core
			WaveManager.damageCore(enemy.damage, id)
			WaveManager.onEnemyReachedCore(id)

			-- Remove enemy
			if character then character:Destroy() end
			if deps.EntityRegistry then
				deps.EntityRegistry.unregister(id)
			end
			table.insert(toRemove, id)
			continue
		end

		-- Check/clear slow effect
		if enemy.slowExpires and tick() > enemy.slowExpires then
			EnemyManager.clearSlow(enemy)
		end

		-- Process status effects (oiled, burning DoT, etc.)
		EnemyManager.updateStatusEffects(enemy)

		-- Calculate effective speed (apply slow if active)
		local effectiveSpeed = enemy.speed
		if enemy.slowAmount then
			effectiveSpeed = enemy.speed * (1 - enemy.slowAmount)
		end

		-- Move toward Core
		if distSq > 0.01 then  -- 0.1^2 = 0.01
			-- Only compute sqrt when needed for normalization
			local dist = math.sqrt(distSq)
			local dirX = dx / dist
			local dirZ = dz / dist

			-- Smooth velocity
			local targetVelX = dirX * effectiveSpeed
			local targetVelZ = dirZ * effectiveSpeed

			enemy.velocityX = enemy.velocityX + (targetVelX - enemy.velocityX) * 0.1
			enemy.velocityZ = enemy.velocityZ + (targetVelZ - enemy.velocityZ) * 0.1

			local newX = myX + enemy.velocityX * dt
			local newZ = myZ + enemy.velocityZ * dt

			-- Simple bobbing animation
			enemy.time = enemy.time + dt
			local bobAmount = 0.2
			local bobSpeed = enemy.speed * 2
			local bob = math.sin(enemy.time * bobSpeed) * bobAmount
			local newY = enemy.baseY + bob

			-- Update facing direction
			local facingAngle = math.atan2(dx, dz) + math.pi

			-- Queue for BulkMoveTo instead of individual PivotTo
			local newCF = CFrame.new(newX, newY, newZ) * CFrame.Angles(0, facingAngle, 0)
			table.insert(partList, hrp)
			table.insert(cframeList, newCF)
		end
	end

	-- BulkMoveTo: Update all enemy positions in a single physics step
	if #partList > 0 then
		workspace:BulkMoveTo(partList, cframeList, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Clean up
	for _, id in ipairs(toRemove) do
		enemies[id] = nil
	end
end

--============================================================================
-- QUERIES
--============================================================================

function EnemyManager.get(id)
	return enemies[id]
end

function EnemyManager.getAll()
	return enemies
end

function EnemyManager.count()
	local n = 0
	for _ in pairs(enemies) do n = n + 1 end
	return n
end

function EnemyManager.findNearest(x, z, maxRange)
	-- Cap range to MAX_SEARCH_RANGE to always use spatial grid
	-- This prevents O(n) full scans on large enemy counts
	local effectiveRange = math.min(maxRange or MAX_SEARCH_RANGE, MAX_SEARCH_RANGE)
	local nearestDistSq = effectiveRange * effectiveRange

	-- Always use spatial grid for performance
	local candidates = getEnemiesNearPoint(x, z, effectiveRange)
	local nearest = nil

	for _, enemy in ipairs(candidates) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local distSq = dx * dx + dz * dz  -- Squared distance (no sqrt!)
				if distSq < nearestDistSq then
					nearestDistSq = distSq
					nearest = enemy
				end
			end
		end
	end

	-- Return actual distance for API compatibility
	return nearest, nearest and math.sqrt(nearestDistSq) or (maxRange or math.huge)
end

function EnemyManager.findWeakest(x, z, maxRange)
	-- Cap range to MAX_SEARCH_RANGE to always use spatial grid
	local effectiveRange = math.min(maxRange or MAX_SEARCH_RANGE, MAX_SEARCH_RANGE)
	local effectiveRangeSq = effectiveRange * effectiveRange

	-- Always use spatial grid for performance
	local candidates = getEnemiesNearPoint(x, z, effectiveRange)
	local weakest = nil
	local lowestHp = math.huge

	for _, enemy in ipairs(candidates) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local distSq = dx * dx + dz * dz  -- Squared distance (no sqrt!)
				if distSq <= effectiveRangeSq and enemy.hp < lowestHp then
					lowestHp = enemy.hp
					weakest = enemy
				end
			end
		end
	end

	return weakest
end

function EnemyManager.findInRange(x, z, range)
	local inRange = {}
	local candidates = getEnemiesNearPoint(x, z, range)
	local rangeSq = range * range  -- Pre-compute squared range

	for _, enemy in ipairs(candidates) do
		if enemy.hp > 0 and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local distSq = dx * dx + dz * dz  -- Squared distance (no sqrt!)
				if distSq <= rangeSq then
					table.insert(inRange, enemy)
				end
			end
		end
	end

	return inRange
end

function EnemyManager.clear()
	for id, enemy in pairs(enemies) do
		if enemy.character then
			enemy.character:Destroy()
		end
		if deps and deps.EntityRegistry then
			deps.EntityRegistry.unregister(id)
		end
	end
	enemies = {}
	table.clear(enemyGrid)  -- Clear spatial grid
end

--============================================================================
-- INIT HEARTBEAT
--============================================================================

function EnemyManager.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		EnemyManager.update(dt)
	end)
end

return EnemyManager
