local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local EntityRegistry = require(PythonTD.Modules.EntityRegistry)

local WaveManager = require(script.Parent.WaveManager)
local EnemyManager = require(script.Parent.EnemyManager)
local ScrapManager = require(script.Parent.ScrapManager)
local PlayerCombat = require(script.Parent.PlayerCombat)
local MapGenerator = require(script.Parent.maps.MapGenerator)
local PathMap = require(script.Parent.PathMap)
local Interpreters = require(script.Parent.Interpreters)

local RemoteEvents = require(script.Parent.RemoteEvents)
local PlayerManager = require(script.Parent.PlayerManager)
local UnitSpawning = require(script.Parent.UnitSpawning)
local GolemStats = require(script.Parent.GolemStats)
local BotStats = require(script.Parent.BotStats)

local MAX_PROGRAM_LENGTH = 5000
local MAX_BOT_INSTRUCTIONS = 30

local DEFAULT_PROGRAM = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]]

local deps = {
	Config = Config,
	EntityRegistry = EntityRegistry,
	attackHitEvent = RemoteEvents.attackHit,
	stateUpdateEvent = RemoteEvents.stateUpdate,
	WaveManager = nil,
	EnemyManager = nil,
	ScrapManager = nil,
	PlayerCombat = nil,
	Interpreters = nil,
}

Interpreters.init(deps)
deps.Interpreters = Interpreters

WaveManager.init(deps)
deps.WaveManager = WaveManager

EnemyManager.init(deps)
EnemyManager.setWaveManager(WaveManager)
deps.EnemyManager = EnemyManager

WaveManager.setEnemyManager(EnemyManager)

ScrapManager.init(deps)
deps.ScrapManager = ScrapManager

PlayerCombat.init(deps)
deps.PlayerCombat = PlayerCombat

PathMap.init(MapGenerator.getLayout(), MapGenerator.getCellSize())

local mapConfig = {
	core = PathMap.getCoreWorldPos(),
	playerSpawn = PathMap.getPlayerSpawn(),
	spawnGates = PathMap.getSpawnGates(),
	initialGolems = {},
	initialBots = {},
}
mapConfig.core.hp = Config.CORE_HP

UnitSpawning.init(mapConfig, Interpreters)
PlayerManager.init(deps, mapConfig, UnitSpawning, Interpreters)

WaveManager.setOnWaveStart(function(waveNumber)
	UnitSpawning.spawnForWave(waveNumber)
end)

WaveManager.setOnRestart(function()
	UnitSpawning.reset()
end)

EnemyManager.startUpdateLoop()
Interpreters.startUpdateLoop()

local function loadMap()
	WaveManager.createCore(mapConfig.core)
	WaveManager.createGateVisuals(mapConfig.spawnGates)
	EnemyManager.setSpawnGates(mapConfig.spawnGates)

	local worldW, worldH = PathMap.getWorldSize()
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(worldW, 4, worldH)
	floor.Position = Vector3.new(worldW / 2, Config.PLATFORM_Y - 2, worldH / 2)
	floor.Anchored = true
	floor.Material = Config.FLOOR_MATERIAL
	floor.Color = Color3.fromRGB(60, 70, 80)
	floor.Parent = workspace

	UnitSpawning.spawnForWave(1)
end

loadMap()

Players.PlayerAdded:Connect(PlayerManager.onPlayerAdded)
Players.PlayerRemoving:Connect(PlayerManager.onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerManager.onPlayerAdded, player)
end

RemoteEvents.requestState.OnServerEvent:Connect(function(player)
	Interpreters.sendFullSync(player)
end)

local function getInterpreterByPid(player, pid)
	local data = Interpreters.get(pid)
	if not data then return nil end
	if data.ownerId ~= player.UserId then return nil end
	return data.interpreter, data
end

