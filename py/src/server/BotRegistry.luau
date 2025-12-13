local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local BotStats = require(script.Parent.BotStats)
local BotModel = require(script.Parent.BotModel)
local Pathfinding = require(script.Parent.Pathfinding)

local BotRegistry = {}

local GROUND_Y = BotStats.GROUND_Y
local BOT_RADIUS = BotStats.BOT_RADIUS
local TURRET_RADIUS = BotStats.TURRET_RADIUS

local bots = {}
local deps = nil
local WaveManager = nil
local InterpreterModule = nil
local GameAPI = nil

local nextBotNumber = 1

local botStateEvent = nil
local botBuildEvent = nil
local botSellEvent = nil
local botRegisterViewerEvent = nil
local botUnregisterViewerEvent = nil

local function recomputeBotPath(bot, goalX, goalZ)
	local character = bot.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local startPos = Vector3.new(hrp.Position.X, GROUND_Y, hrp.Position.Z)
	local goalPos = Vector3.new(goalX, GROUND_Y, goalZ)

	return Pathfinding.computePath(startPos, goalPos, BOT_RADIUS + 1, bot.id)
end

local function getBotObstacles()
	local obstacles = {}
	for id, bot in pairs(bots) do
		if bot.character then
			local hrp = bot.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(obstacles, {
					id = id,
					x = hrp.Position.X,
					z = hrp.Position.Z,
					radius = BOT_RADIUS * 2,
				})
			end
		end
	end
	return obstacles
end

local function getTurretObstacles()
	if not deps or not deps.GolemRegistry then return {} end
	local golems = deps.GolemRegistry.getAll and deps.GolemRegistry.getAll() or {}
	local obstacles = {}
	for id, golem in pairs(golems) do
		if golem.character then
			local hrp = golem.character:FindFirstChild("HumanoidRootPart") or golem.character.PrimaryPart
			if hrp then
				table.insert(obstacles, {
					id = "turret_" .. id,
					x = hrp.Position.X,
					z = hrp.Position.Z,
					radius = TURRET_RADIUS + BOT_RADIUS,
				})
			end
		end
	end
	return obstacles
end

local function getCoreObstacle()
	if not WaveManager then return {} end
	local corePos = WaveManager.getCorePosition and WaveManager.getCorePosition()
	if not corePos then return {} end
	return {{
		id = "core",
		x = corePos.x,
		z = corePos.z,
		radius = 8,
	}}
end

function BotRegistry.init(dependencies, interpreterModule)
	deps = dependencies
	InterpreterModule = interpreterModule

	local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
	GameAPI = require(PythonTD.Python.GameAPI)

	Pathfinding.registerObstacleGetter("bots", getBotObstacles)
	Pathfinding.registerObstacleGetter("turrets", getTurretObstacles)
	Pathfinding.registerObstacleGetter("core", getCoreObstacle)

	botStateEvent = Instance.new("RemoteEvent")
	botStateEvent.Name = "BotState"
	botStateEvent.Parent = PythonTD

	botBuildEvent = Instance.new("RemoteEvent")
	botBuildEvent.Name = "BotBuild"
	botBuildEvent.Parent = PythonTD

	botSellEvent = Instance.new("RemoteEvent")
	botSellEvent.Name = "BotSell"
	botSellEvent.Parent = PythonTD

	botRegisterViewerEvent = Instance.new("RemoteEvent")
	botRegisterViewerEvent.Name = "BotRegisterViewer"
	botRegisterViewerEvent.Parent = PythonTD

	botUnregisterViewerEvent = Instance.new("RemoteEvent")
	botUnregisterViewerEvent.Name = "BotUnregisterViewer"
	botUnregisterViewerEvent.Parent = PythonTD

	botBuildEvent.OnServerEvent:Connect(function(player, x, z)
		local success, result = BotRegistry.tryBuild(player, x, z)
		botBuildEvent:FireClient(player, success, result)
	end)

	botSellEvent.OnServerEvent:Connect(function(player, botId)
		local success, result = BotRegistry.sellBot(player, botId)
		botSellEvent:FireClient(player, success, result)
	end)

	print("BotRegistry: Initialized")
end

function BotRegistry.setWaveManager(waveMgr)
	WaveManager = waveMgr
end

function BotRegistry.getViewerEvents()
	return botRegisterViewerEvent, botUnregisterViewerEvent
