-- main.server.luau
-- Server entry point for Python Tower Defense
-- Tower Defense mode with programmable turrets using Python!

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Set up collision group so players can walk through each other
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

-- Wait for modules
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local EntityRegistry = require(PythonTD.Modules.EntityRegistry)

-- Core modules
local Interpreter = require(PythonTD.Interpreter)
local Python = require(PythonTD.Python)

-- Tower Defense modules
local WaveManager = require(script.Parent.WaveManager)
local EnemyManager = require(script.Parent.EnemyManager)
local GolemRegistry = require(script.Parent.GolemRegistry)

-- Logistics modules (Supply Bots & Physical Scrap)
local ScrapManager = require(script.Parent.ScrapManager)
local BotRegistry = require(script.Parent.BotRegistry)

-- Player combat module
local PlayerCombat = require(script.Parent.PlayerCombat)

-- Load Arena map
local ArenaMap = require(script.Parent.maps.Arena)

-- Create RemoteEvents
local function createRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = PythonTD
	return event
end

-- Core remote events
local runProgramEvent = createRemoteEvent("RunProgram")
local pauseProgramEvent = createRemoteEvent("PauseProgram")
local stepProgramEvent = createRemoteEvent("StepProgram")
local resetProgramEvent = createRemoteEvent("ResetProgram")
local stateUpdateEvent = createRemoteEvent("StateUpdate")
local attackHitEvent = createRemoteEvent("AttackHit")
local playerHurtEvent = createRemoteEvent("PlayerHurt")
local manualAttackEvent = createRemoteEvent("ManualAttack")
local playerFireEvent = createRemoteEvent("PlayerFire")
local beepEvent = createRemoteEvent("Beep")
local playAnimationEvent = createRemoteEvent("PlayAnimation")
local requestStateEvent = createRemoteEvent("RequestState")
local enterBuildModeEvent = createRemoteEvent("EnterBuildMode")

-- TD-specific events
local playerReadyEvent = createRemoteEvent("PlayerReady")
local skipBuildEvent = createRemoteEvent("SkipBuild")
local waveStateEvent = createRemoteEvent("WaveState")
local playerTeleportEvent = createRemoteEvent("PlayerTeleport")
local playerMoveCompleteEvent = createRemoteEvent("PlayerMoveComplete")

-- Player interpreters
local playerInterpreters = {}
local nextPlayerId = 1

-- Default program for player (Python!)
-- Player starts with BULLET weapon program
local DEFAULT_PLAYER_PROGRAM = [[
# BULLET - Fast single target
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]]

-- Track which interpreter each player is viewing
local playerViewingGolem = {}
local playerViewingBot = {}

-- Rate limiting
local rateLimits = {}
local function checkRateLimit(player, action, cooldown)
	local key = player.UserId .. "_" .. action
	local now = tick()
	if rateLimits[key] and now - rateLimits[key] < cooldown then
		return false
	end
	rateLimits[key] = now
	return true
end

--============================================================================
-- DEPENDENCIES
--============================================================================
local deps = {
	Config = Config,
	EntityRegistry = EntityRegistry,
	attackHitEvent = attackHitEvent,
	playerHurtEvent = playerHurtEvent,
	beepEvent = beepEvent,
	playAnimationEvent = playAnimationEvent,

	-- Tower Defense systems (set after init)
	WaveManager = nil,
	EnemyManager = nil,
	GolemRegistry = nil,
	ScrapManager = nil,
	BotRegistry = nil,
	PlayerCombat = nil,
}

--============================================================================
-- PROGRESSIVE UNIT SPAWNING
--============================================================================
local spawnUnitsForWave
local spawnUnitsForPlayer  -- Forward declaration

-- Reset spawn tracking and spawn wave 1 units (defined after spawnUnitsForWave)
local function resetSpawnedUnits()
	spawnedGolems = {}
	spawnedBots = {}
	-- Reset spot ID counters
	nextGolemSpotId = 1
	nextBotSpotId = 1
	spawnUnitsForWave(1)
	GolemRegistry.broadcastState()
	BotRegistry.broadcastState()