RemoteEvents.runProgram.OnServerEvent:Connect(function(player, source, pid)
	local interp, data = getInterpreterByPid(player, pid)
	if not interp then return end

	if type(source) ~= "string" then return end
	if #source > MAX_PROGRAM_LENGTH then
		interp.error = "PROGRAM TOO LONG (max " .. MAX_PROGRAM_LENGTH .. " chars)"
		interp.status = "ERROR"
		Interpreters.sendFullSync(player)
		return
	end

	if data.type == "player" and player.Character then
		interp.character = player.Character
	end

	if interp.paused and interp.source == source then
		interp.paused = false
		if interp.runtime then
			interp.runtime:resume()
		end
	else
		if data.entity then
			data.entity.waitingForTask = false
			data.entity.currentTask = nil
			data.entity.taskQueue = {}
		end
		local loadSuccess, _, instructionCount = interp:load(source)
		if loadSuccess then
			instructionCount = instructionCount or (interp.runtime and interp.runtime.instructionCount) or 0
			if data.type == "bot" then
				if instructionCount > MAX_BOT_INSTRUCTIONS then
					interp.error = "PROGRAM TOO COMPLEX (" .. instructionCount .. "/" .. MAX_BOT_INSTRUCTIONS .. " instructions)"
					interp.status = "ERROR"
					Interpreters.sendFullSync(player)
					return
				end
			elseif data.type == "golem" and data.entity then
				local maxBytecode = interp.maxBytecode or 128
				if instructionCount > maxBytecode then
					interp.error = "NOT ENOUGH RAM (" .. instructionCount .. "/" .. maxBytecode .. " instructions)"
					interp.status = "ERROR"
					Interpreters.sendFullSync(player)
					return
				end
			end
			interp.lastProgram = source
			Interpreters.incrementGen(pid)
		end
		interp.paused = false
	end

	Interpreters.sendFullSync(player)
end)

RemoteEvents.pauseProgram.OnServerEvent:Connect(function(player, pid)
	local interp = getInterpreterByPid(player, pid)
	if not interp then return end

	interp.paused = not interp.paused

	if not interp.paused and interp.runtime then
		interp.runtime:resume()
	end

	Interpreters.sendFullSync(player)
end)

RemoteEvents.stepProgram.OnServerEvent:Connect(function(player, source, pid)
	local interp = getInterpreterByPid(player, pid)
	if not interp then return end

	if interp.status ~= "RUNNING" and interp.status ~= "PAUSED" then
		interp:load(source)
		Interpreters.incrementGen(pid)
	end

	interp.paused = true

	if interp.stepOnce then
		interp:stepOnce()
	end

	Interpreters.sendFullSync(player)
end)

RemoteEvents.resetProgram.OnServerEvent:Connect(function(player, pid)
	local interp, data = getInterpreterByPid(player, pid)
	if not interp then return end

	if data.entity then
		data.entity.waitingForTask = false
		data.entity.currentTask = nil
		data.entity.taskQueue = {}
	end

	local defaultProgram
	if data.type == "golem" then
		defaultProgram = GolemStats.DEFAULT_PROGRAM
	elseif data.type == "bot" then
		defaultProgram = BotStats.DEFAULT_PROGRAM
	else
		defaultProgram = DEFAULT_PROGRAM
	end

	interp:load(defaultProgram)
	interp.lastProgram = defaultProgram
	Interpreters.incrementGen(pid)

	Interpreters.sendFullSync(player)
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
	if interp.paused then return end

	if player.Character then
		interp.character = player.Character
	end

	if interp.gameEnv and interp.gameEnv.self and interp.gameEnv.self.fire then
		interp.gameEnv.self.fire(ammoType or 1)
	end

	RemoteEvents.stateUpdate:FireClient(player, interp:getState())
end)