end

function BotRegistry.get(botId)
	return bots[botId]
end

function BotRegistry.tryBuild(player, x, z)
	local myBotCount = 0
	for _, bot in pairs(bots) do
		if bot.ownerId == player.UserId then
			myBotCount = myBotCount + 1
		end
	end

	if myBotCount >= BotStats.MAX_BOTS_PER_PLAYER then
		return false, "Max bots reached (" .. BotStats.MAX_BOTS_PER_PLAYER .. ")"
	end

	if WaveManager then
		local scrap = WaveManager.getScrap()
		if scrap < BotStats.BASE.cost then
			return false, "Not enough scrap (" .. scrap .. "/" .. BotStats.BASE.cost .. ")"
		end
		WaveManager.removeScrap(BotStats.BASE.cost)
	end

	local botId = BotRegistry.create(x, z)
	if botId then
		bots[botId].ownerId = player.UserId
		bots[botId].spotId = nextBotNumber
		nextBotNumber = nextBotNumber + 1

		print("BotRegistry: Player", player.Name, "built bot", myBotCount + 1, "/", BotStats.MAX_BOTS_PER_PLAYER)
		BotRegistry.broadcastState()
		return true, botId
	end

	return false, "Failed to create bot"
end

function BotRegistry.sellBot(player, botId)
	local bot = bots[botId]
	if not bot then
		return false, "Bot not found"
	end

	if bot.ownerId ~= player.UserId then
		return false, "You don't own this bot"
	end

	local refund = math.floor(BotStats.BASE.cost * 0.5)
	local carryingScrap = bot.scrapInventory or 0
	refund = refund + carryingScrap

	if WaveManager then
		WaveManager.addScrap(refund)
	end

	BotRegistry.destroy(botId)

	print("BotRegistry: Player", player.Name, "sold bot for", refund, "scrap")
	BotRegistry.broadcastState()

	return true, refund
end

function BotRegistry.create(x, z)
	local character = BotModel.create(x, z)
	if not character then return nil end

	local id = game:GetService("HttpService"):GenerateGUID()

	local bot = {
		id = id,
		character = character,
		spotId = nil,
		ownerId = nil,

		scrapInventory = 0,
		maxCapacity = BotStats.BASE.maxCapacity,
		speed = BotStats.BASE.speed,
		pickupRange = BotStats.BASE.pickupRange,
		transferRange = BotStats.BASE.transferRange,

		moveTargetX = nil,
		moveTargetZ = nil,
		isMoving = false,

		taskQueue = {},
		currentTask = nil,
		waitingForTask = false,

		status = "IDLE",

		interpreter = nil,

		shieldActive = false,
		shieldCooldownUntil = 0,
	}

	bots[id] = bot

	if InterpreterModule then
		bot.interpreter = InterpreterModule.new(nil, true, deps)
		bot.interpreter.character = character

		if GameAPI and GameAPI.createBotEnvironment then
			local botEnv = GameAPI.createBotEnvironment(bot, {
				BotRegistry = BotRegistry,
				ScrapManager = deps.ScrapManager,
				GolemRegistry = deps.GolemRegistry,
				EnemyManager = deps.EnemyManager,
				WaveManager = WaveManager,
			})
			bot.interpreter:setGameEnvironment(botEnv)
		end

		bot.interpreter:load(BotStats.DEFAULT_PROGRAM)
		bot.interpreter.lastProgram = BotStats.DEFAULT_PROGRAM
	end

	character:SetAttribute("BotId", id)

	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = id,
			isBot = true,
			character = character,
		})
	end

	BotModel.createBillboard(bot)

	print("BotRegistry: Created bot at", x, z)
	return id
end

function BotRegistry.issueCommand(botId, commandType, args, blocking)
	local bot = bots[botId]
	if not bot then return false end

	table.insert(bot.taskQueue, {
		type = commandType,
		args = args or {},
		startTime = tick(),
	})

	if blocking then
		bot.waitingForTask = true
	end

	return true
end

function BotRegistry.clearCommands(botId)
	local bot = bots[botId]
	if not bot then return end
	bot.taskQueue = {}
	bot.currentTask = nil
	bot.status = "IDLE"
	bot.isMoving = false
end

