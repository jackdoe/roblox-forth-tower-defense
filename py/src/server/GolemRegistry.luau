local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local GolemStats = require(script.Parent.GolemStats)
local GolemModel = require(script.Parent.GolemModel)

local Python = nil

local GolemRegistry = {}

local GROUND_Y = GolemStats.GROUND_Y
local UpgradeTiers = GolemStats.UpgradeTiers
local AmmoStats = GolemStats.AmmoStats

local golems = {}
local deps = nil
local Interpreter = nil
local WaveManager = nil
local EnemyManager = nil

local PathMap = nil
local golemMinDistance = 8
local nextGolemNumber = 1

local golemStateEvent = nil
local golemPlaceAtEvent = nil
local golemSellEvent = nil
local golemFullStateEvent = nil
local golemRegisterViewerEvent = nil
local golemUnregisterViewerEvent = nil
local golemUpgradeEvent = nil
local golemUpgradeRAMEvent = nil
local golemAmmoChangeEvent = nil

local golemViewers = {}
local activeBoosts = {}

function GolemRegistry.init(dependencies, interpreterModule)
	deps = dependencies
	Interpreter = interpreterModule

	Python = require(PythonTD.Python)

	golemStateEvent = Instance.new("RemoteEvent")
	golemStateEvent.Name = "GolemState"
	golemStateEvent.Parent = PythonTD

	golemPlaceAtEvent = Instance.new("RemoteEvent")
	golemPlaceAtEvent.Name = "GolemPlaceAt"
	golemPlaceAtEvent.Parent = PythonTD

	golemSellEvent = Instance.new("RemoteEvent")
	golemSellEvent.Name = "GolemSell"
	golemSellEvent.Parent = PythonTD

	golemFullStateEvent = Instance.new("RemoteEvent")
	golemFullStateEvent.Name = "GolemFullState"
	golemFullStateEvent.Parent = PythonTD

	golemRegisterViewerEvent = Instance.new("RemoteEvent")
	golemRegisterViewerEvent.Name = "GolemRegisterViewer"
	golemRegisterViewerEvent.Parent = PythonTD

	golemUnregisterViewerEvent = Instance.new("RemoteEvent")
	golemUnregisterViewerEvent.Name = "GolemUnregisterViewer"
	golemUnregisterViewerEvent.Parent = PythonTD

	golemPlaceAtEvent.OnServerEvent:Connect(function(player, x, z)
		local success, result = GolemRegistry.tryPlaceAt(player, x, z)
		golemPlaceAtEvent:FireClient(player, success, result)
	end)

	golemSellEvent.OnServerEvent:Connect(function(player, golemId)
		local success, result = GolemRegistry.sellGolem(player, golemId)
		golemSellEvent:FireClient(player, success, result)
	end)

	golemRegisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
		if not golemViewers[golemId] then
			golemViewers[golemId] = {}
		end
		table.insert(golemViewers[golemId], player)
	end)

	golemUnregisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
		if golemViewers[golemId] then
			for i, p in ipairs(golemViewers[golemId]) do
				if p == player then
					table.remove(golemViewers[golemId], i)
					break
				end
			end
		end
	end)

	golemUpgradeEvent = Instance.new("RemoteEvent")
	golemUpgradeEvent.Name = "GolemUpgrade"
	golemUpgradeEvent.Parent = PythonTD

	golemUpgradeEvent.OnServerEvent:Connect(function(player, golemId)
		local success, result = GolemRegistry.upgradeGolem(player, golemId)
		golemUpgradeEvent:FireClient(player, success, result)
	end)

	golemUpgradeRAMEvent = Instance.new("RemoteEvent")
	golemUpgradeRAMEvent.Name = "GolemUpgradeRAM"
	golemUpgradeRAMEvent.Parent = PythonTD

	golemUpgradeRAMEvent.OnServerEvent:Connect(function(player, golemId)
		local success, result = GolemRegistry.upgradeRAM(player, golemId)
		golemUpgradeRAMEvent:FireClient(player, success, result)
	end)

	golemAmmoChangeEvent = Instance.new("RemoteEvent")
	golemAmmoChangeEvent.Name = "GolemAmmoChange"
	golemAmmoChangeEvent.Parent = PythonTD

	golemAmmoChangeEvent.OnServerEvent:Connect(function(player, golemId, ammoType)
		GolemRegistry.changeAmmoType(player, golemId, ammoType)
	end)