end

--============================================================================
-- INITIALIZE TOWER DEFENSE SYSTEMS
--============================================================================

-- Initialize WaveManager
WaveManager.init(deps)
deps.WaveManager = WaveManager

-- Register callback for progressive unit spawning
WaveManager.setOnWaveStart(function(waveNumber)
	if spawnUnitsForWave then
		spawnUnitsForWave(waveNumber)
	end
end)

-- Initialize EnemyManager
EnemyManager.init(deps)
EnemyManager.setWaveManager(WaveManager)
deps.EnemyManager = EnemyManager

-- Initialize GolemRegistry
GolemRegistry.init(deps, Interpreter)
GolemRegistry.setWaveManager(WaveManager)
GolemRegistry.setEnemyManager(EnemyManager)
deps.GolemRegistry = GolemRegistry

-- Cross-link managers
WaveManager.setEnemyManager(EnemyManager)
WaveManager.setGolemRegistry(GolemRegistry)

-- Initialize Logistics systems
ScrapManager.init(deps)
deps.ScrapManager = ScrapManager

BotRegistry.init(deps, Interpreter)
BotRegistry.setWaveManager(WaveManager)
deps.BotRegistry = BotRegistry

-- Initialize PlayerCombat
PlayerCombat.init(deps)
deps.PlayerCombat = PlayerCombat

-- Listen to viewer registration events
local golemRegisterViewerEvent, golemUnregisterViewerEvent = GolemRegistry.getViewerEvents()

golemRegisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
	playerViewingGolem[player.UserId] = golemId
	playerViewingBot[player.UserId] = nil
	print("main.server: Player", player.Name, "now viewing golem", golemId)

	local golem = GolemRegistry.get(golemId)
	if golem and golem.interpreter then
		local state = golem.interpreter:getState()
		state.golemId = golemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.source = golem.interpreter.source
		state.isGolem = true
		stateUpdateEvent:FireClient(player, state)
	end
end)

golemUnregisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
	playerViewingGolem[player.UserId] = nil
	print("main.server: Player", player.Name, "returned to player view")
end)

-- Listen to bot viewer registration events
local botRegisterViewerEvent, botUnregisterViewerEvent = BotRegistry.getViewerEvents()

botRegisterViewerEvent.OnServerEvent:Connect(function(player, botId)
	playerViewingBot[player.UserId] = botId
	playerViewingGolem[player.UserId] = nil
	print("main.server: Player", player.Name, "now viewing bot", botId)

	local bot = BotRegistry.get(botId)
	if bot and bot.interpreter then
		local state = bot.interpreter:getState()
		state.botId = botId
		state.spotId = bot.spotId
		state.source = bot.interpreter.source
		state.isBot = true
		stateUpdateEvent:FireClient(player, state)
	end
end)

botUnregisterViewerEvent.OnServerEvent:Connect(function(player, botId)
	playerViewingBot[player.UserId] = nil
	print("main.server: Player", player.Name, "exited bot view")
end)

-- Start update loops
EnemyManager.startUpdateLoop()
GolemRegistry.startUpdateLoop()
ScrapManager.startUpdateLoop()
BotRegistry.startUpdateLoop()

--============================================================================
-- PROGRESSIVE UNIT SPAWNING (implementation)
-- Each player gets their own set of units!
--============================================================================
-- These are module-level so resetSpawnedUnits can access them
nextGolemSpotId = 1
nextBotSpotId = 1