local function executeTask(bot, dt)
	local task = bot.currentTask
	if not task then return "DONE" end

	local character = bot.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return "FAILED" end

	if task.type == "COLLECT" then
		local scrapId = task.args.target
		local ScrapManager = deps.ScrapManager
		if not ScrapManager then return "FAILED" end

		local scrap = ScrapManager.get(scrapId)
		if not scrap or not scrap.part or not scrap.part.Parent then
			bot.status = "IDLE"
			return "FAILED"
		end

		local sPos = scrap.part.Position
		bot.finalGoalX = sPos.X
		bot.finalGoalZ = sPos.Z

		local dx = sPos.X - hrp.Position.X
		local dz = sPos.Z - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= (bot.pickupRange or 8) then
			BotRegistry.collectScrap(bot.id)
			bot.status = "IDLE"
			return "DONE"
		else
			bot.moveTargetX = sPos.X
			bot.moveTargetZ = sPos.Z
			bot.isMoving = true
			bot.status = "COLLECTING"
			return "RUNNING"
		end

	elseif task.type == "COLLECT_AT" or task.type == "COLLECT_AREA" then
		local targetX = task.args.x
		local targetZ = task.args.z
		if not targetX or not targetZ then return "FAILED" end

		bot.finalGoalX = targetX
		bot.finalGoalZ = targetZ

		if not task.path then
			local startPos = Vector3.new(hrp.Position.X, GROUND_Y, hrp.Position.Z)
			local goalPos = Vector3.new(targetX, GROUND_Y, targetZ)
			task.path = Pathfinding.computePath(startPos, goalPos, BOT_RADIUS + 1, bot.id)
			task.pathIndex = 1
		end

		local waypoint = task.path[task.pathIndex]
		if not waypoint then
			local collected = BotRegistry.collectScrap(bot.id)
			bot.status = "IDLE"
			bot.isMoving = false
			return "DONE"
		end

		local dx = waypoint.x - hrp.Position.X
		local dz = waypoint.z - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		local finalDx = targetX - hrp.Position.X
		local finalDz = targetZ - hrp.Position.Z
		local finalDist = math.sqrt(finalDx * finalDx + finalDz * finalDz)
		local pickupRange = bot.pickupRange or 20

		if finalDist <= pickupRange then
			local collected = BotRegistry.collectScrap(bot.id)
			bot.status = "IDLE"
			bot.isMoving = false
			return "DONE"
		elseif dist < 2 then
			task.pathIndex = task.pathIndex + 1
			waypoint = task.path[task.pathIndex]
			if waypoint then
				bot.moveTargetX = waypoint.x
				bot.moveTargetZ = waypoint.z
			end
			bot.isMoving = true
			bot.status = "COLLECTING"
			return "RUNNING"
		else
			bot.moveTargetX = waypoint.x
			bot.moveTargetZ = waypoint.z
			bot.isMoving = true
			bot.status = "COLLECTING"
			return "RUNNING"
		end

	elseif task.type == "SUPPLY_CORE" then
		local coreX, coreZ = 150, 150
		if WaveManager and WaveManager.getCorePosition then
			local corePos = WaveManager.getCorePosition()
			if corePos then
				coreX = corePos.x or 150
				coreZ = corePos.z or 150
			end
		end

		bot.finalGoalX = coreX
		bot.finalGoalZ = coreZ

		if not task.path then
			local startPos = Vector3.new(hrp.Position.X, GROUND_Y, hrp.Position.Z)
			local goalPos = Vector3.new(coreX, GROUND_Y, coreZ)
			task.path = Pathfinding.computePath(startPos, goalPos, BOT_RADIUS + 1, bot.id)
			task.pathIndex = 1
		end

		local waypoint = task.path[task.pathIndex]
		if not waypoint then
			BotRegistry.depositToCore(bot.id)
			bot.status = "IDLE"
			bot.isMoving = false
			return "DONE"
		end

		local dx = waypoint.x - hrp.Position.X
		local dz = waypoint.z - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		local coreDx = coreX - hrp.Position.X
		local coreDz = coreZ - hrp.Position.Z
		local coreDist = math.sqrt(coreDx * coreDx + coreDz * coreDz)

		if coreDist <= (bot.transferRange or 10) then
			BotRegistry.depositToCore(bot.id)
			bot.status = "IDLE"
			bot.isMoving = false
			return "DONE"
		elseif dist < 2 then
			task.pathIndex = task.pathIndex + 1
			waypoint = task.path[task.pathIndex]
			if waypoint then
				bot.moveTargetX = waypoint.x
				bot.moveTargetZ = waypoint.z
			end
			bot.isMoving = true
			bot.status = "DELIVERING"
			return "RUNNING"
		else
			bot.moveTargetX = waypoint.x
			bot.moveTargetZ = waypoint.z
			bot.isMoving = true
			bot.status = "DELIVERING"
			return "RUNNING"
		end

	elseif task.type == "MOVE" then
		local targetX = task.args.x
		local targetZ = task.args.z

		bot.finalGoalX = targetX
		bot.finalGoalZ = targetZ

		if not task.path then
			local startPos = Vector3.new(hrp.Position.X, GROUND_Y, hrp.Position.Z)
			local goalPos = Vector3.new(targetX, GROUND_Y, targetZ)
			task.path = Pathfinding.computePath(startPos, goalPos, BOT_RADIUS + 1, bot.id)
			task.pathIndex = 1
		end

		local waypoint = task.path[task.pathIndex]
		if not waypoint then
			bot.status = "IDLE"
			bot.isMoving = false
			return "DONE"
		end

		local dx = waypoint.x - hrp.Position.X
		local dz = waypoint.z - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist < 2 then
			task.pathIndex = task.pathIndex + 1
			if task.pathIndex > #task.path then
				bot.status = "IDLE"
				bot.isMoving = false
				return "DONE"
			end
			waypoint = task.path[task.pathIndex]
			bot.moveTargetX = waypoint.x
			bot.moveTargetZ = waypoint.z
			bot.isMoving = true
			bot.status = "MOVING"
			return "RUNNING"
		else
			bot.moveTargetX = waypoint.x
			bot.moveTargetZ = waypoint.z
			bot.isMoving = true
			bot.status = "MOVING"
			return "RUNNING"
		end

	elseif task.type == "IDLE" then
		local duration = task.args.duration or 1
		if not task.idleStart then
			task.idleStart = tick()
		end
		bot.status = "WAITING"
		if tick() - task.idleStart >= duration then
			bot.status = "IDLE"
			return "DONE"
		end
		return "RUNNING"

	elseif task.type == "TELEPORT" then
		local targetX, targetZ

		if task.args.target and type(task.args.target) == "table" then
			local target = task.args.target
			if target.world_position then
				local pos = target.world_position()
				targetX, targetZ = pos[1], pos[2]
			elseif target.position then
				local pos = target.position()
				local coreX, coreZ = 150, 150
				if deps.WaveManager and deps.WaveManager.getCorePosition then
					local corePos = deps.WaveManager.getCorePosition()
					if corePos then
						coreX = corePos.x or 150
						coreZ = corePos.z or 150
					end
				end
				targetX = pos[1] + coreX
				targetZ = pos[2] + coreZ
			end
		else
			targetX = task.args.x
			targetZ = task.args.z
		end

		if not targetX or not targetZ then return "FAILED" end

		local freeX, freeZ = Pathfinding.findFreePosition(targetX, targetZ, bot.id)

		if hrp then
			bot.character:PivotTo(CFrame.new(freeX, GROUND_Y + 3, freeZ))
			bot.status = "IDLE"
		end
		return "DONE"

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
				bot.status = "MOVING"
				local targetPos = enemyHrp.Position
				local dir = (targetPos - hrp.Position).Unit
				local moveSpeed = bot.speed or 20
				local newPos = hrp.Position + dir * math.min(moveSpeed * dt, dist - BotStats.SHOCK_RANGE + 1)

				hrp.CFrame = CFrame.new(newPos.X, hrp.Position.Y, newPos.Z) *
					CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0)
				return "RUNNING"
			end

			local damageDealt = EnemyManager.shock(enemyId, BotStats.SHOCK_DAMAGE, hrp.Position.X, hrp.Position.Z)
			task.damageDealt = damageDealt
			task.shockExecuted = true
			task.stunEndTime = tick() + BotStats.SHOCK_STUN_TIME

			BotModel.createShockEffect(bot)
			bot.status = "SHOCKING"
			return "RUNNING"
		else
			bot.status = "STUNNED"
			if tick() >= task.stunEndTime then
				bot.status = "IDLE"
				return "DONE"
			end
			return "RUNNING"
		end

	elseif task.type == "EXPLODE" then
		local cargo = bot.scrapInventory or 0
		if cargo < 10 then
			bot.status = "IDLE"
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

		BotModel.createExplosionEffect(bot, cargo)

		bot.scrapInventory = 0

		bot.status = "STUNNED"
		task.stunEndTime = tick() + 1.5
		task.exploded = true
		return "RUNNING"
	end

	if task.exploded and task.stunEndTime then
		if tick() >= task.stunEndTime then
			bot.status = "IDLE"
			return "DONE"
		end
		return "RUNNING"
	end

	bot.status = "IDLE"
	return "FAILED"