end

function GolemRegistry.setWaveManager(waveMgr)
	WaveManager = waveMgr
end

function GolemRegistry.getViewerEvents()
	return golemRegisterViewerEvent, golemUnregisterViewerEvent
end

function GolemRegistry.setEnemyManager(enemyMgr)
	EnemyManager = enemyMgr
end

function GolemRegistry.setPathMap(pathMapModule)
	PathMap = pathMapModule
end

function GolemRegistry.isInRestrictedZone(x, z)
	if not PathMap then return false end
	return PathMap.isRestrictedForTurret(x, z, golemMinDistance)
end

function GolemRegistry.isTooCloseToOtherGolem(x, z, excludeId)
	for id, golem in pairs(golems) do
		if id ~= excludeId and golem.character then
			local hrp = golem.character:FindFirstChild("HumanoidRootPart") or golem.character.PrimaryPart
			if hrp then
				local dx = hrp.Position.X - x
				local dz = hrp.Position.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < golemMinDistance then
					return true
				end
			end
		end
	end
	return false
end

function GolemRegistry.canPlaceAt(x, z)
	local inZone, reason = GolemRegistry.isInRestrictedZone(x, z)
	if inZone then
		return false, "Cannot build here: " .. (reason or "restricted area")
	end

	if GolemRegistry.isTooCloseToOtherGolem(x, z) then
		return false, "Too close to another golem"
	end

	return true
end

function GolemRegistry.getNextTurretCost(player)
	local myTurretCount = 0
	for _, golem in pairs(golems) do
		if golem.ownerId == player.UserId then
			myTurretCount = myTurretCount + 1
		end
	end
	return math.floor(GolemStats.TURRET_BASE_COST * (GolemStats.TURRET_COST_MULTIPLIER ^ myTurretCount))
end

function GolemRegistry.tryPlaceAt(player, x, z)
	local myTurretCount = 0
	for _, golem in pairs(golems) do
		if golem.ownerId == player.UserId then
			myTurretCount = myTurretCount + 1
		end
	end

	local canPlace, reason = GolemRegistry.canPlaceAt(x, z)
	if not canPlace then
		return false, reason
	end

	local cost = math.floor(GolemStats.TURRET_BASE_COST * (GolemStats.TURRET_COST_MULTIPLIER ^ myTurretCount))
	if WaveManager then
		local scrap = WaveManager.getScrap()
		if scrap < cost then
			return false, "Not enough scrap (" .. scrap .. "/" .. cost .. ")"
		end
		WaveManager.removeScrap(cost)
	end

	local golemId = GolemRegistry.create(x, z)
	if golemId then
		golems[golemId].spotId = nextGolemNumber
		golems[golemId].ownerId = player.UserId
		nextGolemNumber = nextGolemNumber + 1

		GolemRegistry.setGolemAttribute(golems[golemId])
		GolemRegistry.broadcastState()
		return true, golemId
	end

	return false, "Failed to create golem"
end

function GolemRegistry.sellGolem(player, golemId)
	local golem = golems[golemId]
	if not golem then
		return false, "Golem not found"
	end

	if golem.ownerId ~= player.UserId then
		return false, "You don't own this golem"
	end

	local refund = math.floor(GolemStats.BASE.cost * 0.75)

	if WaveManager then
		WaveManager.addScrap(refund)
	end

	GolemRegistry.destroy(golemId)
	GolemRegistry.broadcastState()

	return true, refund
end

function GolemRegistry.getUpgradeCost(golemId)
	local golem = golems[golemId]
	if not golem then return nil end

	local currentTier = golem.tier or 1
	if currentTier >= GolemStats.MAX_CPU_TIER then return nil end

	local nextTier = UpgradeTiers[currentTier + 1]
	return nextTier and nextTier.upgradeCost or nil
end

