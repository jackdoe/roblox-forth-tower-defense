local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local InterpreterModule = require(PythonTD.Interpreter)
local Python = require(PythonTD.Python)

local GolemModel = require(script.Parent.GolemModel)
local BotModel = require(script.Parent.BotModel)
local GolemStats = require(script.Parent.GolemStats)
local BotStats = require(script.Parent.BotStats)

local Interpreters = {}

local interpreters = {}
local deps = nil
local syncEvent = nil

local lastSentGen = {}
local tickCount = 0
local KEYFRAME_INTERVAL = 100
local nextPid = 1

function Interpreters.init(dependencies)
	deps = dependencies

	syncEvent = Instance.new("RemoteEvent")
	syncEvent.Name = "InterpreterSync"
	syncEvent.Parent = PythonTD
end

function Interpreters.create(interpType, ownerId, x, z)
	local pid = tostring(nextPid)
	nextPid = nextPid + 1

	local character = nil
	local entity = nil
	local defaultProgram = nil
	local cpuHz = 10
	local maxBytecode = 128
	local selfType = "Entity"
	local name = interpType .. ".py"

	if interpType == "golem" then
		name = "T" .. pid .. ".py"

		character = GolemModel.create(x, z)
		selfType = "Turret"
		cpuHz = GolemStats.UpgradeTiers[1].cpuHz
		maxBytecode = GolemStats.RAMTiers[1].maxBytecode
		defaultProgram = GolemStats.DEFAULT_PROGRAM

		entity = {
			tier = 1,
			ramTier = 1,
			character = character,
			facingAngle = 0,
			targetAngle = 0,
			name = name,
		}

		character:SetAttribute("GolemId", pid)

	elseif interpType == "bot" then
		name = "B" .. pid .. ".py"

		character = BotModel.create(x, z)
		selfType = "Bot"
		cpuHz = BotStats.UpgradeTiers[1].cpuHz
		maxBytecode = BotStats.RAMTiers[1].maxBytecode
		defaultProgram = BotStats.DEFAULT_PROGRAM

		entity = {
			tier = 1,
			ramTier = 1,
			character = character,
			scrapInventory = 0,
			maxCapacity = BotStats.UpgradeTiers[1].maxCapacity,
			isMoving = false,
			facingAngle = 0,
			name = name,
		}

		character:SetAttribute("BotId", pid)
	end

	local interp = InterpreterModule.new(nil, interpType ~= "player", deps)
	interp.character = character
	interp.selfType = selfType
	interp.cpuHz = cpuHz
	interp.maxBytecode = maxBytecode

	if interpType == "golem" then
		interp.isGolem = true
		interp.ammo = GolemStats.BASE.maxAmmo
		interp.maxAmmo = GolemStats.BASE.maxAmmo
		interp.range = GolemStats.BASE.range
		interp.dynamicRange = GolemStats.BASE.range
		interp.lastFireTime = 0
		interp.target = nil
		GolemModel.createBillboard(entity)
	elseif interpType == "bot" then
		interp.isBot = true
		BotModel.createBillboard(entity)
	end

	local gameEnv = nil
	local registries = {
		EnemyManager = deps.EnemyManager,
		WaveManager = deps.WaveManager,
		ScrapManager = deps.ScrapManager,
		GolemStats = GolemStats,
		GolemModel = GolemModel,
	}
	if interpType == "golem" then
		gameEnv = Python.createGolemEnvironment(entity, registries)
	elseif interpType == "bot" then
		gameEnv = Python.createBotEnvironment(entity, registries)
	end

	if gameEnv then
		interp:setGameEnvironment(gameEnv)
	end

	if defaultProgram then
		interp:load(defaultProgram)
		interp.lastProgram = defaultProgram
	end

	if entity then
		entity.interpreter = interp
		entity.id = pid
		entity.pid = pid
	end

	interpreters[pid] = {
		pid = pid,
		type = interpType,
		ownerId = ownerId,
		name = name,
		interpreter = interp,
		gen = 1,
		entity = entity,
	}

	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = pid,
			isGolem = interpType == "golem",
			isBot = interpType == "bot",
			character = character,
		})
	end

	return pid
end

function Interpreters.createPlayer(ownerId, character, playerId)
	local pid = tostring(nextPid)
	nextPid = nextPid + 1

	local interp = InterpreterModule.new(nil, false, deps)
	interp.character = character
	interp.selfType = "Player"
	interp.cpuHz = 10
	interp.maxBytecode = 128
	interp.isPlayer = true
	interp.playerId = playerId

	local defaultProgram = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]]

	local gameEnv = Python.createPlayerEnvironment({UserId = ownerId}, interp, deps)
	interp:setGameEnvironment(gameEnv)
	interp:load(defaultProgram)
	interp.lastProgram = defaultProgram

	interpreters[pid] = {
		pid = pid,
		type = "player",
		ownerId = ownerId,
		name = "shoot.py",
		interpreter = interp,
		gen = 1,
		entity = nil,
	}

	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = pid,
			isPlayer = true,
			character = character,
		})
	end

	return pid