-- Spawn units for a specific player based on wave unlocks
spawnUnitsForPlayer = function(player, waveNumber)
	local userId = player.UserId
	local golemsSpawned = 0
	local botsSpawned = 0

	-- Spawn golems unlocking at this wave for this player
	if ArenaMap.initialGolems then
		for i, pos in ipairs(ArenaMap.initialGolems) do
			local unlockWave = pos.unlockWave or 1
			-- Create unique key per player+slot
			local key = userId .. "_golem_" .. i
			if unlockWave <= waveNumber and not spawnedGolems[key] then
				-- Offset position slightly per player to avoid stacking
				local playerIndex = 0
				for idx, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then
						playerIndex = idx - 1
						break
					end
				end
				local offsetX = (playerIndex % 3) * 12 - 12  -- -12, 0, 12
				local offsetZ = math.floor(playerIndex / 3) * 12

				local id = GolemRegistry.create(pos.x + offsetX, pos.z + offsetZ)
				if id then
					local golem = GolemRegistry.get(id)
					if golem then
						golem.spotId = nextGolemSpotId
						golem.ownerId = userId
						nextGolemSpotId = nextGolemSpotId + 1
						spawnedGolems[key] = id
						golemsSpawned = golemsSpawned + 1
						GolemRegistry.setGolemAttribute(golem)
						print("  NEW Golem #" .. golem.spotId .. " for " .. player.Name .. "!")
					end
				end
			end
		end
	end

	-- Spawn bots unlocking at this wave for this player
	if ArenaMap.initialBots then
		for i, pos in ipairs(ArenaMap.initialBots) do
			local unlockWave = pos.unlockWave or 1
			local key = userId .. "_bot_" .. i
			if unlockWave <= waveNumber and not spawnedBots[key] then
				-- Offset position slightly per player
				local playerIndex = 0
				for idx, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then
						playerIndex = idx - 1
						break
					end
				end
				local offsetX = (playerIndex % 3) * 10 - 10
				local offsetZ = math.floor(playerIndex / 3) * 10

				local id = BotRegistry.create(pos.x + offsetX, pos.z + offsetZ)
				if id then
					local bot = BotRegistry.get(id)
					if bot then
						bot.spotId = nextBotSpotId
						bot.ownerId = userId
						nextBotSpotId = nextBotSpotId + 1
						spawnedBots[key] = id
						botsSpawned = botsSpawned + 1
						print("  NEW Bot #" .. bot.spotId .. " for " .. player.Name .. "!")
					end
				end
			end
		end
	end

	return golemsSpawned, botsSpawned
end

spawnUnitsForWave = function(waveNumber)
	local totalGolems = 0
	local totalBots = 0

	-- Spawn units for each player
	for _, player in ipairs(Players:GetPlayers()) do
		local g, b = spawnUnitsForPlayer(player, waveNumber)
		totalGolems = totalGolems + g
		totalBots = totalBots + b
	end

	if totalGolems > 0 or totalBots > 0 then
		print("Wave " .. waveNumber .. " reinforcements: +" .. totalGolems .. " turrets, +" .. totalBots .. " bots total")
		GolemRegistry.broadcastState()
		BotRegistry.broadcastState()
	end
end

-- Register restart callback
WaveManager.setOnRestart(resetSpawnedUnits)

--============================================================================
-- LOAD ARENA MAP
--============================================================================
local function loadArenaMap()
	print("Loading Arena map...")

	-- Create Core
	WaveManager.createCore(ArenaMap.core)

	-- Set spawn gates for enemies
	EnemyManager.setSpawnGates(ArenaMap.spawnGates)

	-- Set enemy path waypoints
	if ArenaMap.enemyPath then
		EnemyManager.setEnemyPath(ArenaMap.enemyPath)
	end

	-- Create fancy gate visuals
	WaveManager.createGateVisuals(ArenaMap.spawnGates)

	-- Pass full map data to GolemRegistry
	GolemRegistry.setMapData(ArenaMap)

	-- Build terrain
	local floorSize = ArenaMap.width * Config.CELL_SIZE

	-- Create floor (elevated platform)
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(floorSize, 4, floorSize)
	floor.Position = Vector3.new(floorSize / 2, Config.PLATFORM_Y - 2, floorSize / 2)
	floor.Anchored = true
	floor.Material = Config.FLOOR_MATERIAL
	floor.Color = Color3.fromRGB(60, 70, 80)
	floor.Parent = workspace

	-- Create zone visuals
	GolemRegistry.createZoneVisuals()

	-- Spawn starter units
	print("Spawning starter units...")
	spawnUnitsForWave(1)
	print("Arena map loaded! More units unlock as waves progress.")