function GolemRegistry.upgradeGolem(player, golemId)
	local golem = golems[golemId]
	if not golem then
		return false, "Golem not found"
	end

	if golem.ownerId ~= player.UserId then
		return false, "You don't own this turret"
	end

	local currentTier = golem.tier or 1
	if currentTier >= GolemStats.MAX_CPU_TIER then
		return false, "CPU already at max"
	end

	local nextTierData = UpgradeTiers[currentTier + 1]
	if not nextTierData then
		return false, "Invalid tier"
	end

	local cost = nextTierData.upgradeCost
	if not cost then
		return false, "No upgrade cost defined"
	end

	if WaveManager then
		local scrap = WaveManager.getScrap()
		if scrap < cost then
			return false, "Not enough scrap (" .. scrap .. "/" .. cost .. ")"
		end
		WaveManager.removeScrap(cost)
	end

	golem.tier = currentTier + 1
	local newTierData = UpgradeTiers[golem.tier]

	local interp = golem.interpreter
	interp.maxAmmo = math.floor(GolemStats.BASE.maxAmmo * newTierData.ammoMultiplier)
	interp.ammo = math.min(interp.ammo, interp.maxAmmo)
	interp.range = math.floor(GolemStats.BASE.range * newTierData.rangeMultiplier)
	interp.dynamicRange = interp.range
	interp.tierDamageMultiplier = newTierData.damageMultiplier
	interp.tierFireRateMultiplier = newTierData.fireRateMultiplier

	local isDefaultProgram = false
	for _, tierProg in pairs(GolemStats.TIER_PROGRAMS) do
		if interp.lastProgram == tierProg then
			isDefaultProgram = true
			break
		end
	end

	if isDefaultProgram or not interp.lastProgram or interp.lastProgram == "" then
		local newProgram = GolemStats.TIER_PROGRAMS[golem.tier]
		if newProgram then
			interp:load(newProgram)
			interp.lastProgram = newProgram
		end
	end

	GolemModel.applyVisualUpgrade(golem)
	GolemModel.updateBillboard(golem)
	GolemRegistry.broadcastState()

	return true, {
		tier = golem.tier,
		tierName = newTierData.name,
		unlockedAmmo = GolemStats.getUnlockedAmmo(golem.tier)
	}
end

function GolemRegistry.upgradeRAM(player, golemId)
	local golem = golems[golemId]
	if not golem then
		return false, "Golem not found"
	end

	if golem.ownerId ~= player.UserId then
		return false, "You don't own this turret"
	end

	local currentRAMTier = golem.ramTier or 1
	if currentRAMTier >= GolemStats.MAX_RAM_TIER then
		return false, "RAM already at max"
	end

	local cost = GolemStats.getRAMUpgradeCost(currentRAMTier)
	if not cost then
		return false, "No upgrade available"
	end

	if WaveManager then
		local scrap = WaveManager.getScrap()
		if scrap < cost then
			return false, "Not enough scrap (" .. scrap .. "/" .. cost .. ")"
		end
		WaveManager.removeScrap(cost)
	end

	golem.ramTier = currentRAMTier + 1
	local newRAMData = GolemStats.RAMTiers[golem.ramTier]

	GolemModel.applyColorUpgrade(golem)
	GolemRegistry.broadcastState()

	return true, {
		ramTier = golem.ramTier,
		maxBytecode = newRAMData.maxBytecode,
	}
end

function GolemRegistry.changeAmmoType(player, golemId, ammoType)
	local golem = golems[golemId]
	if not golem then
		return false, "Golem not found"
	end

	if golem.ownerId ~= player.UserId then
		return false, "You don't own this turret"
	end

	local tier = golem.tier or 1
	if not GolemStats.isAmmoUnlocked(tier, ammoType) then
		return false, "Ammo type not unlocked"
	end

	local ammoName = GolemStats.AMMO_NAMES[ammoType] or "BULLET"

	local newProgram = string.format([[
# Turret - %s mode
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), %s)
]], ammoName, ammoName)

	local interp = golem.interpreter
	if interp then
		interp:load(newProgram)
		interp.lastProgram = newProgram
		golem.selectedAmmoType = ammoType
		GolemRegistry.broadcastState()

		if golemViewers[golemId] then
			for _, viewerPlayer in ipairs(golemViewers[golemId]) do
				GolemRegistry.sendGolemFullState(golemId, viewerPlayer)
			end
		end

		return true, {ammoType = ammoType, ammoName = ammoName}
	end

	return false, "No interpreter"