end

function BotRegistry.update(dt)
	for id, bot in pairs(bots) do
		local character = bot.character

		if not character or not character.Parent then
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
		if not hrp then continue end

		local baseY = character:GetAttribute("BaseY") or 2.5
		local facingAngle = character:GetAttribute("FacingAngle") or 0

		local newX, newZ = hrp.Position.X, hrp.Position.Z

		if bot.moveTargetX and bot.moveTargetZ then
			local dx = bot.moveTargetX - hrp.Position.X
			local dz = bot.moveTargetZ - hrp.Position.Z
			local dist = math.sqrt(dx * dx + dz * dz)

			if dist < 2 then
				bot.moveTargetX = nil
				bot.moveTargetZ = nil
				bot.isMoving = false
				bot.lastPos = nil
			else
				local speed = bot.speed or BotStats.BASE.speed
				local moveAmount = math.min(speed * dt, dist)
				local dirX = dx / dist
				local dirZ = dz / dist

				local proposedX = hrp.Position.X + dirX * moveAmount
				local proposedZ = hrp.Position.Z + dirZ * moveAmount

				local blocked = Pathfinding.isPositionBlocked(proposedX, proposedZ, id)

				if not blocked then
					newX = proposedX
					newZ = proposedZ
					bot.lastPos = {x = newX, z = newZ}
				else
					local lastRecompute = bot.lastPathRecompute or 0
					if tick() - lastRecompute > Pathfinding.PATH_RECOMPUTE_COOLDOWN then
						bot.lastPathRecompute = tick()
						local goalX = bot.finalGoalX or bot.moveTargetX
						local goalZ = bot.finalGoalZ or bot.moveTargetZ
						local newPath = recomputeBotPath(bot, goalX, goalZ)
						if newPath and #newPath > 0 then
							if bot.currentTask then
								bot.currentTask.path = newPath
								bot.currentTask.pathIndex = 1
							end
							bot.moveTargetX = newPath[1].x
							bot.moveTargetZ = newPath[1].z
						end
					end
				end

				facingAngle = math.atan2(-dirX, -dirZ)
				character:SetAttribute("FacingAngle", facingAngle)
			end
		end

		character:SetAttribute("IsMoving", bot.isMoving or false)
		character:SetAttribute("EmoteType", bot.emoteType or "")
		character:SetAttribute("EmoteEndTime", bot.emoteEndTime or 0)

		if bot.emoteEndTime and tick() >= bot.emoteEndTime then
			bot.emoteType = nil
			bot.emoteEndTime = nil
		end

		hrp.CFrame = CFrame.new(newX, baseY, newZ)
			* CFrame.Angles(0, facingAngle, 0)

		if not bot.currentTask and #bot.taskQueue > 0 then
			bot.currentTask = table.remove(bot.taskQueue, 1)
		end

		if bot.currentTask then
			local taskStatus = executeTask(bot, dt)
			if taskStatus == "DONE" or taskStatus == "FAILED" then
				bot.currentTask = nil
				if #bot.taskQueue == 0 then
					bot.waitingForTask = false
					if bot.interpreter and bot.interpreter.runtime then
						local vm = bot.interpreter.runtime.vm
						if vm and vm.unblock then
							vm:unblock()
						end
					end
				end
			end
		end

		if bot.interpreter and not bot.waitingForTask then
			local status = bot.interpreter.status
			if status == "RUNNING" or status == "READY" then
				bot.interpreter:run(5)
			end
		end

		BotModel.updateBillboard(bot)

		local backpack = character:FindFirstChild("Backpack")
		if backpack then
			local scrapPile = backpack:FindFirstChild("ScrapPile")
			if scrapPile then
				local ratio = (bot.scrapInventory or 0) / (bot.maxCapacity or 50)
				if ratio > 0 then
					scrapPile.Transparency = 0
					local pileHeight = 0.2 + (ratio * 0.8)
					scrapPile.Size = Vector3.new(1.6, pileHeight, 0.6)
				else
					scrapPile.Transparency = 1
				end
			end
		end

		local chatHead = character:FindFirstChild("ChatHead")
		if chatHead then
			local chatBubble = chatHead:FindFirstChild("ChatBubble")
			if chatBubble then
				local bubble = chatBubble:FindFirstChild("Bubble")
				local chatText = bubble and bubble:FindFirstChild("Text")
				local chatExpiry = character:GetAttribute("ChatExpiry") or 0

				if tick() > chatExpiry then
					if bubble then bubble.BackgroundTransparency = 1 end
					if chatText then chatText.TextTransparency = 1 end
				else
					if bubble then bubble.BackgroundTransparency = 0.1 end
					if chatText then chatText.TextTransparency = 0 end
				end
			end
		end
	end