end

function Interpreters.destroy(pid)
	local data = interpreters[pid]
	if not data then return end

	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(pid)
	end

	if data.entity and data.entity.character then
		data.entity.character:Destroy()
	end

	interpreters[pid] = nil
end

function Interpreters.destroyByOwner(ownerId)
	local toDestroy = {}
	for pid, data in pairs(interpreters) do
		if data.ownerId == ownerId and data.type ~= "player" then
			table.insert(toDestroy, pid)
		end
	end
	for _, pid in ipairs(toDestroy) do
		Interpreters.destroy(pid)
	end
end

function Interpreters.destroyAllUnits()
	local toDestroy = {}
	for pid, data in pairs(interpreters) do
		if data.type ~= "player" then
			table.insert(toDestroy, pid)
		end
	end
	for _, pid in ipairs(toDestroy) do
		Interpreters.destroy(pid)
	end
end

function Interpreters.destroyPlayer(ownerId)
	for pid, data in pairs(interpreters) do
		if data.ownerId == ownerId and data.type == "player" then
			Interpreters.destroy(pid)
			return
		end
	end
end

function Interpreters.get(pid)
	return interpreters[pid]
end

function Interpreters.getInterpreter(pid)
	local data = interpreters[pid]
	return data and data.interpreter
end

function Interpreters.getEntity(pid)
	local data = interpreters[pid]
	return data and data.entity
end

function Interpreters.getByOwner(ownerId)
	local result = {}
	for pid, data in pairs(interpreters) do
		if data.ownerId == ownerId then
			result[pid] = data
		end
	end
	return result
end

function Interpreters.getAll()
	return interpreters
end

function Interpreters.getByType(interpType)
	local result = {}
	for pid, data in pairs(interpreters) do
		if data.type == interpType then
			result[pid] = data
		end
	end
	return result
end

function Interpreters.upgradeCPU(pid)
	local data = interpreters[pid]
	if not data or not data.entity then return false, "Not found" end

	local entity = data.entity
	local currentTier = entity.tier or 1

	local tiers = data.type == "golem" and GolemStats.UpgradeTiers or BotStats.UpgradeTiers
	local maxTier = data.type == "golem" and GolemStats.MAX_CPU_TIER or BotStats.MAX_CPU_TIER

	if currentTier >= maxTier then return false, "Max tier" end

	local nextTierData = tiers[currentTier + 1]
	if not nextTierData then return false, "Invalid tier" end

	local cost = nextTierData.upgradeCost
	if deps.WaveManager then
		local scrap = deps.WaveManager.getScrap()
		if scrap < cost then return false, "Not enough scrap" end
		deps.WaveManager.removeScrap(cost)
	end

	entity.tier = currentTier + 1
	data.interpreter.cpuHz = nextTierData.cpuHz

	if data.type == "golem" then
		GolemModel.applyVisualUpgrade(entity)
	end

	data.gen = data.gen + 1
	return true, {tier = entity.tier}
end

function Interpreters.upgradeRAM(pid)
	local data = interpreters[pid]
	if not data or not data.entity then return false, "Not found" end

	local entity = data.entity
	local currentTier = entity.ramTier or 1

	local tiers = data.type == "golem" and GolemStats.RAMTiers or BotStats.RAMTiers
	local maxTier = data.type == "golem" and GolemStats.MAX_RAM_TIER or BotStats.MAX_RAM_TIER

	if currentTier >= maxTier then return false, "Max RAM" end

	local nextTierData = tiers[currentTier + 1]
	if not nextTierData then return false, "Invalid tier" end

	local cost = nextTierData.upgradeCost
	if deps.WaveManager then
		local scrap = deps.WaveManager.getScrap()
		if scrap < cost then return false, "Not enough scrap" end
		deps.WaveManager.removeScrap(cost)
	end

	entity.ramTier = currentTier + 1
	data.interpreter.maxBytecode = nextTierData.maxBytecode

	if data.type == "golem" then
		GolemModel.applyColorUpgrade(entity)
	end

	data.gen = data.gen + 1
	return true, {ramTier = entity.ramTier, maxBytecode = nextTierData.maxBytecode}
end

