-- main.server.luau
-- Server entry point for Forthy: Iron Defense
-- Tower Defense mode with programmable turrets!

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Set up collision group so players can walk through each other
PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

-- Wait for modules
local Forthy = ReplicatedStorage:WaitForChild("Forthy")
local Config = require(Forthy.Config)
local EntityRegistry = require(Forthy.Modules.EntityRegistry)

-- Core modules (Interpreter is now in ReplicatedStorage for client access)
local Interpreter = require(Forthy.Interpreter)

-- Game-specific word modules (remain on server, passed through deps)
local SharedWords = require(script.Parent.Words.SharedWords)
local GameWords = require(script.Parent.Words.GameWords)
local GolemWords = require(script.Parent.Words.GolemWords)
local LogisticsWords = require(script.Parent.Words.LogisticsWords)

-- Tower Defense modules
local WaveManager = require(script.Parent.WaveManager)
local EnemyManager = require(script.Parent.EnemyManager)
local GolemRegistry = require(script.Parent.GolemRegistry)

-- Legacy modules (kept for compatibility, can be removed later)
local DayNightCycle = require(script.Parent.DayNightCycle)

-- Load Arena map
local ArenaMap = require(script.Parent.maps.Arena)

-- Create RemoteEvents
local function createRemoteEvent(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = Forthy
	return event
end

local function createRemoteFunction(name)
	local func = Instance.new("RemoteFunction")
	func.Name = name
	func.Parent = Forthy
	return func
end

-- Core remote events (kept from original)
local runProgramEvent = createRemoteEvent("RunProgram")
local pauseProgramEvent = createRemoteEvent("PauseProgram")
local stepProgramEvent = createRemoteEvent("StepProgram")
local resetProgramEvent = createRemoteEvent("ResetProgram")
local stateUpdateEvent = createRemoteEvent("StateUpdate")
local attackHitEvent = createRemoteEvent("AttackHit")
local playerHurtEvent = createRemoteEvent("PlayerHurt")
local manualAttackEvent = createRemoteEvent("ManualAttack")
local beepEvent = createRemoteEvent("Beep")
local playAnimationEvent = createRemoteEvent("PlayAnimation")
local updateWordSlotEvent = createRemoteEvent("UpdateWordSlot")
local enterBuildModeEvent = createRemoteEvent("EnterBuildMode")

-- Player interpreters
local playerInterpreters = {}
local nextPlayerId = 1

-- Track which interpreter each player is viewing (for unified state updates)
-- nil = viewing own player interpreter, golemId = viewing that golem
local playerViewingGolem = {}

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
-- SHARED MEMORY (S0-S9 for co-op communication)
--============================================================================
local GlobalMemory = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

--============================================================================
-- DEPENDENCIES
--============================================================================
local deps = {
	Config = Config,
	EntityRegistry = EntityRegistry,
	attackHitEvent = attackHitEvent,
	playerHurtEvent = playerHurtEvent,
	beepEvent = beepEvent,
	enterBuildModeEvent = enterBuildModeEvent,
	playAnimationEvent = playAnimationEvent,

	-- Game-specific word modules (passed to Interpreter)
	SharedWords = SharedWords,
	GameWords = GameWords,
	GolemWords = GolemWords,
	LogisticsWords = LogisticsWords,

	-- Tower Defense systems
	WaveManager = nil, -- Set after init
	EnemyManager = nil, -- Set after init
	GolemRegistry = nil, -- Set after init

	-- Shared memory for co-op
	GlobalMemory = GlobalMemory,
}

--============================================================================
-- INITIALIZE TOWER DEFENSE SYSTEMS
--============================================================================

-- Initialize WaveManager
WaveManager.init(deps)
deps.WaveManager = WaveManager

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

-- Listen to viewer registration events
local golemRegisterViewerEvent, golemUnregisterViewerEvent = GolemRegistry.getViewerEvents()

golemRegisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
	playerViewingGolem[player.UserId] = golemId
	print("main.server: Player", player.Name, "now viewing golem", golemId)

	-- Send full golem state immediately (includes programSource)
	local golem = GolemRegistry.get(golemId)
	if golem and golem.interpreter then
		local state = golem.interpreter:getState()
		state.golemId = golemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.programSource = table.concat(golem.interpreter.tokens or {}, " ")
		state.isGolem = true
		stateUpdateEvent:FireClient(player, state)
	end
end)

golemUnregisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
	playerViewingGolem[player.UserId] = nil
	print("main.server: Player", player.Name, "returned to player view")
end)

-- Start update loops
EnemyManager.startUpdateLoop()
GolemRegistry.startUpdateLoop()

--============================================================================
-- LOAD ARENA MAP
--============================================================================

local function loadArenaMap()
	print("Loading Arena map...")

	-- Create Core
	WaveManager.createCore(ArenaMap.core)

	-- Set spawn gates for enemies
	EnemyManager.setSpawnGates(ArenaMap.spawnGates)

	-- Create fancy gate visuals
	WaveManager.createGateVisuals(ArenaMap.spawnGates)

	-- Pass full map data to GolemRegistry (for free placement zones)
	GolemRegistry.setMapData(ArenaMap)

	-- Build terrain (simplified for TD - mostly just floor and boundaries)
	local floorSize = ArenaMap.width * Config.CELL_SIZE

	-- Create floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(floorSize, 1, floorSize)
	floor.Position = Vector3.new(floorSize / 2, -0.5, floorSize / 2)
	floor.Anchored = true
	floor.Material = Config.FLOOR_MATERIAL
	floor.Color = Color3.fromRGB(60, 70, 80)
	floor.Parent = workspace

	-- Create zone visuals showing restricted areas (paths, core, gates)
	GolemRegistry.createZoneVisuals()

	print("Arena map loaded!")
end

loadArenaMap()

-- Start day/night cycle (if enabled)
if Config.DAY_NIGHT_CYCLE.ENABLED then
	DayNightCycle.start()