end

function BotRegistry.getInterpreter(id)
	return nil
end

function BotRegistry.getAll()
	return bots
end

function BotRegistry.count()
	local n = 0
	for _ in pairs(bots) do n = n + 1 end
	return n
end

function BotRegistry.getBySpotId(spotId)
	for id, bot in pairs(bots) do
		if bot.spotId == spotId then
			return bot
		end
	end
	return nil
end

function BotRegistry.getByOwner(ownerId)
	local result = {}
	for id, bot in pairs(bots) do
		if bot.ownerId == ownerId then
			table.insert(result, bot)
		end
	end
	return result
end

function BotRegistry.isIdle(botId)
	local bot = bots[botId]
	if not bot then return false end
	return bot.currentTask == nil and #bot.taskQueue == 0 and not bot.isMoving
end

function BotRegistry.findNearest(x, z, maxRange)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	for id, bot in pairs(bots) do
		local character = bot.character
		local hrp = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
		if hrp then
			local dx = hrp.Position.X - x
			local dz = hrp.Position.Z - z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < nearestDist then
				nearestDist = dist
				nearest = bot
			end
		end
	end

	return nearest, nearestDist
end

function BotRegistry.findNearestWithCargo(x, z, maxRange)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	for id, bot in pairs(bots) do
		if (bot.scrapInventory or 0) > 0 then
			local character = bot.character
			local hrp = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < nearestDist then
					nearestDist = dist
					nearest = bot
				end
			end
		end
	end

	return nearest, nearestDist