end

function GolemRegistry.create(x, z)
	local character = GolemModel.create(x, z)
	if not character then return nil end

	local interp = Interpreter.new(nil, true, deps)
	interp.character = character
	interp.isGolem = true

	interp.ammo = GolemStats.BASE.maxAmmo
	interp.maxAmmo = GolemStats.BASE.maxAmmo
	interp.range = GolemStats.BASE.range
	interp.dynamicRange = GolemStats.BASE.range
	interp.lastFireTime = 0
	interp.lastAmmoType = nil
	interp.target = nil
	interp.status = "IDLE"

	local id = game:GetService("HttpService"):GenerateGUID()
	interp.id = id

	local golem = {
		id = id,
		interpreter = interp,
		character = character,
		typeData = GolemStats.BASE,
		spotId = nil,
		ownerId = nil,
		tier = 1,
		ramTier = 1,

		facingAngle = 0,
		targetAngle = 0,
		barrelTilt = 0,

		taskQueue = {},
		currentTask = nil,
		overrideMode = nil,
	}

	golems[id] = golem

	if Python and Python.createGolemEnvironment then
		local envDeps = {
			GolemRegistry = GolemRegistry,
			EnemyManager = EnemyManager,
			WaveManager = WaveManager,
		}
		local gameEnv = Python.createGolemEnvironment(golem, envDeps)
		interp:setGameEnvironment(gameEnv)
	end

	interp:load(GolemStats.DEFAULT_PROGRAM)
	interp.lastProgram = GolemStats.DEFAULT_PROGRAM

	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = id,
			isGolem = true,
			character = character,
		})
	end

	GolemModel.createBillboard(golem)

	return id
end

function GolemRegistry.setGolemAttribute(golem)
	if golem and golem.character then
		golem.character:SetAttribute("GolemId", golem.id)
		golem.character:SetAttribute("SpotId", golem.spotId)
	end
end

function GolemRegistry.issueCommand(golemId, commandType, args)
	local golem = golems[golemId]
	if not golem then return false end

	table.insert(golem.taskQueue, {
		type = commandType,
		args = args or {},
		startTime = tick(),
	})
	return true
end

function GolemRegistry.setMode(golemId, mode)
	local golem = golems[golemId]
	if not golem then return false end

	golem.overrideMode = mode
	local interp = golem.interpreter

	if mode == "rapid" then
		interp.dynamicRange = 30
		interp.fireRateMultiplier = 2.0
	elseif mode == "eco" then
		interp.dynamicRange = 40
		interp.fireRateMultiplier = 0.5
	elseif mode == "sniper" then
		interp.dynamicRange = 60
		interp.fireRateMultiplier = 0.75
	elseif mode == "shotgun" then
		interp.dynamicRange = 15
		interp.fireRateMultiplier = 1.5
	else
		golem.overrideMode = nil
		interp.dynamicRange = 40
		interp.fireRateMultiplier = 1.0
	end

	return true
end

function GolemRegistry.forceTarget(golemId, enemyId)
	local golem = golems[golemId]
	if not golem then return false end
	golem.interpreter.target = enemyId
	return true
end

function GolemRegistry.clearCommands(golemId)
	local golem = golems[golemId]
	if not golem then return end
	golem.taskQueue = {}
	golem.currentTask = nil
	golem.overrideMode = nil
	golem.interpreter.fireRateMultiplier = 1.0
end

local function executeGolemTask(golem, dt)
	local task = golem.currentTask
	if not task then return "DONE" end

	if task.type == "SET_MODE" then
		GolemRegistry.setMode(golem.id, task.args.mode)
		return "DONE"
	elseif task.type == "FORCE_TARGET" then
		GolemRegistry.forceTarget(golem.id, task.args.enemyId)
		return "DONE"
	elseif task.type == "SET_RANGE" then
		local newRange = math.clamp(task.args.range or 40, 10, 60)
		golem.interpreter.dynamicRange = newRange
		return "DONE"
	end

	return "FAILED"
end

function GolemRegistry.getByOwner(ownerId)
	local result = {}
	for id, golem in pairs(golems) do
		if golem.ownerId == ownerId then
			table.insert(result, golem)
		end
	end
	return result
end

