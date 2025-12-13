local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local EntityRegistry = require(PythonTD.Modules.EntityRegistry)

local WaveManager = require(script.Parent.WaveManager)
local EnemyManager = require(script.Parent.EnemyManager)
local GolemRegistry = require(script.Parent.GolemRegistry)
local ScrapManager = require(script.Parent.ScrapManager)
local BotRegistry = require(script.Parent.BotRegistry)
local PlayerCombat = require(script.Parent.PlayerCombat)
local ArenaMap = require(script.Parent.maps.Arena)

local RemoteEvents = require(script.Parent.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local UnitSpawning = require(script.Parent.UnitSpawning)

local MAX_PROGRAM_LENGTH = 5000
local MAX_BOT_INSTRUCTIONS = 30

local deps = {
	Config = Config,
	EntityRegistry = EntityRegistry,
	attackHitEvent = RemoteEvents.attackHit,
	playerHurtEvent = RemoteEvents.playerHurt,
	beepEvent = RemoteEvents.beep,
	playAnimationEvent = RemoteEvents.playAnimation,
	stateUpdateEvent = RemoteEvents.stateUpdate,
	WaveManager = nil,
	EnemyManager = nil,
	GolemRegistry = nil,
	ScrapManager = nil,
	BotRegistry = nil,
	PlayerCombat = nil,
}

WaveManager.init(deps)
deps.WaveManager = WaveManager

EnemyManager.init(deps)
EnemyManager.setWaveManager(WaveManager)
deps.EnemyManager = EnemyManager

GolemRegistry.init(deps, require(PythonTD.Interpreter))
GolemRegistry.setWaveManager(WaveManager)
GolemRegistry.setEnemyManager(EnemyManager)
deps.GolemRegistry = GolemRegistry

WaveManager.setEnemyManager(EnemyManager)
WaveManager.setGolemRegistry(GolemRegistry)

ScrapManager.init(deps)
deps.ScrapManager = ScrapManager

BotRegistry.init(deps, require(PythonTD.Interpreter))
BotRegistry.setWaveManager(WaveManager)
deps.BotRegistry = BotRegistry

PlayerCombat.init(deps)
deps.PlayerCombat = PlayerCombat

UnitSpawning.init(GolemRegistry, BotRegistry, ArenaMap)
PlayerManager.init(deps, ArenaMap, UnitSpawning)

WaveManager.setOnWaveStart(function(waveNumber)
	UnitSpawning.spawnForWave(waveNumber)
end)

WaveManager.setOnRestart(function()
	UnitSpawning.reset()
end)

local golemRegisterViewerEvent, golemUnregisterViewerEvent = GolemRegistry.getViewerEvents()

golemRegisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
	PlayerManager.setViewingGolem(player.UserId, golemId)

	local golem = GolemRegistry.get(golemId)
	if golem and golem.interpreter then
		local state = golem.interpreter:getState()
		state.golemId = golemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.source = golem.interpreter.source
		state.isGolem = true
		RemoteEvents.stateUpdate:FireClient(player, state)
	end
end)

golemUnregisterViewerEvent.OnServerEvent:Connect(function(player)
	PlayerManager.clearViewing(player.UserId)
end)

local botRegisterViewerEvent, botUnregisterViewerEvent = BotRegistry.getViewerEvents()

botRegisterViewerEvent.OnServerEvent:Connect(function(player, botId)
	PlayerManager.setViewingBot(player.UserId, botId)

	local bot = BotRegistry.get(botId)
	if bot and bot.interpreter then
		local state = bot.interpreter:getState()
		state.botId = botId
		state.spotId = bot.spotId
		state.source = bot.interpreter.source
		state.isBot = true
		RemoteEvents.stateUpdate:FireClient(player, state)
	end
end)

botUnregisterViewerEvent.OnServerEvent:Connect(function(player)
	PlayerManager.clearViewing(player.UserId)
end)

EnemyManager.startUpdateLoop()
GolemRegistry.startUpdateLoop()
ScrapManager.startUpdateLoop()
BotRegistry.startUpdateLoop()

local function loadArenaMap()
	WaveManager.createCore(ArenaMap.core)
	EnemyManager.setSpawnGates(ArenaMap.spawnGates)
	if ArenaMap.enemyPath then
		EnemyManager.setEnemyPath(ArenaMap.enemyPath)
	end
	WaveManager.createGateVisuals(ArenaMap.spawnGates)
	GolemRegistry.setMapData(ArenaMap)

	local floorSize = ArenaMap.width * Config.CELL_SIZE
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(floorSize, 4, floorSize)
	floor.Position = Vector3.new(floorSize / 2, Config.PLATFORM_Y - 2, floorSize / 2)
	floor.Anchored = true
	floor.Material = Config.FLOOR_MATERIAL
	floor.Color = Color3.fromRGB(60, 70, 80)
	floor.Parent = workspace

	GolemRegistry.createZoneVisuals()
	UnitSpawning.spawnForWave(1)
end

loadArenaMap()

Players.PlayerAdded:Connect(PlayerManager.onPlayerAdded)
Players.PlayerRemoving:Connect(PlayerManager.onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerManager.onPlayerAdded, player)
end

RemoteEvents.requestState.OnServerEvent:Connect(function(player)
	GolemRegistry.sendStateToPlayer(player)
	BotRegistry.sendStateToPlayer(player)

	local interp = PlayerManager.get(player.UserId)
	if interp then
		local state = interp:getState()
		state.source = interp.source
		RemoteEvents.stateUpdate:FireClient(player, state)
	end
end)