end

function BotRegistry.getStats()
	return BotStats.BASE
end

function BotRegistry.moveBot(botId, x, z)
	local bot = bots[botId]
	if not bot then return end

	bot.moveTargetX = x
	bot.moveTargetZ = z
	bot.isMoving = true
	bot.status = "MOVING"
end

function BotRegistry.collectScrap(botId)
	local bot = bots[botId]
	if not bot then return 0 end

	local character = bot.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end

	local ScrapManager = deps.ScrapManager
	if not ScrapManager then return 0 end

	local x, z = hrp.Position.X, hrp.Position.Z
	local pickupRange = bot.pickupRange or 8
	local totalCollected = 0

	while true do
		local currentScrap = bot.scrapInventory or 0
		local maxCapacity = bot.maxCapacity or 50
		local space = maxCapacity - currentScrap

		if space <= 0 then
			break
		end

		local scrap = ScrapManager.findNearest(x, z, pickupRange)
		if not scrap or not scrap.id then
			break
		end

		local scrapAmount = scrap.amount or 1
		local toCollect = math.min(scrapAmount, space)
		bot.scrapInventory = (bot.scrapInventory or 0) + toCollect
		totalCollected = totalCollected + toCollect
		ScrapManager.remove(scrap.id)
	end

	if totalCollected > 0 then
		print("BotRegistry: Bot collected " .. totalCollected .. " scrap, now carrying " .. (bot.scrapInventory or 0))
	end

	return totalCollected
end

function BotRegistry.depositToCore(botId)
	local bot = bots[botId]
	if not bot then return 0 end

	local scrapToDeposit = bot.scrapInventory or 0
	if scrapToDeposit <= 0 then return 0 end

	if WaveManager then
		WaveManager.addScrap(scrapToDeposit)
		print("BotRegistry: Bot deposited " .. scrapToDeposit .. " scrap to core")
	end
	bot.scrapInventory = 0

	return scrapToDeposit