end

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

		EntityRegistry.register(interp)
		playerInterpreters[player.UserId] = interp

		-- Teleport to spawn
		task.defer(function()
			local spawnPos = ArenaMap.playerSpawn
			if spawnPos and character and character.Parent then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local angle = spawnPos.facingAngle or 0
					hrp.CFrame = CFrame.new(spawnPos.x, 3, spawnPos.z) * CFrame.Angles(0, math.rad(angle), 0)
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
end

local function onPlayerRemoving(player)
	local interp = playerInterpreters[player.UserId]
	if interp then
		EntityRegistry.unregister(interp.id)
		playerInterpreters[player.UserId] = nil
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

--============================================================================
-- PROGRAM EXECUTION HANDLERS
--============================================================================

local MAX_PROGRAM_LENGTH = 2000

-- Helper to send full interpreter state (includes static data - use on program load)
local function sendInterpreterState(player, interpreterTarget)
	local interp, golem
	if interpreterTarget.type == "golem" then
		golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	-- Send full state (includes tokens/source) on program changes
	local state = interp:getState()

	-- Add golem-specific info if viewing golem
	if golem then
		state.golemId = interpreterTarget.golemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.programSource = table.concat(interp.tokens or {}, " ")
		state.isGolem = true
	end

	stateUpdateEvent:FireClient(player, state)
end

-- Helper to send dynamic-only state (use in tick loop - much smaller payload)
local function sendDynamicState(player, interp, golem, viewingGolemId)
	local state = interp:getDynamicState()

	-- Add golem-specific info if viewing golem
	if golem then
		state.golemId = viewingGolemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.isGolem = true
		-- Note: NOT sending programSource here - it's in static state
	end

	return state
end

runProgramEvent.OnServerEvent:Connect(function(player, source, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
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

	interp.lastActionTime = tick()
	if interpreterTarget.type == "player" and player.Character then
		interp.character = player.Character
	end

	if interp:load(source) then
		interp.lastProgram = source
	end

	-- Always start running
	interp.paused = false

	sendInterpreterState(player, interpreterTarget)
end)

pauseProgramEvent.OnServerEvent:Connect(function(player, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	interp.paused = not interp.paused
	if interp.paused and interp.stopWalking then
		interp.stopWalking()
	elseif not interp.paused and interp.status == "PAUSED" then
		interp.status = "RUNNING"
	end

	sendInterpreterState(player, interpreterTarget)
end)

stepProgramEvent.OnServerEvent:Connect(function(player, source, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	if interpreterTarget.type == "player" and player.Character then
		interp.character = player.Character
	end

	-- If interpreter is idle/done, load the program first
	if interp.status == "IDLE" or interp.status == "DONE" then
		if type(source) == "string" and #source > 0 then
			if interp:load(source) then
				interp.lastProgram = source
			end
		end
	end

	-- Ensure paused for stepping
	interp.paused = true

	-- Step if not in error state
	if interp.status ~= "ERROR" then
		interp:step()
	end

	sendInterpreterState(player, interpreterTarget)
end)

resetProgramEvent.OnServerEvent:Connect(function(player)
	local interp = playerInterpreters[player.UserId]
	if not interp then return end

	interp:reset()
	stateUpdateEvent:FireClient(player, interp:getState())
end)

updateWordSlotEvent.OnServerEvent:Connect(function(player, wordName, newCode, interpreterTarget)
	interpreterTarget = interpreterTarget or {type = "player"}

	local interp
	if interpreterTarget.type == "golem" then
		local golem = GolemRegistry.get(interpreterTarget.golemId)
		if not golem then return end
		interp = golem.interpreter
	else
		interp = playerInterpreters[player.UserId]
		if not interp then return end
	end

	if type(wordName) ~= "string" or #wordName == 0 then return end
	if type(newCode) ~= "string" then return end
	if #newCode > 500 then newCode = newCode:sub(1, 500) end

	local success, err = interp:updateWordSlotFromSource(wordName, newCode)
	if not success then
		interp.error = "Word error: " .. (err or "unknown")
	end

	sendInterpreterState(player, interpreterTarget)
end)

manualAttackEvent.OnServerEvent:Connect(function(player)
	if not checkRateLimit(player, "attack", 0.2) then return end

	local interp = playerInterpreters[player.UserId]
	if not interp then return end

	if player.Character then
		interp.character = player.Character
	end

	interp.output = ""
	if interp.dict and interp.dict["HIT"] then
		interp.dict["HIT"]()
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
	-- EnemyManager and GolemRegistry have their own Heartbeat loops

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
								hrp.CFrame = CFrame.new(spawnPos.x, 3, spawnPos.z)
							end
						end
					end
				end

				-- Run interpreter
				if not interp.paused and not interp.dead and (interp.status == "READY" or interp.status == "RUNNING") then
					interp:run(Config.PLAYER_TICKS_PER_UPDATE or 1, Config.PLAYER_FREE_STEPS_PER_TICK or 1)
				end

				-- Process timeouts
				SharedWords.processTimeouts(interp)

				-- Build state for client based on what they're viewing
				-- Use DYNAMIC state only (no tokens/source) to reduce bandwidth
				local viewingGolemId = playerViewingGolem[userId]
				local state
				local golem = nil

				if viewingGolemId then
					-- Player is viewing a golem - send golem interpreter state
					golem = GolemRegistry.get(viewingGolemId)
					if golem and golem.interpreter then
						state = sendDynamicState(player, golem.interpreter, golem, viewingGolemId)
					else
						-- Golem no longer exists, fall back to player state
						state = interp:getDynamicState()
						playerViewingGolem[userId] = nil
					end
				else
					-- Player is viewing their own interpreter
					state = interp:getDynamicState()
				end

				-- Add player list (always needed)
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

				-- Add TD-specific state (always needed for HUD)
				state.scrap = WaveManager.getScrap(userId)
				state.ammoInventory = interp.ammoInventory

				-- Add wave state (always needed for HUD)
				local waveState = WaveManager.getState()
				state.waveNumber = waveState.waveNumber
				state.phase = waveState.phase
				state.coreHp = waveState.coreHp
				state.coreMaxHp = waveState.coreMaxHp
				state.buildTimeRemaining = waveState.buildTimeRemaining
				state.restartTimeRemaining = waveState.restartTimeRemaining
				state.enemiesRemaining = waveState.enemiesRemaining

				-- Death countdown (player's death, not golem)
				if interp.dead and interp.deathTime then
					state.deathTimeRemaining = math.max(0, Config.RESPAWN_TIME - (tick() - interp.deathTime))
					state.dead = true
				end

				stateUpdateEvent:FireClient(player, state)
			end
		end

		-- Broadcast golem state periodically (for TD HUD golem list, not interpreter state)
		GolemRegistry.broadcastState()
	end
end)

print("Forthy: Iron Defense server initialized!")
print("Game Mode: Tower Defense")
print("Defend the Core from enemy waves!")
