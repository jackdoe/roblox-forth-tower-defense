-- WaveManager.luau
-- Core game loop for Tower Defense mode
-- Manages waves, Core HP, game phases, and scrap economy

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local WaveManager = {}

-- Ground level Y coordinate
local GROUND_Y = Config.PLATFORM_Y

-- Dependencies (set via init)
local deps = nil
local EnemyManager = nil
local GolemRegistry = nil

-- Callbacks (set by main.server)
local onWaveStartCallback = nil
local onRestartCallback = nil

-- Game state
local state = {
	phase = "LOBBY", -- LOBBY, BUILD, COMBAT, UPGRADE, GAMEOVER, VICTORY
	waveNumber = 0,
	totalWaves = 0, -- Infinite waves now (NG+ after wave 8)

	-- Core (the thing we're defending)
	coreHp = 1000,
	coreMaxHp = 1000,
	corePosition = nil, -- Set from map
	coreModel = nil,

	-- Economy (shared core scrap)
	scrap = 0, -- Single shared scrap value for the core

	-- Timing
	buildTime = 30,     -- Seconds for build phase
	buildTimeRemaining = 0,
	waveSpawnInterval = 2, -- Seconds between enemy spawns in wave

	-- Wave tracking
	enemiesRemaining = 0,
	enemiesSpawned = 0,
	enemiesToSpawn = 0,
	spawnQueue = {}, -- { {type, gate, delay}, ... }

	-- Ready system (for lobby)
	readyPlayers = {},

	-- Restart countdown
	restartTimeRemaining = 0,

	-- Current wave composition (for preview)
	currentWaveComposition = {},
}

-- Remote events
local coreHitEvent = nil
local playerReadyEvent = nil
local skipBuildEvent = nil
local waveStateEvent = nil

-- Enemy types for procedural generation
local ENEMY_TYPES = {"Zombie", "Runner", "Tank"}


--============================================================================
-- PROCEDURAL WAVE GENERATION
--============================================================================

-- Generate a random wave composition based on wave number
-- Higher waves = more enemies, more bosses (up to 5), faster spawns
function WaveManager.generateWave(waveNum)
	local composition = {}

	-- Base enemy count scales with wave (10 + wave * 3)
	local baseCount = 10 + waveNum * 3
	-- Add some randomness (+/- 20%)
	local enemyCount = math.floor(baseCount * (0.8 + math.random() * 0.4))

	-- Spawn interval gets faster with waves (starts 2s, min 0.5s)
	local interval = math.max(0.5, 2 - waveNum * 0.1)

	-- Generate random enemies (Zombie, Runner, Tank)
	-- Higher waves unlock more enemy types
	local availableTypes = {"Zombie"}
	if waveNum >= 2 then table.insert(availableTypes, "Runner") end
	if waveNum >= 4 then table.insert(availableTypes, "Tank") end

	for i = 1, enemyCount do
		local enemyType = availableTypes[math.random(#availableTypes)]
		table.insert(composition, {
			type = enemyType,
			delay = (i - 1) * interval + math.random() * 0.2,
		})
	end

	-- Boss count: higher waves = more chance for multiple bosses
	-- Wave 1-2: 1 boss, Wave 3-5: 1-2, Wave 6-8: 1-3, Wave 9+: 1-5
	local maxBosses = math.min(5, math.floor(waveNum / 2) + 1)
	-- Probability increases with wave number
	local bossCount = 1
	for i = 2, maxBosses do
		-- Each additional boss has (wave * 5)% chance
		if math.random(100) < waveNum * 5 then
			bossCount = bossCount + 1
		end
	end

	-- Add bosses at the end (last boss is always last enemy)
	local lastDelay = #composition > 0 and composition[#composition].delay or 0
	for i = 1, bossCount do
		table.insert(composition, {
			type = "Boss",
			delay = lastDelay + 2 + (i - 1) * 3, -- Bosses spawn after regular enemies, 3s apart
		})
	end

	-- Store for preview
	state.currentWaveComposition = composition

	return composition
end

-- Get preview list for HUD (returns array of enemy type strings in spawn order)
function WaveManager.getWavePreview()
	-- Generate next wave if not cached
	local nextWave = state.waveNumber + 1
	if #state.currentWaveComposition == 0 then
		WaveManager.generateWave(nextWave)
	end

	-- Return first 20 enemies as type names
	local previewList = {}
	for i = 1, math.min(#state.currentWaveComposition, 20) do
		table.insert(previewList, state.currentWaveComposition[i].type)
	end

	return previewList
end

--============================================================================
-- INITIALIZATION
--============================================================================

function WaveManager.init(dependencies)
	deps = dependencies

	-- Find existing remote events (created by main.server.luau)
	local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")

	-- These events are already created by main.server.luau, just find them
	playerReadyEvent = PythonTD:WaitForChild("PlayerReady")
	skipBuildEvent = PythonTD:WaitForChild("SkipBuild")
	waveStateEvent = PythonTD:WaitForChild("WaveState")

	-- CoreHit might not exist yet, create if needed
	coreHitEvent = PythonTD:FindFirstChild("CoreHit")
	if not coreHitEvent then
		coreHitEvent = Instance.new("RemoteEvent")
		coreHitEvent.Name = "CoreHit"
		coreHitEvent.Parent = PythonTD
	end

	-- Handle player ready
	playerReadyEvent.OnServerEvent:Connect(function(player)
		WaveManager.playerReady(player.UserId)
	end)

	-- Handle skip build phase
	skipBuildEvent.OnServerEvent:Connect(function(player)
		WaveManager.skipBuildPhase()
	end)

	-- Initialize core scrap
	state.scrap = deps.Config.STARTING_SCRAP or 200

	-- Handle player ready state cleanup
	Players.PlayerRemoving:Connect(function(player)
		state.readyPlayers[player.UserId] = nil
	end)

	-- Pre-generate first wave preview for lobby
	WaveManager.generateWave(1)

	print("WaveManager: Initialized")
end

function WaveManager.setEnemyManager(enemyMgr)
	EnemyManager = enemyMgr
end

function WaveManager.setGolemRegistry(golemReg)
	GolemRegistry = golemReg
end

--============================================================================
-- CORE MANAGEMENT
--============================================================================

-- NEW: Helper to create fancy visual gates
function WaveManager.createGateVisuals(gates)
	local corePos = state.corePosition
	if not corePos then return end

	for i, gate in ipairs(gates) do
		local model = Instance.new("Model")
		model.Name = "Gate_" .. i

		-- Calculate angle to face the core
		local dx = corePos.x - gate.x
		local dz = corePos.z - gate.z
		local angleToCore = math.atan2(dx, dz)

		-- Gate position and rotation base
		local gatePos = Vector3.new(gate.x, GROUND_Y, gate.z)
		local gateCFrame = CFrame.new(gatePos) * CFrame.Angles(0, angleToCore, 0)

		-- 1. The Frame (Archway)
		local frameColor = Color3.fromRGB(80, 80, 80)
		local neonColor = Color3.fromRGB(255, 50, 50) -- Enemy Red

		-- Left Pillar
		local leftPillar = Instance.new("Part")
		leftPillar.Size = Vector3.new(2, 12, 2)
		leftPillar.CFrame = gateCFrame * CFrame.new(-4, 6, 0)
		leftPillar.Anchored = true
		leftPillar.Material = Enum.Material.Metal
		leftPillar.Color = frameColor
		leftPillar.Parent = model

		local leftStripe = Instance.new("Part")
		leftStripe.Size = Vector3.new(0.5, 10, 2.1)
		leftStripe.CFrame = leftPillar.CFrame
		leftStripe.Anchored = true
		leftStripe.CanCollide = false
		leftStripe.Material = Enum.Material.Neon
		leftStripe.Color = neonColor
		leftStripe.Parent = model

		-- Right Pillar
		local rightPillar = Instance.new("Part")
		rightPillar.Size = Vector3.new(2, 12, 2)
		rightPillar.CFrame = gateCFrame * CFrame.new(4, 6, 0)
		rightPillar.Anchored = true
		rightPillar.Material = Enum.Material.Metal
		rightPillar.Color = frameColor
		rightPillar.Parent = model

		local rightStripe = Instance.new("Part")
		rightStripe.Size = Vector3.new(0.5, 10, 2.1)
		rightStripe.CFrame = rightPillar.CFrame
		rightStripe.Anchored = true
		rightStripe.CanCollide = false
		rightStripe.Material = Enum.Material.Neon
		rightStripe.Color = neonColor
		rightStripe.Parent = model

		-- Top Bar
		local top = Instance.new("Part")
		top.Size = Vector3.new(12, 2, 3)
		top.CFrame = gateCFrame * CFrame.new(0, 13, 0)
		top.Anchored = true
		top.Material = Enum.Material.Metal
		top.Color = frameColor
		top.Parent = model

		-- 2. The Portal Field (Swirling Void)
		local field = Instance.new("Part")
		field.Name = "Field"
		field.Size = Vector3.new(6, 10, 0.2)
		field.CFrame = gateCFrame * CFrame.new(0, 7, 0)
		field.Anchored = true
		field.CanCollide = false
		field.Material = Enum.Material.ForceField
		field.Color = neonColor
		field.Transparency = 0.5
		field.Parent = model

		-- Gate Text
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 100, 0, 50)
		bb.StudsOffset = Vector3.new(0, 8, 0)
		bb.AlwaysOnTop = true
		bb.Parent = top
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = "GATE " .. i
		txt.TextColor3 = neonColor
		txt.Font = Enum.Font.SciFi
		txt.TextSize = 20
		txt.Parent = bb

		model.Parent = workspace
	end
end

-- UPDATED: createCore with animation and particles
function WaveManager.createCore(position)
	state.corePosition = position
	state.coreHp = state.coreMaxHp

	local model = Instance.new("Model")
	model.Name = "CoreModel"

	-- 1. Base Pedestal
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(1, 12, 12) -- Cylinders are rotated, size is (height, dia, dia)
	base.Position = Vector3.new(position.x, GROUND_Y + 0.5, position.z)
	base.Orientation = Vector3.new(0, 0, 90)
	base.Anchored = true
	base.Material = Enum.Material.Metal
	base.Color = Color3.fromRGB(50, 50, 60)
	base.Parent = model

	-- 2. The Crystal (The actual Core Hitbox)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(4, 4, 4)
	core.Position = Vector3.new(position.x, GROUND_Y + 8, position.z)
	core.Anchored = true
	core.CanCollide = true
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(0, 255, 255) -- Cyan
	core.Shape = Enum.PartType.Ball
	core.Transparency = 0.2
	core.Parent = model

	-- Make it look like a Diamond
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://9756362" -- Standard Diamond Mesh
	mesh.Scale = Vector3.new(4, 8, 4)
	mesh.Parent = core


	-- 4. Particles
	local attachment = Instance.new("Attachment", core)
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxassetid://243098098" -- Generic sparkle
	particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 20
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Parent = attachment

	-- 5. Floating Animation for Crystal
	local floatInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local floatGoal = { Position = core.Position + Vector3.new(0, 1.5, 0) }
	TweenService:Create(core, floatInfo, floatGoal):Play()

	-- 6. Spin the crystal
	task.spawn(function()
		while core and core.Parent do
			core.CFrame = core.CFrame * CFrame.Angles(0, math.rad(1), 0)
			-- Color shifts based on HP
			local hpRatio = state.coreHp / state.coreMaxHp
			if hpRatio > 0.5 then
				core.Color = Color3.fromRGB(0, 255, 255)
			elseif hpRatio > 0.25 then
				core.Color = Color3.fromRGB(255, 200, 100)
			else
				core.Color = Color3.fromRGB(255, 100, 100)
			end
			task.wait(0.02)
		end
	end)

	model.Parent = workspace
	state.coreModel = core
	print("WaveManager: Fancy Core created at", position.x, position.z)
end

function WaveManager.damageCore(amount, enemyId)
	if state.phase == "GAMEOVER" then return end

	state.coreHp = math.max(0, state.coreHp - amount)

	-- Notify clients of hit
	for _, player in ipairs(Players:GetPlayers()) do
		coreHitEvent:FireClient(player, {
			damage = amount,
			currentHp = state.coreHp,
			maxHp = state.coreMaxHp,
		})
	end

	-- Check for game over
	if state.coreHp <= 0 then
		WaveManager.gameOver()
	end
end

function WaveManager.getCorePosition()
	return state.corePosition
end

function WaveManager.getCoreHp()
	return state.coreHp, state.coreMaxHp
end

function WaveManager.resetCoreVisual()
	if state.coreModel then
		local core = state.coreModel:FindFirstChild("Core")
		if core then
			core.Color = Color3.fromRGB(0, 255, 255) -- Cyan
			core.Transparency = 0.2
		end
	end
end

--============================================================================
-- PHASE MANAGEMENT
--============================================================================

function WaveManager.setPhase(newPhase)
	local oldPhase = state.phase
	state.phase = newPhase

	print("WaveManager: Phase changed from", oldPhase, "to", newPhase)

	if newPhase == "BUILD" then
		state.buildTimeRemaining = state.buildTime
	elseif newPhase == "COMBAT" then
		WaveManager.startWave()
	end
end

function WaveManager.getPhase()
	return state.phase
end

function WaveManager.playerReady(userId)
	state.readyPlayers[userId] = true

	-- CHANGED: If ANY player presses ready, start the game.
	-- No waiting for everyone.
	WaveManager.setPhase("BUILD")
end

function WaveManager.skipBuildPhase()
	-- CHANGED: If ANY player presses skip, start combat immediately.
	if state.phase == "BUILD" then
		state.buildTimeRemaining = 0
		WaveManager.setPhase("COMBAT")
	end
end

--============================================================================
-- WAVE MANAGEMENT
--============================================================================

-- Set callback for wave start (for progressive unit spawning)
function WaveManager.setOnWaveStart(callback)
	onWaveStartCallback = callback
end

function WaveManager.setOnRestart(callback)
	onRestartCallback = callback
end

function WaveManager.startWave()
	state.waveNumber = state.waveNumber + 1

	-- Trigger callback for progressive spawning
	if onWaveStartCallback then
		onWaveStartCallback(state.waveNumber)
	end

	-- Scale enemies based on player count (more players = more enemies)
	local playerCount = #Players:GetPlayers()
	local playerMultiplier = 1 + (playerCount - 1) * 0.5 -- +50% enemies per extra player

	-- Simple linear scaling for enemy stats (+10% per wave)
	local waveMultiplier = 1 + (state.waveNumber - 1) * 0.1
	if EnemyManager then
		EnemyManager.setNewGamePlusMultiplier(waveMultiplier)
		EnemyManager.setWave(state.waveNumber)
	end

	print("WaveManager: Starting wave", state.waveNumber, "with", playerCount, "players, multiplier:", string.format("%.1fx", waveMultiplier))

	-- Use pre-generated wave composition (or generate if not cached)
	local waveComposition = state.currentWaveComposition
	if #waveComposition == 0 then
		waveComposition = WaveManager.generateWave(state.waveNumber)
	end

	-- Build spawn queue from composition (all enemies spawn from gate 1)
	state.spawnQueue = {}
	state.enemiesToSpawn = 0
	state.enemiesSpawned = 0
	state.enemiesRemaining = 0

	for _, enemy in ipairs(waveComposition) do
		-- Scale count for multiplayer (but bosses always spawn as-is)
		local count = 1
		if enemy.type ~= "Boss" then
			count = math.ceil(playerMultiplier)
		end
		for i = 1, count do
			table.insert(state.spawnQueue, {
				type = enemy.type,
				gate = 1, -- Single gate only
				delay = enemy.delay + (i - 1) * 0.3, -- Slight offset for extra spawns
			})
			state.enemiesToSpawn = state.enemiesToSpawn + 1
		end
	end

	-- Sort by delay
	table.sort(state.spawnQueue, function(a, b) return a.delay < b.delay end)

	state.waveStartTime = tick()
	state.enemiesRemaining = state.enemiesToSpawn

	-- Clear composition for next wave generation
	state.currentWaveComposition = {}
end

function WaveManager.onEnemyKilled(enemyId, killerGolemId)
	state.enemiesRemaining = state.enemiesRemaining - 1

	-- NOTE: Direct scrap awards removed!
	-- Scrap now drops physically on the ground when enemies die.
	-- Supply Bots collect it and deliver to core.
	-- Small "assist" bonus for the kill goes to core.
	local assistBonus = deps.Config.SCRAP_ASSIST_BONUS or 2
	WaveManager.addScrap(assistBonus)

	-- Check if wave complete
	if state.enemiesRemaining <= 0 and state.enemiesSpawned >= state.enemiesToSpawn then
		WaveManager.waveComplete()
	end
end

function WaveManager.onEnemyReachedCore(enemyId)
	state.enemiesRemaining = state.enemiesRemaining - 1

	-- Check if wave complete
	if state.enemiesRemaining <= 0 and state.enemiesSpawned >= state.enemiesToSpawn then
		WaveManager.waveComplete()
	end
end

function WaveManager.waveComplete()
	print("WaveManager: Wave", state.waveNumber, "complete!")

	-- MELTDOWN: Kill all temporary bots (FORK clones die at wave end)
	if deps.BotRegistry then
		deps.BotRegistry.killTemporaryBots()
	end

	-- Bonus scrap for completing wave (50 * wave number)
	local bonusScrap = state.waveNumber * 50
	WaveManager.addScrap(bonusScrap)

	-- Pre-generate next wave composition for preview
	WaveManager.generateWave(state.waveNumber + 1)

	-- Infinite waves - always go to build phase
	WaveManager.setPhase("BUILD")
end

--============================================================================
-- ECONOMY
--============================================================================

function WaveManager.addScrap(amount)
	state.scrap = (state.scrap or 0) + amount
end

function WaveManager.removeScrap(amount)
	local current = state.scrap or 0
	if current >= amount then
		state.scrap = current - amount
		return true
	end
	return false
end

function WaveManager.getScrap()
	return state.scrap or 0
end

--============================================================================
-- GAME END
--============================================================================

function WaveManager.gameOver()
	state.phase = "GAMEOVER"
	state.restartTimeRemaining = 10 -- 10 second countdown
	print("WaveManager: GAME OVER - Core destroyed!")
end

function WaveManager.restart()
	print("WaveManager: Restarting game...")

	-- Clear enemies
	if EnemyManager then
		EnemyManager.clear()
		EnemyManager.setNewGamePlusMultiplier(1) -- Reset NG+ multiplier
	end

	-- Clear golems
	if GolemRegistry then
		GolemRegistry.clear()
	end

	-- Clear logistics (Supply Bots & Physical Scrap)
	if deps.ScrapManager then
		deps.ScrapManager.clear()
	end
	if deps.BotRegistry then
		deps.BotRegistry.clear()
	end

	-- Reset state
	state.phase = "LOBBY"
	state.waveNumber = 0
	state.coreHp = state.coreMaxHp
	state.readyPlayers = {}
	state.spawnQueue = {}
	state.enemiesRemaining = 0
	state.enemiesSpawned = 0
	state.currentWaveComposition = {}

	-- Reset scrap
	state.scrap = deps.Config.STARTING_SCRAP or 200

	-- Pre-generate first wave preview
	WaveManager.generateWave(1)

	-- Reset core visual
	WaveManager.resetCoreVisual()

	-- Call restart callback (spawns initial units)
	if onRestartCallback then
		onRestartCallback()
	end

	-- Broadcast updated state
	WaveManager.broadcastState()
end

--============================================================================
-- UPDATE LOOP
--============================================================================

function WaveManager.update(dt)
	if state.phase == "BUILD" then
		-- Countdown build timer
		state.buildTimeRemaining = state.buildTimeRemaining - dt
		if state.buildTimeRemaining <= 0 then
			WaveManager.setPhase("COMBAT")
		end
	elseif state.phase == "COMBAT" then
		-- Process spawn queue
		local elapsed = tick() - state.waveStartTime

		while #state.spawnQueue > 0 and state.spawnQueue[1].delay <= elapsed do
			local spawn = table.remove(state.spawnQueue, 1)

			if EnemyManager then
				EnemyManager.spawn(spawn.type, spawn.gate, deps)
				state.enemiesSpawned = state.enemiesSpawned + 1
			end
		end
	elseif state.phase == "GAMEOVER" then
		-- Countdown restart timer
		local prevSecond = math.ceil(state.restartTimeRemaining)
		state.restartTimeRemaining = state.restartTimeRemaining - dt
		local newSecond = math.ceil(state.restartTimeRemaining)

		-- Broadcast once per second so client sees countdown
		if newSecond ~= prevSecond and state.restartTimeRemaining > 0 then
			WaveManager.broadcastState()
		end

		if state.restartTimeRemaining <= 0 then
			WaveManager.restart()
		end
	end
end

--============================================================================
-- STATE BROADCAST
--============================================================================

function WaveManager.broadcastState()
	local stateData = {
		phase = state.phase,
		waveNumber = state.waveNumber,
		coreHp = state.coreHp,
		coreMaxHp = state.coreMaxHp,
		buildTimeRemaining = state.buildTimeRemaining,
		restartTimeRemaining = state.restartTimeRemaining,
		enemiesRemaining = state.enemiesRemaining,
		readyCount = 0,
		totalPlayers = #Players:GetPlayers(),
		wavePreview = WaveManager.getWavePreview(), -- Preview of next wave
	}

	-- Count ready players
	for userId, _ in pairs(state.readyPlayers) do
		stateData.readyCount = stateData.readyCount + 1
	end

	stateData.scrap = state.scrap or 0
	for _, player in ipairs(Players:GetPlayers()) do
		stateData.isReady = state.readyPlayers[player.UserId] or false
		waveStateEvent:FireClient(player, stateData)
	end
end

function WaveManager.getState()
	return state
end

return WaveManager