end

function BotRegistry.isStunned(botId)
	local bot = bots[botId]
	if not bot then return false end
	return bot.stunnedUntil and tick() < bot.stunnedUntil
end

function BotRegistry.kill(botId)
	local bot = bots[botId]
	if not bot then return end

	local ownerId = bot.ownerId
	local spotId = bot.spotId

	local cargo = bot.scrapInventory or 0
	if cargo > 0 and deps.ScrapManager and bot.character then
		local hrp = bot.character:FindFirstChild("HumanoidRootPart")
		if hrp then
			deps.ScrapManager.spawn(hrp.Position, cargo)
		end
	end

	BotModel.createDeathEffect(bot.character)

	print("BotRegistry: Bot #" .. (spotId or "?") .. " destroyed! Respawning in " .. BotStats.RESPAWN_TIME .. "s")

	BotRegistry.broadcastState()
	BotRegistry.destroy(botId)

	if ownerId and spotId then
		task.delay(BotStats.RESPAWN_TIME, function()
			local newBotId = BotRegistry.create(0, 0)
			if newBotId then
				local newBot = bots[newBotId]
				newBot.ownerId = ownerId
				newBot.spotId = spotId
				print("BotRegistry: Bot #" .. spotId .. " respawned!")
				BotRegistry.broadcastState()
			end
		end)
	end
end

function BotRegistry.activateShield(botId, duration)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	duration = duration or 3

	if bot.shieldActive then return false end

	if bot.shieldCooldownUntil and tick() < bot.shieldCooldownUntil then
		return false
	end

	bot.shieldActive = true
	bot.shieldExpires = tick() + duration
	bot.shieldCooldownUntil = tick() + BotStats.SHIELD_COOLDOWN

	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local shield = Instance.new("Part")
		shield.Name = "ShieldBubble"
		shield.Shape = Enum.PartType.Ball
		shield.Size = Vector3.new(8, 8, 8)
		shield.Material = Enum.Material.ForceField
		shield.Color = Color3.fromRGB(0, 200, 255)
		shield.Transparency = 0.6
		shield.Anchored = false
		shield.CanCollide = false
		shield.CFrame = hrp.CFrame
		shield.Parent = bot.character

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = shield
		weld.Parent = hrp

		task.delay(duration, function()
			if shield and shield.Parent then
				shield:Destroy()
			end
			if bot then
				bot.shieldActive = false
				bot.shieldExpires = nil
			end
		end)
	end

	return true
end

function BotRegistry.destroy(id)
	local bot = bots[id]
	if not bot then return end

	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(id)
	end

	if bot.character then
		bot.character:Destroy()
	end

	bots[id] = nil
	print("BotRegistry: Destroyed bot", id)
end

function BotRegistry.clear()
	for id in pairs(bots) do
		BotRegistry.destroy(id)
	end
	nextBotNumber = 1
end

function BotRegistry.broadcastState()
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		local data = BotRegistry.getStateForPlayer(player)
		botStateEvent:FireClient(player, data)
	end
end

function BotRegistry.getStateForPlayer(player)
	local botList = {}
	local playerId = player and player.UserId or nil

	for id, bot in pairs(bots) do
		if playerId == nil or bot.ownerId == playerId then
			local interp = bot.interpreter
			table.insert(botList, {
				id = id,
				spotId = bot.spotId,
				ownerId = bot.ownerId,
				scrapInventory = bot.scrapInventory or 0,
				maxCapacity = bot.maxCapacity or 50,
				maxBytecode = bot.maxBytecode or BotStats.BASE.maxBytecode,
				status = bot.status or "IDLE",
				paused = interp and interp.paused or false,
			})
		end
	end
	return { bots = botList }
end

function BotRegistry.sendStateToPlayer(player)
	local data = BotRegistry.getStateForPlayer(player)
	botStateEvent:FireClient(player, data)
end

function BotRegistry.killTemporaryBots()
	local count = 0
	for id, bot in pairs(bots) do
		if bot.isTemporary then
			BotModel.createMeltdownEffect(bot.character)

			task.delay(0.3, function()
				BotRegistry.destroy(id)
			end)
			count = count + 1
		end
	end
	if count > 0 then
		print("BotRegistry: Meltdown! Destroyed " .. count .. " temporary bots.")
	end