end

loadArenaMap()

--============================================================================
-- PLAYER SETUP
--============================================================================
local function setPlayerCollisionGroup(character)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end)
end

local function onPlayerAdded(player)
	local playerId = nextPlayerId
	nextPlayerId = nextPlayerId + 1

	local function onCharacterAdded(character)
		setPlayerCollisionGroup(character)

		-- Create interpreter for player
		local interp = Interpreter.new(player, false, deps)
		interp.character = character
		interp.playerId = playerId
		interp.playerName = player.Name

		-- TD-specific: player ammo inventory
		interp.ammoInventory = Config.STARTING_AMMO or 100

		-- Logistics: player scrap inventory (players carry much more than bots)
		interp.scrapInventory = 0
		interp.maxCapacity = 500

		-- Set up Python game environment for player
		local gameEnv = Python.createPlayerEnvironment(player, interp, deps)
		interp:setGameEnvironment(gameEnv)

		-- Load default program
		interp:load(DEFAULT_PLAYER_PROGRAM)
		interp.lastProgram = DEFAULT_PLAYER_PROGRAM

		EntityRegistry.register(interp)
		playerInterpreters[player.UserId] = interp

		-- Teleport to spawn
		task.defer(function()
			local spawnPos = ArenaMap.playerSpawn
			if spawnPos and character and character.Parent then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local angle = spawnPos.facingAngle or 0
					hrp.CFrame = CFrame.new(spawnPos.x, Config.PLATFORM_Y + 3, spawnPos.z) * CFrame.Angles(0, math.rad(angle), 0)
					print("Spawned " .. player.Name .. " at arena spawn")
				end
			end
		end)

		-- Send initial state
		stateUpdateEvent:FireClient(player, interp:getState())
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Spawn units for this player based on current wave
	local waveState = WaveManager.getState()
	local currentWave = waveState.waveNumber or 0
	if currentWave >= 1 then
		-- Game is in progress, spawn units for this player
		spawnUnitsForPlayer(player, currentWave)
		GolemRegistry.broadcastState()
		BotRegistry.broadcastState()
	end
end

local function onPlayerRemoving(player)
	local userId = player.UserId

	-- Remove player's interpreter
	local interp = playerInterpreters[userId]
	if interp then
		EntityRegistry.unregister(interp.id)
		playerInterpreters[userId] = nil
	end

	-- Remove player's turrets
	if spawnedGolems then
		for key, golemId in pairs(spawnedGolems) do
			if string.match(key, "^" .. userId .. "_golem_") then
				GolemRegistry.destroy(golemId)
				spawnedGolems[key] = nil
			end
		end
	end

	-- Remove player's bots
	if spawnedBots then
		for key, botId in pairs(spawnedBots) do
			if string.match(key, "^" .. userId .. "_bot_") then
				BotRegistry.destroy(botId)
				spawnedBots[key] = nil
			end
		end
	end

	GolemRegistry.broadcastState()
	BotRegistry.broadcastState()
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Client requests current state
requestStateEvent.OnServerEvent:Connect(function(player)
	GolemRegistry.sendStateToPlayer(player)
	BotRegistry.sendStateToPlayer(player)

	-- Also send player's own interpreter state
	local interp = playerInterpreters[player.UserId]
	if interp then
		local state = interp:getState()
		state.source = interp.source
		stateUpdateEvent:FireClient(player, state)
	end
end)

--============================================================================
-- PROGRAM EXECUTION HANDLERS
--============================================================================
local MAX_PROGRAM_LENGTH = 5000  -- Python programs can be longer
local MAX_BOT_INSTRUCTIONS = 30  -- Bot programs limited to force specialization