function Interpreters.run(pid, ticks, freeSteps)
	local data = interpreters[pid]
	if not data then return end

	local interp = data.interpreter
	if interp.paused then return end

	if interp.status == "DONE" then
		interp:reset()
		if interp.lastProgram then
			interp:load(interp.lastProgram)
		end
	end

	if interp.status == "READY" or interp.status == "RUNNING" then
		interp:run(ticks, freeSteps)
	end
end

function Interpreters.getState(pid, fullState)
	local data = interpreters[pid]
	if not data then return nil end

	local interp = data.interpreter

	local state = {
		pid = data.pid,
		type = data.type,
		name = data.name,

		status = interp.status,
		error = interp.error,
		paused = interp.paused,

		ip = nil,
		variables = interp:getDynamicState().variables,

		ammo = interp.ammo,
		maxAmmo = interp.maxAmmo,
		dynamicRange = interp.dynamicRange,
		cpuHz = interp.cpuHz,
		maxBytecode = interp.maxBytecode,
	}

	local runtimeState = interp.runtime and interp.runtime:getState()
	if runtimeState and runtimeState.vm then
		state.ip = runtimeState.vm.ip
	end

	if fullState then
		state.source = interp.source
		state.bytecode = runtimeState and runtimeState.bytecode
		state.gen = data.gen
	end

	if data.entity then
		local e = data.entity
		if data.type == "golem" then
			state.tier = e.tier
			state.ramTier = e.ramTier
		elseif data.type == "bot" then
			state.tier = e.tier
			state.scrapInventory = e.scrapInventory
			state.maxCapacity = e.maxCapacity
		end
	end

	return state
end

function Interpreters.buildSyncPayload(playerId)
	tickCount = tickCount + 1
	local isKeyframe = (tickCount % KEYFRAME_INTERVAL) == 0

	if not lastSentGen[playerId] then
		lastSentGen[playerId] = {}
	end
	local playerCache = lastSentGen[playerId]

	local payload = {}

	for pid, data in pairs(interpreters) do
		if data.ownerId == playerId then
			local needsFull = isKeyframe or (playerCache[pid] ~= data.gen)
			local state = Interpreters.getState(pid, needsFull)

			if needsFull then
				playerCache[pid] = data.gen
			end

			payload[pid] = state
		end
	end

	return payload
end

function Interpreters.broadcastAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local payload = Interpreters.buildSyncPayload(player.UserId)
		syncEvent:FireClient(player, payload)
	end
end

function Interpreters.sendFullSync(player)
	local playerId = player.UserId
	if not lastSentGen[playerId] then
		lastSentGen[playerId] = {}
	end

	local payload = {}
	for pid, data in pairs(interpreters) do
		if data.ownerId == playerId then
			payload[pid] = Interpreters.getState(pid, true)
			lastSentGen[playerId][pid] = data.gen
		end
	end

	syncEvent:FireClient(player, payload)
end

function Interpreters.clearPlayerCache(playerId)
	lastSentGen[playerId] = nil
end

function Interpreters.incrementGen(pid)
	local data = interpreters[pid]
	if data then
		data.gen = data.gen + 1
	end
end

function Interpreters.updateName(pid, name)
	local data = interpreters[pid]
	if data then
		data.name = name
	end
end

local function collectScrap(entity)
	local character = entity.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end

	local ScrapManager = deps.ScrapManager
	if not ScrapManager then return 0 end

	local x, z = hrp.Position.X, hrp.Position.Z
	local pickupRange = BotStats.BASE.pickupRange or 5
	local piecesCollected = 0

	while (entity.scrapInventory or 0) < (entity.maxCapacity or 3) do
		local scrap = ScrapManager.findNearest(x, z, pickupRange)
		if not scrap or not scrap.id then break end

		if ScrapManager.collect(scrap.id) then
			entity.scrapInventory = (entity.scrapInventory or 0) + 1
			piecesCollected = piecesCollected + 1
		else
			break
		end
	end

	return piecesCollected
end

