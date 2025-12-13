local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local EntityRegistry = require(PythonTD.Modules.EntityRegistry)
local Interpreter = require(PythonTD.Interpreter)
local Python = require(PythonTD.Python)

local PlayerManager = {}

PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

local interpreters = {}
local nextPlayerId = 1
local viewingGolem = {}
local viewingBot = {}
local rateLimits = {}

local deps = nil
local arenaMap = nil
local unitSpawning = nil

local DEFAULT_PROGRAM = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]]

function PlayerManager.init(dependencies, map, spawning)
	deps = dependencies
	arenaMap = map
	unitSpawning = spawning
end

function PlayerManager.get(userId)
	return interpreters[userId]
end

function PlayerManager.getAll()
	return interpreters
end

function PlayerManager.getViewingGolem(userId)
	return viewingGolem[userId]
end

function PlayerManager.setViewingGolem(userId, golemId)
	viewingGolem[userId] = golemId
	if golemId then
		viewingBot[userId] = nil
	end
end

function PlayerManager.getViewingBot(userId)
	return viewingBot[userId]
end

function PlayerManager.setViewingBot(userId, botId)
	viewingBot[userId] = botId
	if botId then
		viewingGolem[userId] = nil
	end
end

function PlayerManager.clearViewing(userId)
	viewingGolem[userId] = nil
	viewingBot[userId] = nil
end

function PlayerManager.checkRateLimit(player, action, cooldown)
	local key = player.UserId .. "_" .. action
	local now = tick()
	if rateLimits[key] and now - rateLimits[key] < cooldown then
		return false
	end
	rateLimits[key] = now
	return true
end

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

local function onCharacterAdded(player, playerId, character)
	setPlayerCollisionGroup(character)

	local interp = Interpreter.new(player, false, deps)
	interp.character = character
	interp.playerId = playerId
	interp.playerName = player.Name
	interp.ammoInventory = Config.STARTING_AMMO or 100
	interp.scrapInventory = 0
	interp.maxCapacity = 500

	local gameEnv = Python.createPlayerEnvironment(player, interp, deps)
	interp:setGameEnvironment(gameEnv)

	interp:load(DEFAULT_PROGRAM)
	interp.lastProgram = DEFAULT_PROGRAM

	EntityRegistry.register(interp)
	interpreters[player.UserId] = interp

	task.defer(function()
		local spawnPos = arenaMap.playerSpawn
		if spawnPos and character and character.Parent then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local angle = spawnPos.facingAngle or 0
				hrp.CFrame = CFrame.new(spawnPos.x, Config.PLATFORM_Y + 3, spawnPos.z) * CFrame.Angles(0, math.rad(angle), 0)
			end
		end
	end)

	deps.stateUpdateEvent:FireClient(player, interp:getState())
end

function PlayerManager.onPlayerAdded(player)
	local playerId = nextPlayerId
	nextPlayerId = nextPlayerId + 1

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, playerId, character)
	end)

	if player.Character then
		onCharacterAdded(player, playerId, player.Character)
	end

	if unitSpawning then
		local waveState = deps.WaveManager.getState()
		local currentWave = waveState.waveNumber or 0
		if currentWave >= 1 then
			unitSpawning.spawnForPlayer(player, currentWave)
			deps.GolemRegistry.broadcastState()
			deps.BotRegistry.broadcastState()
		end
	end
end

function PlayerManager.onPlayerRemoving(player)
	local userId = player.UserId

	local interp = interpreters[userId]
	if interp then
		EntityRegistry.unregister(interp.id)
		interpreters[userId] = nil
	end

	if unitSpawning then
		unitSpawning.removePlayerUnits(userId)
	end

	deps.GolemRegistry.broadcastState()
	deps.BotRegistry.broadcastState()
end

function PlayerManager.updateDeath(interp)
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

			local spawnPos = arenaMap.playerSpawn
			if spawnPos then
				local hrp = interp.character:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.CFrame = CFrame.new(spawnPos.x, Config.PLATFORM_Y + 3, spawnPos.z)
				end
			end
		end
	end
end

function PlayerManager.updateScrap(interp, player, ScrapManager, WaveManager)
	if interp.dead or not player.Character then return end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local px, pz = hrp.Position.X, hrp.Position.Z

	local scrapsInRange = ScrapManager.findInRange(px, pz, 5)
	for _, scrap in ipairs(scrapsInRange) do
		local capacity = (interp.maxCapacity or 50) - (interp.scrapInventory or 0)
		if capacity > 0 then
			ScrapManager.collect(scrap.id, interp)
		end
	end

	local coreX, coreZ = arenaMap.core.x, arenaMap.core.z
	local distToCore = math.sqrt((px - coreX)^2 + (pz - coreZ)^2)
	if distToCore <= 10 and (interp.scrapInventory or 0) > 0 then
		WaveManager.addScrap(interp.scrapInventory)
		interp.scrapInventory = 0
	end
end

function PlayerManager.buildClientState(userId, interp)
	local state

	local golemId = viewingGolem[userId]
	local botId = viewingBot[userId]

	if golemId then
		local golem = deps.GolemRegistry.get(golemId)
		if golem and golem.interpreter then
			state = golem.interpreter:getDynamicState()
			state.golemId = golemId
			state.spotId = golem.spotId
			state.typeName = golem.typeData and golem.typeData.name
			state.isGolem = true
			state.source = golem.interpreter.source
		else
			state = interp:getDynamicState()
			state.source = interp.source
			viewingGolem[userId] = nil
		end
	elseif botId then
		local bot = deps.BotRegistry.get(botId)
		if bot and bot.interpreter then
			state = bot.interpreter:getDynamicState()
			state.botId = botId
			state.spotId = bot.spotId
			state.isBot = true
			state.source = bot.interpreter.source
		else
			state = interp:getDynamicState()
			state.source = interp.source
			viewingBot[userId] = nil
		end
	else
		state = interp:getDynamicState()
		state.source = interp.source
	end

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

	state.scrap = deps.WaveManager.getScrap()
	state.ammoInventory = interp.ammoInventory
	state.scrapInventory = interp.scrapInventory or 0
	state.maxCapacity = interp.maxCapacity or 50

	local waveState = deps.WaveManager.getState()
	state.waveNumber = waveState.waveNumber
	state.phase = waveState.phase
	state.coreHp = waveState.coreHp
	state.coreMaxHp = waveState.coreMaxHp
	state.buildTimeRemaining = waveState.buildTimeRemaining
	state.restartTimeRemaining = waveState.restartTimeRemaining
	state.enemiesRemaining = waveState.enemiesRemaining

	state.enemyMinimap = deps.EnemyManager.getMinimapData()
	state.pathLength = deps.EnemyManager.getPathLength()

	local nextWavePreview = deps.WaveManager.getWavePreview()
	local nextWaveSummary = {}
	for _, typeName in ipairs(nextWavePreview) do
		nextWaveSummary[typeName] = (nextWaveSummary[typeName] or 0) + 1
	end
	state.nextWavePreview = nextWaveSummary
	state.nextWaveNumber = waveState.waveNumber + 1

	if interp.dead and interp.deathTime then
		state.deathTimeRemaining = math.max(0, Config.RESPAWN_TIME - (tick() - interp.deathTime))
		state.dead = true
	end

	return state
end

return PlayerManager