function GolemRegistry.isFiring(golemId)
	local golem = golems[golemId]
	if not golem then return false end
	return golem.interpreter.target ~= nil
end

function GolemRegistry.update(dt)
	for id, golem in pairs(golems) do
		local interp = golem.interpreter
		local character = golem.character

		if not character or not character.Parent then
			continue
		end

		if interp.reloadPending then
			local reload = interp.reloadPending
			local elapsed = tick() - reload.startTime

			if reload.collected < reload.amount then
				local stillNeed = reload.amount - reload.collected
				if WaveManager and WaveManager.removeCoreStockpile then
					local taken = WaveManager.removeCoreStockpile(math.min(stillNeed, 10))
					if taken > 0 then
						reload.collected = reload.collected + taken
						interp.ammo = (interp.ammo or 0) + taken
					end
				end
			end

			local isComplete = reload.collected >= reload.amount and elapsed >= reload.duration
			local timedOut = elapsed > 10

			if isComplete or timedOut then
				interp.reloadPending = nil
				local vm = interp.runtime and interp.runtime.vm
				if vm and vm.unblock then
					vm:unblock()
				end
			end
		end

		if golem.currentTask or #golem.taskQueue > 0 then
			if not golem.currentTask and #golem.taskQueue > 0 then
				golem.currentTask = table.remove(golem.taskQueue, 1)
			end

			if golem.currentTask then
				local status = executeGolemTask(golem, dt)
				if status == "DONE" or status == "FAILED" then
					golem.currentTask = nil
				end
			end
		end

		if not interp.paused then
			if interp.status == "DONE" then
				interp:reset()
				if interp.lastProgram then
					interp:load(interp.lastProgram)
				end
			end

			local tickRate = GolemStats.getTickRate(golem.tier)
			golem.tickAccum = (golem.tickAccum or 0) + dt
			if golem.tickAccum >= tickRate then
				golem.tickAccum = 0
				if interp.status == "READY" or interp.status == "RUNNING" then
					local freeSteps = deps.Config.GOLEM_FREE_STEPS_PER_TICK or 8
					interp:run(deps.Config.GOLEM_TICKS_PER_UPDATE or 1, freeSteps)
				end
			end
		end

		if interp.target and EnemyManager then
			local enemy = EnemyManager.get(interp.target)
			if enemy and enemy.character then
				local enemyHrp = enemy.character:FindFirstChild("HumanoidRootPart")
				local myHrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
				if enemyHrp and myHrp then
					local dx = enemyHrp.Position.X - myHrp.Position.X
					local dz = enemyHrp.Position.Z - myHrp.Position.Z
					golem.targetAngle = math.atan2(dx, dz) + math.pi
				end
			end
		end

		local angleDiff = golem.targetAngle - golem.facingAngle
		while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
		while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
		golem.facingAngle = golem.facingAngle + angleDiff * 0.15

		local head = character:FindFirstChild("Head")
		if head then
			local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
			if hrp then
				head.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0)) *
					CFrame.Angles(0, golem.facingAngle, 0)
			end
		end

		GolemModel.updateBillboard(golem)
	end
end