local function executeBotTask(data, dt)
	local entity = data.entity
	local task = entity.currentTask
	if not task then return "DONE" end

	local character = entity.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return "FAILED" end

	local GROUND_Y = BotStats.GROUND_Y

	if task.type == "COLLECT" then
		local ScrapManager = deps.ScrapManager
		if not ScrapManager then
			task.result = false
			return "FAILED"
		end

		local capacity = entity.maxCapacity or 3
		if (entity.scrapInventory or 0) >= capacity then
			entity.status = "IDLE"
			task.result = true
			return "DONE"
		end

		if not task.targetX then
			local x, z, count = ScrapManager.findBestCluster(hrp.Position.X, hrp.Position.Z, 200, 20)
			if not x or count == 0 then
				entity.status = "IDLE"
				task.result = false
				return "DONE"
			end
			task.targetX = x
			task.targetZ = z
			task.collected = 0
		end

		local dx = task.targetX - hrp.Position.X
		local dz = task.targetZ - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= (BotStats.BASE.pickupRange or 8) then
			local collected = collectScrap(entity)
			task.collected = (task.collected or 0) + collected

			if (entity.scrapInventory or 0) >= capacity then
				entity.status = "IDLE"
				task.result = task.collected > 0
				return "DONE"
			end

			local nearest = ScrapManager.findNearest(hrp.Position.X, hrp.Position.Z, 50)
			if nearest and nearest.part then
				task.targetX = nearest.part.Position.X
				task.targetZ = nearest.part.Position.Z
				return "RUNNING"
			end

			entity.status = "IDLE"
			task.result = task.collected > 0
			return "DONE"
		end

		entity.moveTargetX = task.targetX
		entity.moveTargetZ = task.targetZ
		entity.isMoving = true
		entity.status = "COLLECTING"
		return "RUNNING"

	elseif task.type == "TELEPORT" then
		local targetX = task.args.x
		local targetZ = task.args.z
		if not targetX or not targetZ then return "FAILED" end

		character:PivotTo(CFrame.new(targetX, GROUND_Y + 3, targetZ))
		entity.status = "IDLE"
		task.result = true
		return "DONE"

	elseif task.type == "MOVE" then
		local targetX = task.args.x
		local targetZ = task.args.z

		local dx = targetX - hrp.Position.X
		local dz = targetZ - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= 2 then
			entity.status = "IDLE"
			entity.isMoving = false
			task.result = true
			return "DONE"
		end

		entity.moveTargetX = targetX
		entity.moveTargetZ = targetZ
		entity.isMoving = true
		entity.status = "MOVING"
		return "RUNNING"

	elseif task.type == "SHOCK" then
		local enemyId = task.args.enemyId
		local EnemyManager = deps.EnemyManager
		if not EnemyManager then return "FAILED" end

		local enemy = EnemyManager.get(enemyId)
		if not enemy or not enemy.character then return "FAILED" end

		local enemyHrp = enemy.character:FindFirstChild("HumanoidRootPart")
		if not enemyHrp then return "FAILED" end

		if not task.shockExecuted then
			local dist = (enemyHrp.Position - hrp.Position).Magnitude
			if dist > BotStats.SHOCK_RANGE then
				entity.status = "MOVING"
				local targetPos = enemyHrp.Position
				local dir = (targetPos - hrp.Position).Unit
				entity.moveTargetX = hrp.Position.X + dir.X * (dist - BotStats.SHOCK_RANGE + 1)
				entity.moveTargetZ = hrp.Position.Z + dir.Z * (dist - BotStats.SHOCK_RANGE + 1)
				entity.isMoving = true
				return "RUNNING"
			end

			EnemyManager.shock(enemyId, BotStats.SHOCK_DAMAGE, hrp.Position.X, hrp.Position.Z)
			task.shockExecuted = true
			task.stunEndTime = tick() + BotStats.SHOCK_STUN_TIME

			BotModel.createShockEffect(entity)
			entity.status = "SHOCKING"
			return "RUNNING"
		else
			entity.status = "STUNNED"
			if tick() >= task.stunEndTime then
				entity.status = "IDLE"
				return "DONE"
			end
			return "RUNNING"
		end

	elseif task.type == "EXPLODE" then
		local cargo = entity.scrapInventory or 0
		if cargo < 10 then
			entity.status = "IDLE"
			task.result = false
			return "FAILED"
		end

		local damage = cargo * 2
		local explodeRange = 15

		local EnemyManager = deps.EnemyManager
		if EnemyManager and EnemyManager.findInRange then
			local enemies = EnemyManager.findInRange(hrp.Position.X, hrp.Position.Z, explodeRange)
			for _, enemy in ipairs(enemies) do
				EnemyManager.damage(enemy.id, damage)
			end
		end

		BotModel.createExplosionEffect(entity, cargo)
		entity.scrapInventory = 0
		entity.status = "STUNNED"
		task.stunEndTime = tick() + 1.5
		task.exploded = true
		task.result = true
		return "RUNNING"
	end

	if task.exploded and task.stunEndTime then
		if tick() >= task.stunEndTime then
			entity.status = "IDLE"
			return "DONE"
		end
		return "RUNNING"
	end

	entity.status = "IDLE"
	task.result = false
	return "FAILED"
end