RemoteEvents.golemPlaceAt.OnServerEvent:Connect(function(player, x, z)
	local count = 0
	local MIN_TURRET_DISTANCE = 10
	for _, data in pairs(Interpreters.getByType("golem")) do
		if data.ownerId == player.UserId then
			count = count + 1
		end
		if data.entity and data.entity.character then
			local hrp = data.entity.character:FindFirstChild("HumanoidRootPart") or data.entity.character.PrimaryPart
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < MIN_TURRET_DISTANCE then
					RemoteEvents.golemPlaceAt:FireClient(player, false, "Too close to another turret")
					return
				end
			end
		end
	end

	local maxTurrets = Config.MAX_TURRETS or 10
	if count >= maxTurrets then
		RemoteEvents.golemPlaceAt:FireClient(player, false, "Max turrets reached")
		return
	end

	local cost = math.floor(GolemStats.TURRET_BASE_COST * (GolemStats.TURRET_COST_MULTIPLIER ^ count))
	local scrap = WaveManager.getScrap()
	if scrap < cost then
		RemoteEvents.golemPlaceAt:FireClient(player, false, "Not enough scrap")
		return
	end

	WaveManager.removeScrap(cost)
	local pid = Interpreters.create("golem", player.UserId, x, z)
	if pid then
		RemoteEvents.golemPlaceAt:FireClient(player, true, {pid = pid})
		Interpreters.sendFullSync(player)
	else
		WaveManager.addScrap(cost)
		RemoteEvents.golemPlaceAt:FireClient(player, false, "Failed to create turret")
	end
end)

RemoteEvents.golemSell.OnServerEvent:Connect(function(player, pid)
	local data = Interpreters.get(pid)
	if not data or data.ownerId ~= player.UserId or data.type ~= "golem" then return end

	local tier = data.entity and data.entity.tier or 1
	local baseCost = GolemStats.BASE.cost
	local refund = math.floor(baseCost * 0.5 * tier)

	Interpreters.destroy(pid)
	WaveManager.addScrap(refund)
	Interpreters.sendFullSync(player)
end)

RemoteEvents.golemUpgrade.OnServerEvent:Connect(function(player, pid, upgradeType)
	local data = Interpreters.get(pid)
	if not data or data.ownerId ~= player.UserId then return end

	local success, result
	if upgradeType == "cpu" then
		success, result = Interpreters.upgradeCPU(pid)
	elseif upgradeType == "ram" then
		success, result = Interpreters.upgradeRAM(pid)
	end

	RemoteEvents.golemUpgrade:FireClient(player, success, result)
	Interpreters.sendFullSync(player)
end)

RemoteEvents.botBuild.OnServerEvent:Connect(function(player, x, z)
	local count = 0
	for _, data in pairs(Interpreters.getByType("bot")) do
		if data.ownerId == player.UserId then
			count = count + 1
		end
	end

	local maxBots = Config.MAX_BOTS or 4
	if count >= maxBots then
		RemoteEvents.botBuild:FireClient(player, false, "Max bots reached")
		return
	end

	local cost = math.floor(BotStats.BOT_BASE_COST * (BotStats.BOT_COST_MULTIPLIER ^ count))
	local scrap = WaveManager.getScrap()
	if scrap < cost then
		RemoteEvents.botBuild:FireClient(player, false, "Not enough scrap")
		return
	end

	WaveManager.removeScrap(cost)
	local pid = Interpreters.create("bot", player.UserId, x, z)
	if pid then
		RemoteEvents.botBuild:FireClient(player, true, {pid = pid})
		Interpreters.sendFullSync(player)
	else
		WaveManager.addScrap(cost)
		RemoteEvents.botBuild:FireClient(player, false, "Failed to create bot")
	end
end)

RemoteEvents.botSell.OnServerEvent:Connect(function(player, pid)
	local data = Interpreters.get(pid)
	if not data or data.ownerId ~= player.UserId or data.type ~= "bot" then return end

	local refund = math.floor(BotStats.BASE.cost * 0.5)

	Interpreters.destroy(pid)
	WaveManager.addScrap(refund)
	Interpreters.sendFullSync(player)
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

				if not interp.paused and (interp.status == "READY" or interp.status == "RUNNING") then
					interp:run(interp.cpuHz or 2)
				end

				PlayerManager.updateScrap(interp, player, ScrapManager, WaveManager)

				local gameState = PlayerManager.buildGameState(userId, interp)
				RemoteEvents.stateUpdate:FireClient(player, gameState)
			end
		end

		Interpreters.broadcastAll()
	end
end)