function GolemRegistry.fire(golemId, ammoType, skipCooldown)
	local golem = golems[golemId]
	if not golem then return false end

	local tier = golem.tier or 1
	if not GolemStats.isAmmoUnlocked(tier, ammoType) then
		ammoType = 1
	end

	local ammoStats = AmmoStats[ammoType] or AmmoStats[1]

	local interp = golem.interpreter

	local baseRange = 40
	local currentRange = interp.dynamicRange or baseRange
	local damageMult = baseRange / currentRange

	if interp.ammo < ammoStats.ammoCost then
		return false
	end

	local fireRateMult = interp.fireRateMultiplier or 1
	local tierFireRateMult = interp.tierFireRateMultiplier or 1
	fireRateMult = fireRateMult * tierFireRateMult

	local boost = activeBoosts[golemId]
	if boost then
		if tick() < boost.expires then
			fireRateMult = fireRateMult * boost.multiplier
		else
			activeBoosts[golemId] = nil
		end
	end

	local now = tick()
	local adjustedFireRate = ammoStats.fireRate / fireRateMult
	if not skipCooldown and now - interp.lastFireTime < adjustedFireRate then
		return false
	end

	if not interp.target then
		return false
	end

	if not EnemyManager then
		return false
	end

	local enemy = EnemyManager.get(interp.target)
	if not enemy or enemy.hp <= 0 then
		interp.target = nil
		return false
	end

	local character = golem.character
	local myHrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	local enemyHrp = enemy.character and enemy.character:FindFirstChild("HumanoidRootPart")
	if not myHrp or not enemyHrp then
		return false
	end

	local dist = (enemyHrp.Position - myHrp.Position).Magnitude

	if dist > currentRange then
		interp.target = nil
		return false
	end

	interp.ammo = interp.ammo - ammoStats.ammoCost
	interp.lastFireTime = now

	local tierDamageMult = interp.tierDamageMultiplier or 1
	local finalDamage = math.floor(ammoStats.damage * damageMult * tierDamageMult)

	if ammoStats.splashRadius and ammoStats.splashRadius > 0 then
		local enemies = EnemyManager.getAll and EnemyManager.getAll() or {}
		for _, e in pairs(enemies) do
			if e.hp > 0 and e.character then
				local eHrp = e.character:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local eDist = (eHrp.Position - enemyHrp.Position).Magnitude
					if eDist <= ammoStats.splashRadius then
						local damageToApply = finalDamage
						if EnemyManager.checkShatterCombo then
							damageToApply = EnemyManager.checkShatterCombo(e.id, finalDamage)
						end
						local falloff = 1 - (eDist / ammoStats.splashRadius) * 0.5
						EnemyManager.damage(e.id, math.floor(damageToApply * falloff), golemId)
						if EnemyManager.applyOiled then
							EnemyManager.applyOiled(e.id, 5)
						end
					end
				end
			end
		end
	else
		if finalDamage > 0 then
			EnemyManager.damage(interp.target, finalDamage, golemId)
		end
	end

	if ammoStats.slowAmount and ammoStats.slowDuration then
		EnemyManager.applySlow(interp.target, ammoStats.slowAmount, ammoStats.slowDuration)
	end

	if ammoType == 3 and EnemyManager.applyBurning then
		EnemyManager.applyBurning(interp.target, 3, 5)
	end

	GolemModel.createMuzzleFlash(golem, enemyHrp.Position, ammoStats)

	return true
end

function GolemRegistry.uploadProgram(golemId, source, autoStart)
	local golem = golems[golemId]
	if not golem then return false, "Golem not found" end

	local interp = golem.interpreter
	local success = interp:load(source)

	if success then
		if autoStart ~= false then
			interp.paused = false
		end
		return true
	else
		return false, interp.error or "Compilation failed"
	end
end

function GolemRegistry.getProgram(golemId)
	local golem = golems[golemId]
	if not golem then return nil end
	return golem.interpreter.source or ""
end

function GolemRegistry.get(id)
	return golems[id]
end

function GolemRegistry.getInterpreter(id)
	local golem = golems[id]
	return golem and golem.interpreter
end

function GolemRegistry.getAll()
	return golems
end

function GolemRegistry.count()
	local n = 0
	for _ in pairs(golems) do n = n + 1 end
	return n
end

function GolemRegistry.getBySpotId(spotId)
	for id, golem in pairs(golems) do
		if golem.spotId == spotId then
			return golem
		end
	end
	return nil
end

function GolemRegistry.findNearest(x, z, maxRange)
	local nearest = nil
	local nearestDist = maxRange or math.huge

	for id, golem in pairs(golems) do
		local character = golem.character
		local hrp = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
		if hrp then
			local dx = hrp.Position.X - x
			local dz = hrp.Position.Z - z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < nearestDist then
				nearestDist = dist
				nearest = golem
			end
		end
	end

	return nearest, nearestDist
end

function GolemRegistry.findNearestToCharacter(character)
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	return GolemRegistry.findNearest(hrp.Position.X, hrp.Position.Z, 10)
end

function GolemRegistry.refillAmmo(golemId, amount)
	local golem = golems[golemId]
	if not golem then return 0 end

	local interp = golem.interpreter
	local needed = interp.maxAmmo - interp.ammo
	local toAdd = math.min(amount, needed)

	interp.ammo = interp.ammo + toAdd
	return toAdd
end