local function updateGolem(data, dt)
	local entity = data.entity
	local interp = data.interpreter
	local character = entity.character
	if not character or not character.Parent then return end

	if interp.target and deps.EnemyManager then
		local enemy = deps.EnemyManager.get(interp.target)
		if enemy and enemy.character then
			local enemyHrp = enemy.character:FindFirstChild("HumanoidRootPart")
			local myHrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
			if enemyHrp and myHrp then
				local dx = enemyHrp.Position.X - myHrp.Position.X
				local dz = enemyHrp.Position.Z - myHrp.Position.Z
				entity.targetAngle = math.atan2(dx, dz) + math.pi
			end
		end
	end

	local angleDiff = entity.targetAngle - entity.facingAngle
	while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
	while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
	entity.facingAngle = entity.facingAngle + angleDiff * 0.15

	local head = character:FindFirstChild("Head")
	if head then
		local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
		if hrp then
			head.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0)) *
				CFrame.Angles(0, entity.facingAngle, 0)
		end
	end
end

local function updateBot(data, dt)
	local entity = data.entity
	local character = entity.character
	if not character or not character.Parent then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	local baseY = character:GetAttribute("BaseY") or (BotStats.GROUND_Y + 2.5)
	local facingAngle = entity.facingAngle or 0

	local newX, newZ = hrp.Position.X, hrp.Position.Z

	if entity.moveTargetX and entity.moveTargetZ then
		local dx = entity.moveTargetX - hrp.Position.X
		local dz = entity.moveTargetZ - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist < 2 then
			entity.moveTargetX = nil
			entity.moveTargetZ = nil
			entity.isMoving = false
		else
			local speed = BotStats.UpgradeTiers[entity.tier or 1].speed or BotStats.BASE.speed
			local dirX = dx / dist
			local dirZ = dz / dist
			local moveAmount = math.min(speed * dt, dist)
			newX = hrp.Position.X + dirX * moveAmount
			newZ = hrp.Position.Z + dirZ * moveAmount
			facingAngle = math.atan2(-dirX, -dirZ)
			entity.facingAngle = facingAngle
		end
	end

	hrp.CFrame = CFrame.new(newX, baseY, newZ) * CFrame.Angles(0, facingAngle, 0)

	if (entity.scrapInventory or 0) < (entity.maxCapacity or 3) then
		local ScrapManager = deps.ScrapManager
		if ScrapManager then
			local scrap = ScrapManager.findNearest(newX, newZ, BotStats.BASE.pickupRange or 5)
			if scrap and scrap.id and ScrapManager.collect(scrap.id) then
				entity.scrapInventory = (entity.scrapInventory or 0) + 1
			end
		end
	end

	if not entity.currentTask and entity.taskQueue and #entity.taskQueue > 0 then
		entity.currentTask = table.remove(entity.taskQueue, 1)
	end

	if entity.currentTask then
		local taskStatus = executeBotTask(data, dt)
		if taskStatus == "DONE" or taskStatus == "FAILED" then
			local taskResult = entity.currentTask.result
			entity.currentTask = nil
			if not entity.taskQueue or #entity.taskQueue == 0 then
				entity.waitingForTask = false
				local vm = data.interpreter.runtime and data.interpreter.runtime.vm
				if vm and vm.unblock then
					vm:unblock(taskResult)
				end
			end
		end
	end

	local backpack = character:FindFirstChild("Backpack")
	if backpack then
		local scrapPile = backpack:FindFirstChild("ScrapPile")
		if scrapPile then
			local ratio = (entity.scrapInventory or 0) / (entity.maxCapacity or 50)
			if ratio > 0 then
				scrapPile.Transparency = 0
				local pileHeight = 0.2 + (ratio * 0.8)
				scrapPile.Size = Vector3.new(1.6, pileHeight, 0.6)
			else
				scrapPile.Transparency = 1
			end
		end
	end
end

function Interpreters.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		for pid, data in pairs(interpreters) do
			if data.type == "golem" and data.entity then
				local interp = data.interpreter
				if not interp.paused and (interp.status == "READY" or interp.status == "RUNNING") then
					interp:run(interp.cpuHz or 10)
				end
				updateGolem(data, dt)
				GolemModel.updateBillboard(data.entity)

			elseif data.type == "bot" and data.entity then
				local interp = data.interpreter
				if not data.entity.waitingForTask then
					if not interp.paused and (interp.status == "READY" or interp.status == "RUNNING") then
						interp:run(interp.cpuHz or 10)
					end
				end
				updateBot(data, dt)
				BotModel.updateBillboard(data.entity)
			end
		end
	end)
end

return Interpreters