local function getTargetInterpreter(player, target)
	target = target or { type = "player" }

	if target.type == "golem" then
		local golem = GolemRegistry.get(target.golemId)
		return golem and golem.interpreter, golem
	elseif target.type == "bot" then
		local bot = BotRegistry.get(target.botId)
		return bot and bot.interpreter, nil, bot
	else
		return PlayerManager.get(player.UserId)
	end
end

local function sendInterpreterState(player, target)
	local interp, golem, bot = getTargetInterpreter(player, target)
	if not interp then return end

	local state = interp:getState()
	state.source = interp.source

	if golem then
		state.golemId = target.golemId
		state.spotId = golem.spotId
		state.typeName = golem.typeData and golem.typeData.name
		state.isGolem = true
	end

	if bot then
		state.botId = target.botId
		state.spotId = bot.spotId
		state.isBot = true
	end

	RemoteEvents.stateUpdate:FireClient(player, state)
end

RemoteEvents.runProgram.OnServerEvent:Connect(function(player, source, target)
	target = target or { type = "player" }

	local interp, golem = getTargetInterpreter(player, target)
	if not interp then return end

	if type(source) ~= "string" then return end
	if #source > MAX_PROGRAM_LENGTH then
		interp.error = "PROGRAM TOO LONG (max " .. MAX_PROGRAM_LENGTH .. " chars)"
		interp.status = "ERROR"
		sendInterpreterState(player, target)
		return
	end

	if target.type == "player" and player.Character then
		interp.character = player.Character
	end

	if interp.paused and interp.source == source then
		interp.paused = false
	else
		local loadSuccess, _, instructionCount = interp:load(source)
		if loadSuccess then
			instructionCount = instructionCount or (interp.runtime and interp.runtime.instructionCount) or 0
			if target.type == "bot" then
				if instructionCount > MAX_BOT_INSTRUCTIONS then
					interp.error = "PROGRAM TOO COMPLEX (" .. instructionCount .. "/" .. MAX_BOT_INSTRUCTIONS .. " instructions)"
					interp.status = "ERROR"
					sendInterpreterState(player, target)
					return
				end
			elseif target.type == "golem" then
				if golem then
					local maxBytecode = GolemRegistry.getMaxBytecode(golem.tier)
					if instructionCount > maxBytecode then
						interp.error = "NOT ENOUGH RAM (" .. instructionCount .. "/" .. maxBytecode .. " instructions) - Upgrade for more!"
						interp.status = "ERROR"
						sendInterpreterState(player, target)
						return
					end
				end
			end
			interp.lastProgram = source
		end
		interp.paused = false
	end

	sendInterpreterState(player, target)
end)

RemoteEvents.pauseProgram.OnServerEvent:Connect(function(player, target)
	local interp = getTargetInterpreter(player, target)
	if not interp then return end

	interp.paused = not interp.paused
	sendInterpreterState(player, target)
end)

RemoteEvents.stepProgram.OnServerEvent:Connect(function(player, source, target)
	local interp = getTargetInterpreter(player, target)
	if not interp then return end

	if interp.status ~= "RUNNING" and interp.status ~= "PAUSED" then
		interp:load(source)
	end

	interp.paused = true

	if interp.stepOnce then
		interp:stepOnce()
	end

	sendInterpreterState(player, target)
end)

RemoteEvents.resetProgram.OnServerEvent:Connect(function(player)
	local interp = PlayerManager.get(player.UserId)
	if not interp then return end

	interp:reset()
	RemoteEvents.stateUpdate:FireClient(player, interp:getState())
end)

RemoteEvents.manualAttack.OnServerEvent:Connect(function(player)
	if not PlayerManager.checkRateLimit(player, "attack", 0.2) then return end

	local interp = PlayerManager.get(player.UserId)
	if not interp then return end

	if player.Character then
		interp.character = player.Character
	end

	if interp.gameEnv and interp.gameEnv.hit then
		interp.gameEnv.hit()
	end

	RemoteEvents.stateUpdate:FireClient(player, interp:getState())
end)

RemoteEvents.playerMoveComplete.OnServerEvent:Connect(function(player)
	local interp = PlayerManager.get(player.UserId)
	if interp and interp.runtime and interp.runtime.vm then
		interp.runtime.vm:unblock()
	end
end)

RemoteEvents.playerFire.OnServerEvent:Connect(function(player, ammoType)
	if not PlayerManager.checkRateLimit(player, "fire", 0.15) then return end

	local interp = PlayerManager.get(player.UserId)
	if not interp then return end

	if player.Character then
		interp.character = player.Character
	end

	if interp.gameEnv and interp.gameEnv.self and interp.gameEnv.self.fire then
		interp.gameEnv.self.fire(ammoType or 1)
	end

	RemoteEvents.stateUpdate:FireClient(player, interp:getState())
end)

local tickAccum = 0

RunService.Heartbeat:Connect(function(dt)
	tickAccum = tickAccum + dt

	WaveManager.update(dt)

	if tickAccum >= Config.PLAYER_TICK_RATE then
		tickAccum = 0

		for userId, interp in pairs(PlayerManager.getAll()) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				if player.Character then
					interp.character = player.Character
				end

				PlayerManager.updateDeath(interp)

				if not interp.paused and not interp.dead and (interp.status == "READY" or interp.status == "RUNNING") then
					interp:run(Config.PLAYER_TICKS_PER_UPDATE or 1)
				end

				PlayerManager.updateScrap(interp, player, ScrapManager, WaveManager)

				local state = PlayerManager.buildClientState(userId, interp)
				RemoteEvents.stateUpdate:FireClient(player, state)
			end
		end

		GolemRegistry.broadcastState()
	end
end)