function GolemRegistry.applyBoost(golemId, multiplier, duration)
	activeBoosts[golemId] = {
		multiplier = multiplier,
		expires = tick() + duration
	}

	local golem = golems[golemId]
	if golem and golem.character and golem.character.PrimaryPart then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(1, 1, 1)
		p.Position = golem.character.PrimaryPart.Position + Vector3.new(0, 5, 0)
		p.Transparency = 1
		p.Parent = workspace

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 100, 0, 50)
		bb.AlwaysOnTop = true
		bb.Parent = p

		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 1, 0)
		t.BackgroundTransparency = 1
		t.Text = "OVERDRIVE!"
		t.TextColor3 = Color3.fromRGB(255, 100, 50)
		t.Font = Enum.Font.GothamBold
		t.TextSize = 18
		t.TextStrokeTransparency = 0.5
		t.Parent = bb

		game:GetService("Debris"):AddItem(p, 2)

		TweenService:Create(p, TweenInfo.new(1), {
			Position = p.Position + Vector3.new(0, 5, 0)
		}):Play()
	end
end

function GolemRegistry.destroy(id)
	local golem = golems[id]
	if not golem then return end

	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(id)
	end

	if golem.character then
		golem.character:Destroy()
	end

	golems[id] = nil
end

function GolemRegistry.clear()
	for id in pairs(golems) do
		GolemRegistry.destroy(id)
	end
	nextGolemNumber = 1
end

function GolemRegistry.getStateForPlayer(player)
	local golemList = {}
	local playerId = player and player.UserId or nil

	for id, golem in pairs(golems) do
		local interp = golem.interpreter
		if playerId == nil or golem.ownerId == playerId then
			local tier = golem.tier or 1
			local tierData = UpgradeTiers[tier]
			local upgradeCost = GolemRegistry.getUpgradeCost(id)

			local ramTier = golem.ramTier or 1
			local ramTierData = GolemStats.RAMTiers[ramTier]
			local ramUpgradeCost = GolemStats.getRAMUpgradeCost(ramTier)

			table.insert(golemList, {
				id = id,
				spotId = golem.spotId,
				typeName = golem.typeData.name,
				ammo = interp.ammo,
				maxAmmo = interp.maxAmmo,
				dynamicRange = interp.dynamicRange or 40,
				status = interp.ammo <= 0 and "EMPTY" or (interp.target and "FIRING" or "IDLE"),
				ownerId = golem.ownerId,
				paused = interp.paused or false,
				tier = tier,
				tierName = tierData and tierData.name or "1 Hz",
				upgradeCost = upgradeCost,
				cpuHz = tierData and tierData.cpuHz or 1,
				ramTier = ramTier,
				maxBytecode = ramTierData and ramTierData.maxBytecode or 32,
				ramUpgradeCost = ramUpgradeCost,
				unlockedAmmo = GolemStats.getUnlockedAmmo(tier),
				selectedAmmoType = golem.selectedAmmoType or 1,
			})
		end
	end

	local nextCost = GolemRegistry.getNextTurretCost(player)

	return { golems = golemList, nextTurretCost = nextCost }
end

function GolemRegistry.broadcastState()
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		local data = GolemRegistry.getStateForPlayer(player)
		golemStateEvent:FireClient(player, data)
	end
end

function GolemRegistry.sendStateToPlayer(player)
	local data = GolemRegistry.getStateForPlayer(player)
	golemStateEvent:FireClient(player, data)
end

function GolemRegistry.sendGolemFullState(golemId, player)
	local golem = golems[golemId]
	if not golem or not golem.interpreter then return end

	local state = golem.interpreter:getState()
	state.golemId = golemId
	state.spotId = golem.spotId
	state.typeName = golem.typeData.name
	state.programSource = golem.interpreter.source or ""

	golemFullStateEvent:FireClient(player, state)
end

function GolemRegistry.getGolemStats()
	return GolemStats.BASE
end

function GolemRegistry.getCpuHz(tier)
	return GolemStats.getCpuHz(tier)
end

function GolemRegistry.getMaxBytecode(ramTier)
	return GolemStats.getMaxBytecode(ramTier)
end

function GolemRegistry.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		GolemRegistry.update(dt)
	end)
end

return GolemRegistry