local function sendInterpreterState(player, interpreterTarget)
	local interp, golem, bot
	if interpreterTarget.type == "golem" then
		golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	elseif interpreterTarget.type == "bot" then
		bot = BotRegistry.get(interpreterTarget.botId)
		if not bot then return end
		interp = bot.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	local state = interp:getState()

	-- Always include source for editor loading
	state.source = interp.source

	if golem then
		state.golemId = interpreterTarget.golemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.isGolem = true
	end

	if bot then
		state.botId = interpreterTarget.botId
		state.spotId = bot.spotId
		state.isBot = true
	end

	stateUpdateEvent:FireClient(player, state)
end

runProgramEvent.OnServerEvent:Connect(function(player, source, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	elseif interpreterTarget.type == "bot" then
		local bot = BotRegistry.get(interpreterTarget.botId)
		if not bot then return end
		interp = bot.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	if type(source) ~= "string" then return end
	if #source > MAX_PROGRAM_LENGTH then
		interp.error = "PROGRAM TOO LONG (max " .. MAX_PROGRAM_LENGTH .. " chars)"
		interp.status = "ERROR"
		sendInterpreterState(player, interpreterTarget)
		return
	end

	if interpreterTarget.type == "player" and player.Character then
		interp.character = player.Character
	end

	-- If paused with the same source, just unpause (resume)
	-- Otherwise, load fresh and start
	if interp.paused and interp.source == source then
		-- Resume execution without reloading
		interp.paused = false
	else
		-- Load new program and start fresh
		local loadSuccess, loadErr, instructionCount = interp:load(source)
		if loadSuccess then
			-- Check instruction limit (RAM) - enforces specialization
			instructionCount = instructionCount or (interp.runtime and interp.runtime.instructionCount) or 0
			if interpreterTarget.type == "bot" then
				if instructionCount > MAX_BOT_INSTRUCTIONS then
					interp.error = "PROGRAM TOO COMPLEX (" .. instructionCount .. "/" .. MAX_BOT_INSTRUCTIONS .. " instructions)"
					interp.status = "ERROR"
					sendInterpreterState(player, interpreterTarget)
					return
				end
			elseif interpreterTarget.type == "golem" then
				local golem = GolemRegistry.get(interpreterTarget.golemId)
				if golem then
					local maxBytecode = GolemRegistry.getMaxBytecode(golem.tier)
					if instructionCount > maxBytecode then
						interp.error = "NOT ENOUGH RAM (" .. instructionCount .. "/" .. maxBytecode .. " instructions) - Upgrade for more!"
						interp.status = "ERROR"
						sendInterpreterState(player, interpreterTarget)
						return
					end
				end
			end
			interp.lastProgram = source
		end
		interp.paused = false
	end

	sendInterpreterState(player, interpreterTarget)
end)

pauseProgramEvent.OnServerEvent:Connect(function(player, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	elseif interpreterTarget.type == "bot" then
		local bot = BotRegistry.get(interpreterTarget.botId)
		if not bot then return end
		interp = bot.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	-- Toggle pause/resume
	interp.paused = not interp.paused
	sendInterpreterState(player, interpreterTarget)
end)

-- Step program (execute one step while paused)
stepProgramEvent.OnServerEvent:Connect(function(player, source, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	elseif interpreterTarget.type == "bot" then
		local bot = BotRegistry.get(interpreterTarget.botId)
		if not bot then return end
		interp = bot.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	-- If not running yet, load the source first
	if interp.status ~= "RUNNING" and interp.status ~= "PAUSED" then
		interp:load(source)
	end

	-- Ensure we're paused for stepping
	interp.paused = true

	-- Execute a single step
	if interp.stepOnce then
		interp:stepOnce()
	end

	sendInterpreterState(player, interpreterTarget)
end)

resetProgramEvent.OnServerEvent:Connect(function(player)
	local interp = playerInterpreters[player.UserId]
	if not interp then return end

	interp:reset()
	stateUpdateEvent:FireClient(player, interp:getState())
end)

manualAttackEvent.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "attack", 0.2) then return end

	local interp = playerInterpreters[player.UserId]
	if not interp then return end

	if player.Character then
		interp.character = player.Character
	end

	-- Call hit function from game environment
	if interp.gameEnv and interp.gameEnv.hit then
		interp.gameEnv.hit()
	end

	stateUpdateEvent:FireClient(player, interp:getState())
end)

-- Player movement complete callback - unblocks VM
playerMoveCompleteEvent.OnServerEvent:Connect(function(player)
	local interp = playerInterpreters[player.UserId]
	if interp and interp.runtime and interp.runtime.vm then
		interp.runtime.vm:unblock()
	end
end)

-- Player fire event (ranged projectile attack)
playerFireEvent.OnServerEvent:Connect(function(player, ammoType)
	if not checkRateLimit(player, "fire", 0.15) then return end

	local interp = playerInterpreters[player.UserId]
	if not interp then return end

	if player.Character then
		interp.character = player.Character
	end

	-- Call fire function from game environment
	if interp.gameEnv and interp.gameEnv.self and interp.gameEnv.self.fire then
		interp.gameEnv.self.fire(ammoType or 1)
	end

	stateUpdateEvent:FireClient(player, interp:getState())
end)

--============================================================================
-- MAIN UPDATE LOOP
--============================================================================
local tickAccum = 0

RunService.Heartbeat:Connect(function(dt)
	tickAccum = tickAccum + dt

	-- Update Tower Defense systems
	WaveManager.update(dt)

	-- Player interpreter updates
	if tickAccum >= Config.PLAYER_TICK_RATE then
		tickAccum = 0

		for userId, interp in pairs(playerInterpreters) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				if player.Character then
					interp.character = player.Character
				end

				-- Death handling
				if interp.hp <= 0 and not interp.dead then
					interp.dead = true
					interp.deathTime = tick()

					if interp.character then
						local humanoid = interp.character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid.PlatformStand = true
							humanoid.WalkSpeed = 0
							humanoid.JumpPower = 0
						end
					end
				end

				-- Auto-respawn
				if interp.dead and interp.deathTime and (tick() - interp.deathTime > Config.RESPAWN_TIME) then
					interp.dead = false
					interp.hp = interp.maxHp
					interp.deathTime = nil

					if interp.character then
						local humanoid = interp.character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid.PlatformStand = false
							humanoid.WalkSpeed = Config.MANUAL_WALKING_SPEED
							humanoid.JumpPower = 50
						end

						local spawnPos = ArenaMap.playerSpawn
						if spawnPos then
							local hrp = interp.character:FindFirstChild("HumanoidRootPart")
							if hrp then
								hrp.CFrame = CFrame.new(spawnPos.x, Config.PLATFORM_Y + 3, spawnPos.z)
							end
						end
					end
				end

				-- Run interpreter
				if not interp.paused and not interp.dead and (interp.status == "READY" or interp.status == "RUNNING") then
					interp:run(Config.PLAYER_TICKS_PER_UPDATE or 1)
				end

				-- Auto scrap pickup (player walks near scrap)
				if not interp.dead and player.Character then
					local hrp = player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						local px, pz = hrp.Position.X, hrp.Position.Z
						local pickupRange = 5 -- studs
						local scrapsInRange = ScrapManager.findInRange(px, pz, pickupRange)
						for _, scrap in ipairs(scrapsInRange) do
							local capacity = (interp.maxCapacity or 50) - (interp.scrapInventory or 0)
							if capacity > 0 then
								local collected = ScrapManager.collect(scrap.id, interp)
								if collected > 0 then
									-- Visual feedback would go here
								end
							end
						end

						-- Auto deposit to core (player near core)
						local coreX, coreZ = ArenaMap.core.x, ArenaMap.core.z
						local distToCore = math.sqrt((px - coreX)^2 + (pz - coreZ)^2)
						local depositRange = 10 -- studs
						if distToCore <= depositRange and (interp.scrapInventory or 0) > 0 then
							local toDeposit = interp.scrapInventory
							WaveManager.addScrap(toDeposit)
							interp.scrapInventory = 0
							-- Visual feedback would go here
						end
					end
				end

				-- Build state for client
				local viewingGolemId = playerViewingGolem[userId]
				local viewingBotId = playerViewingBot[userId]
				local state

				if viewingGolemId then
					local golem = GolemRegistry.get(viewingGolemId)
					if golem and golem.interpreter then
						state = golem.interpreter:getDynamicState()
						state.golemId = viewingGolemId
						state.spotId = golem.spotId
						state.typeName = golem.typeData and golem.typeData.name
						state.isGolem = true
						state.source = golem.interpreter.source  -- Include source for editor
					else
						state = interp:getDynamicState()
						state.source = interp.source
						playerViewingGolem[userId] = nil
					end
				elseif viewingBotId then
					local bot = BotRegistry.get(viewingBotId)
					if bot and bot.interpreter then
						state = bot.interpreter:getDynamicState()
						state.botId = viewingBotId
						state.spotId = bot.spotId
						state.isBot = true
						state.source = bot.interpreter.source  -- Include source for editor
					else
						state = interp:getDynamicState()
						state.source = interp.source
						playerViewingBot[userId] = nil
					end
				else
					state = interp:getDynamicState()
					state.source = interp.source  -- Include source for editor
				end

				-- Add player list
				local allPlayers = {}
				for _, entity in pairs(EntityRegistry.getAll()) do
					if entity.isPlayer then
						table.insert(allPlayers, {
							id = entity.playerId,
							name = entity.playerName or "Player",
							hp = entity.hp,
							maxHp = entity.maxHp,
							dead = entity.dead,
							isMe = (entity.id == interp.id),
						})
					end
				end
				table.sort(allPlayers, function(a, b) return a.id < b.id end)
				state.allPlayers = allPlayers
				state.myPlayerId = interp.playerId

				-- Add TD-specific state
				state.scrap = WaveManager.getScrap()
				state.ammoInventory = interp.ammoInventory
				state.scrapInventory = interp.scrapInventory or 0
				state.maxCapacity = interp.maxCapacity or 50

				-- Add wave state
				local waveState = WaveManager.getState()
				state.waveNumber = waveState.waveNumber
				state.phase = waveState.phase
				state.coreHp = waveState.coreHp
				state.coreMaxHp = waveState.coreMaxHp
				state.buildTimeRemaining = waveState.buildTimeRemaining
				state.restartTimeRemaining = waveState.restartTimeRemaining
				state.enemiesRemaining = waveState.enemiesRemaining

				-- Add enemy minimap data (lightweight for network)
				state.enemyMinimap = EnemyManager.getMinimapData()
				state.pathLength = EnemyManager.getPathLength()

				-- Add next wave preview (count of each enemy type)
				local nextWavePreview = WaveManager.getWavePreview()
				local nextWaveSummary = {}
				for _, typeName in ipairs(nextWavePreview) do
					nextWaveSummary[typeName] = (nextWaveSummary[typeName] or 0) + 1
				end
				state.nextWavePreview = nextWaveSummary
				state.nextWaveNumber = waveState.waveNumber + 1

				-- Death countdown
				if interp.dead and interp.deathTime then
					state.deathTimeRemaining = math.max(0, Config.RESPAWN_TIME - (tick() - interp.deathTime))
					state.dead = true
				end

				stateUpdateEvent:FireClient(player, state)
			end
		end

		-- Broadcast golem state periodically
		GolemRegistry.broadcastState()
	end
end)

print("Python Tower Defense server initialized!")
print("Game Mode: Tower Defense with Python programming!")
print("Defend the Core from enemy waves!")