end

function BotRegistry.setBotColor(botId, colorName)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local col = BotStats.COLOR_MAP[string.lower(colorName or "")] or BotStats.COLOR_MAP.white
	bot.color = col

	for _, part in pairs(bot.character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = col
		end
	end
	return true
end

function BotRegistry.setChatBubble(botId, message)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local head = bot.character:FindFirstChild("Head") or bot.character.PrimaryPart
	if not head then return false end

	local bb = head:FindFirstChild("BotChat")

	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "BotChat"
		bb.Size = UDim2.new(0, 150, 0, 50)
		bb.StudsOffset = Vector3.new(0, 4, 0)
		bb.AlwaysOnTop = true
		bb.Parent = head

		local txt = Instance.new("TextLabel")
		txt.Name = "ChatText"
		txt.Size = UDim2.new(1, 0, 1, 0)
		txt.BackgroundTransparency = 1
		txt.TextColor3 = Color3.new(1, 1, 1)
		txt.TextStrokeTransparency = 0
		txt.TextStrokeColor3 = Color3.new(0, 0, 0)
		txt.Font = Enum.Font.Cartoon
		txt.TextSize = 18
		txt.TextScaled = false
		txt.Parent = bb
	end

	local txt = bb:FindFirstChild("ChatText")
	if txt then
		txt.Text = tostring(message)

		task.delay(3, function()
			if txt and txt.Parent and txt.Text == tostring(message) then
				txt.Text = ""
			end
		end)
	end
	return true
end

function BotRegistry.playEmote(botId, emoteName)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	if emoteName == "dance" or emoteName == "spin" then
		bot.emoteEndTime = tick() + 2
		bot.emoteType = "spin"
	elseif emoteName == "jump" or emoteName == "hop" then
		bot.emoteEndTime = tick() + 0.5
		bot.emoteType = "jump"
	elseif emoteName == "shake" or emoteName == "shiver" then
		bot.emoteEndTime = tick() + 1
		bot.emoteType = "shake"
	end

	return true
end

function BotRegistry.triggerExplosion(botId, damage)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local pos = hrp.Position

	local exp = Instance.new("Explosion")
	exp.Position = pos
	exp.BlastRadius = 0
	exp.BlastPressure = 0
	exp.Parent = workspace

	local EnemyManager = deps.EnemyManager
	if EnemyManager and EnemyManager.findInRange then
		local hitList = EnemyManager.findInRange(pos.X, pos.Z, 15)
		for _, enemy in ipairs(hitList) do
			if EnemyManager.damage then
				EnemyManager.damage(enemy.id, damage or 200)
			end
		end
	end

	BotRegistry.kill(botId)
	return true
end

function BotRegistry.zapEnemy(botId, range)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local EnemyManager = deps.EnemyManager
	if not EnemyManager or not EnemyManager.findNearest then return false end

	local bx, bz = hrp.Position.X, hrp.Position.Z
	local enemy, dist = EnemyManager.findNearest(bx, bz, range or 10)

	if enemy then
		local enemyPos = enemy.position
		if enemyPos then
			local beam = Instance.new("Part")
			beam.Name = "ZapBeam"
			beam.Anchored = true
			beam.CanCollide = false
			beam.Material = Enum.Material.Neon
			beam.Color = Color3.fromRGB(100, 200, 255)

			local startPos = hrp.Position
			local endPos = Vector3.new(enemyPos.X, startPos.Y, enemyPos.Z)
			local midPoint = (startPos + endPos) / 2
			local length = (startPos - endPos).Magnitude

			beam.Size = Vector3.new(0.3, 0.3, length)
			beam.CFrame = CFrame.lookAt(midPoint, endPos)
			beam.Parent = workspace

			task.delay(0.15, function()
				if beam and beam.Parent then
					beam:Destroy()
				end
			end)
		end

		if EnemyManager.damage then
			EnemyManager.damage(enemy.id, 25)
		end
		return true
	end
	return false
end

function BotRegistry.visualEffect(botId, effectType, targetId)
	local bot = bots[botId]
	if not bot then return false end

	if effectType == "zap" then
		return BotRegistry.zapEnemy(botId, 15)
	end
	return false
end

function BotRegistry.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		BotRegistry.update(dt)
	end)
end

return BotRegistry
