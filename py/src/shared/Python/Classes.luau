local Classes = {}

local T = {
	ANY = "any",
	NIL = "nil",
	BOOL = "bool",
	NUMBER = "number",
	STRING = "string",
	LIST = "List",
	ENEMY = "Enemy",
	TURRET = "Turret",
	BOT = "Bot",
	PLAYER = "Player",
	AMMO_TYPE = "AmmoType",
	VECTOR = "Vector",
	FUNCTION = "Function",
}

Classes.T = T

local function method(args, returns, impl)
	return { kind = "method", args = args, returns = returns, impl = impl }
end

local function prop(typ, getter)
	return { kind = "prop", type = typ, get = getter }
end

local function queueTask(entity, taskType, args, blocking)
	if not entity.taskQueue then
		entity.taskQueue = {}
	end
	table.insert(entity.taskQueue, {
		type = taskType,
		args = args or {},
		startTime = tick(),
	})
	if blocking then
		entity.waitingForTask = true
		local vm = entity.interpreter and entity.interpreter.runtime and entity.interpreter.runtime.vm
		if vm and vm.block then vm:block() end
	end
	return true
end

Classes.Enemy = {
	name = "Enemy",
	members = {
		id = prop(T.STRING, function(deps, e) return e.id end),
		is_boss = prop(T.BOOL, function(deps, e) return e.typeName == "Boss" end),
		is_tank = prop(T.BOOL, function(deps, e) return e.typeName == "Tank" end),
		is_runner = prop(T.BOOL, function(deps, e) return e.typeName == "Runner" end),
		hp = prop(T.NUMBER, function(deps, e) return e.hp or 0 end),
		max_hp = prop(T.NUMBER, function(deps, e) return e.maxHp or 1 end),
		burning = prop(T.BOOL, function(deps, e) return e.burning or false end),
		frozen = prop(T.BOOL, function(deps, e) return (e.slowAmount and e.slowAmount >= 0.5) or false end),
		slowed = prop(T.BOOL, function(deps, e) return (e.slowAmount and e.slowAmount > 0) or false end),
		oiled = prop(T.BOOL, function(deps, e) return e.oiled or false end),

		pos = prop(T.VECTOR, function(deps, enemy)
			local EnemyManager = deps.EnemyManager
			local e = EnemyManager and EnemyManager.get and EnemyManager.get(enemy.id)
			if e and e.character then
				local hrp = e.character:FindFirstChild("HumanoidRootPart") or e.character.PrimaryPart
				if hrp then
					local coreX, coreZ = deps.getCoreOffset()
					return { math.floor(hrp.Position.X - coreX), math.floor(hrp.Position.Z - coreZ) }
				end
			end
			return { 0, 0 }
		end),

		alive = method({}, T.BOOL, function(deps, enemy)
			local EnemyManager = deps.EnemyManager
			local e = EnemyManager and EnemyManager.get and EnemyManager.get(enemy.id)
			return e and e.hp and e.hp > 0
		end),
	},
}

Classes.Turret = {
	name = "Turret",
	members = {
		pos = prop(T.VECTOR, function(deps, turret)
			if turret.character then
				local x, z = deps.getCharacterPos(turret.character)
				local coreX, coreZ = deps.getCoreOffset()
				return { math.floor(x - coreX), math.floor(z - coreZ) }
			end
			return { 0, 0 }
		end),

		ammo = method({}, T.NUMBER, function(deps, turret)
			return turret.interpreter and turret.interpreter.ammo or 0
		end),

		max_ammo = method({}, T.NUMBER, function(deps, turret)
			return turret.interpreter and turret.interpreter.maxAmmo or 300
		end),

		reload = method({ T.NUMBER }, T.NUMBER, function(deps, turret, amount)
			local interp = turret.interpreter
			if not interp then return 0 end

			local needed = (interp.maxAmmo or 300) - (interp.ammo or 0)
			if needed <= 0 then return 0 end

			amount = amount or needed
			local toReload = math.min(amount, needed)

			interp.reloadPending = {
				amount = toReload,
				startTime = tick(),
				duration = 1 + (toReload / 50),
				collected = 0,
			}

			local vm = interp.runtime and interp.runtime.vm
			if vm and vm.block then vm:block() end

			return toReload
		end),

		set_range = method({ T.NUMBER }, T.NIL, function(deps, turret, range)
			if turret.interpreter then
				turret.interpreter.dynamicRange = math.clamp(range or 40, 10, 60)
			end
		end),

		set_target = method({ T.ENEMY }, T.NIL, function(deps, turret, enemy)
			if turret.interpreter and enemy and enemy.id then
				turret.interpreter.target = enemy.id
			end
		end),

		target = method({}, { "optional", T.ENEMY }, function(deps, turret)
			if not turret.interpreter then return nil end
			local targetId = turret.interpreter.target
			if not targetId then return nil end

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.get then
				local enemy = EnemyManager.get(targetId)
				if enemy and enemy.hp and enemy.hp > 0 then
					return deps.createEnemyProxy(enemy)
				end
			end
			return nil
		end),

		fire = method({ T.AMMO_TYPE }, T.BOOL, function(deps, turret, ammoType)
			ammoType = ammoType or 1
			local interp = turret.interpreter
			if not interp then return false end

			local GolemStats = deps.GolemStats
			local GolemModel = deps.GolemModel
			if not GolemStats or not GolemModel then return false end

			local AmmoStats = GolemStats.AmmoStats
			local ammoStats = AmmoStats[ammoType] or AmmoStats[1]

			if interp.ammo < ammoStats.ammoCost then return false end

			local now = tick()
			local fireRateMult = interp.fireRateMultiplier or 1
			local adjustedFireRate = ammoStats.fireRate / fireRateMult
			if now - interp.lastFireTime < adjustedFireRate then return false end

			if not interp.target then return false end

			local EnemyManager = deps.EnemyManager
			if not EnemyManager then return false end

			local enemy = EnemyManager.get(interp.target)
			if not enemy or enemy.hp <= 0 then
				interp.target = nil
				return false
			end

			local character = turret.character
			local myHrp = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
			local enemyHrp = enemy.character and enemy.character:FindFirstChild("HumanoidRootPart")
			if not myHrp or not enemyHrp then return false end

			local dist = (enemyHrp.Position - myHrp.Position).Magnitude
			local currentRange = interp.dynamicRange or 40
			if dist > currentRange then
				interp.target = nil
				return false
			end

			interp.ammo = interp.ammo - ammoStats.ammoCost
			interp.lastFireTime = now

			local baseRange = 40
			local damageMult = baseRange / currentRange
			local tierDamageMult = interp.tierDamageMultiplier or 1
			local unitPower = interp.power or 1
			local finalDamage = math.floor(ammoStats.damage * damageMult * tierDamageMult * unitPower)

			if ammoStats.splashRadius and ammoStats.splashRadius > 0 then
				local enemies = EnemyManager.getAll and EnemyManager.getAll() or {}
				for _, e in pairs(enemies) do
					if e.hp > 0 and e.character then
						local eHrp = e.character:FindFirstChild("HumanoidRootPart")
						if eHrp then
							local eDist = (eHrp.Position - enemyHrp.Position).Magnitude
							if eDist <= ammoStats.splashRadius then
								local falloff = 1 - (eDist / ammoStats.splashRadius) * 0.5
								EnemyManager.damage(e.id, math.floor(finalDamage * falloff), turret.id)
							end
						end
					end
				end
			else
				if finalDamage > 0 then
					EnemyManager.damage(interp.target, finalDamage, turret.id)
				end
			end

			if ammoStats.slowAmount and ammoStats.slowDuration then
				EnemyManager.applySlow(interp.target, ammoStats.slowAmount, ammoStats.slowDuration)
			end

			if ammoType == 3 and EnemyManager.applyBurning then
				EnemyManager.applyBurning(interp.target, 3, 5)
			end

			GolemModel.createMuzzleFlash(turret, enemyHrp.Position, ammoStats)

			return true
		end),

		scan = method({}, { T.LIST, T.ENEMY }, function(deps, turret)
			if not turret.character then return {} end
			local x, z = deps.getCharacterPos(turret.character)
			local range = turret.interpreter and turret.interpreter.dynamicRange or 40

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findInRange then
				local enemies = EnemyManager.findInRange(x, z, range)
				local results = {}
				for _, e in ipairs(enemies) do
					table.insert(results, deps.createEnemyProxy(e))
				end
				return results
			end
			return {}
		end),

		danger = method({}, T.NUMBER, function(deps, turret)
			if not turret.character then return 9999 end
			local x, z = deps.getCharacterPos(turret.character)
			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findNearest then
				local enemy, dist = EnemyManager.findNearest(x, z, 100)
				if enemy then return math.floor(dist) end
			end
			return 9999
		end),
	},
}

Classes.Bot = {
	name = "Bot",
	members = {
		pos = prop(T.VECTOR, function(deps, bot)
			if bot.character then
				local x, z = deps.getCharacterPos(bot.character)
				local coreX, coreZ = deps.getCoreOffset()
				return { math.floor(x - coreX), math.floor(z - coreZ) }
			end
			return { 0, 0 }
		end),

		cargo = prop(T.NUMBER, function(deps, bot)
			return bot.scrapInventory or 0
		end),

		carrying = method({}, T.NUMBER, function(deps, bot)
			return bot.scrapInventory or 0
		end),

		forward = method({ T.NUMBER }, T.BOOL, function(deps, bot, steps)
			steps = steps or 10
			if not bot.character then return false end
			local hrp = bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local facingAngle = bot.facingAngle or 0
			local dirX = -math.sin(facingAngle)
			local dirZ = -math.cos(facingAngle)
			local targetX = hrp.Position.X + dirX * steps
			local targetZ = hrp.Position.Z + dirZ * steps

			return queueTask(bot, "MOVE", { x = targetX, z = targetZ }, true)
		end),

		backward = method({ T.NUMBER }, T.BOOL, function(deps, bot, steps)
			return Classes.Bot.members.forward.impl(deps, bot, -(steps or 10))
		end),

		left = method({ T.NUMBER }, T.BOOL, function(deps, bot, angle)
			angle = angle or 90
			bot.facingAngle = (bot.facingAngle or 0) + math.rad(angle)
			return true
		end),

		right = method({ T.NUMBER }, T.BOOL, function(deps, bot, angle)
			return Classes.Bot.members.left.impl(deps, bot, -(angle or 90))
		end),

		teleport = method({ T.VECTOR }, T.BOOL, function(deps, bot, pos)
			if type(pos) ~= "table" or #pos ~= 2 then return false end
			local coreX, coreZ = deps.getCoreOffset()
			return queueTask(bot, "TELEPORT", { x = pos[1] + coreX, z = pos[2] + coreZ }, true)
		end),

		shock = method({ T.ENEMY }, T.BOOL, function(deps, bot, target)
			local enemyId = type(target) == "table" and target.id or target
			if not enemyId then return false end
			return queueTask(bot, "SHOCK", { enemyId = enemyId }, true)
		end),

		scan = method({}, { T.LIST, T.ENEMY }, function(deps, bot)
			if not bot.character then return {} end
			local x, z = deps.getCharacterPos(bot.character)

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findInRange then
				local enemies = EnemyManager.findInRange(x, z, 50)
				local results = {}
				for _, e in ipairs(enemies) do
					table.insert(results, deps.createEnemyProxy(e))
				end
				return results
			end
			return {}
		end),

		collect = method({}, T.BOOL, function(deps, bot)
			local capacity = bot.maxCapacity or 3
			if (bot.scrapInventory or 0) >= capacity then return true end

			local ScrapManager = deps.ScrapManager
			if not ScrapManager then return false end

			local hrp = bot.character and bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local x, z, count = ScrapManager.findBestCluster(hrp.Position.X, hrp.Position.Z, 200, 20)
			if not x or count == 0 then return false end

			return queueTask(bot, "COLLECT", {}, true)
		end),

		explode = method({}, T.BOOL, function(deps, bot)
			local cargo = bot.scrapInventory or 0
			if cargo < 10 then
				error("explode() requires at least 10 scrap (carrying " .. cargo .. ")")
			end
			return queueTask(bot, "EXPLODE", {}, true)
		end),

		say = method({ T.STRING }, T.NIL, function(deps, bot, message)
			local character = bot.character
			if not character then return end

			local head = character:FindFirstChild("Head") or character.PrimaryPart
			if not head then return end

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
		end),

		deposit = method({}, T.BOOL, function(deps, bot)
			if (bot.scrapInventory or 0) <= 0 then return false end
			if not bot.character then return false end

			local hrp = bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local coreX, coreZ = deps.getCoreOffset()
			local dist = math.sqrt((hrp.Position.X - coreX)^2 + (hrp.Position.Z - coreZ)^2)
			if dist > 15 then return false end

			local WaveManager = deps.WaveManager
			if not WaveManager then return false end

			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local Config = require(ReplicatedStorage:WaitForChild("PythonTD").Config)
			local pieceValue = Config.SCRAP_PIECE_VALUE or 10

			WaveManager.addScrap(bot.scrapInventory * pieceValue)
			bot.scrapInventory = 0
			return true
		end),
	},
}

Classes.Player = {
	name = "Player",
	members = {
		pos = prop(T.VECTOR, function(deps, player)
			if player.character then
				local x, z = deps.getCharacterPos(player.character)
				local coreX, coreZ = deps.getCoreOffset()
				return { math.floor(x - coreX), math.floor(z - coreZ) }
			end
			return { 0, 0 }
		end),

		cargo = prop(T.NUMBER, function(deps, player)
			return player.interpreter and player.interpreter.scrapInventory or 0
		end),

		forward = method({ T.NUMBER }, T.BOOL, function(deps, player, steps)
			steps = steps or 10
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.character:FindFirstChild("Humanoid")
			if not hrp or not humanoid then return false end

			local lookVector = hrp.CFrame.LookVector
			local targetPos = hrp.Position + lookVector * steps
			humanoid:MoveTo(targetPos)
			return true
		end),

		backward = method({ T.NUMBER }, T.BOOL, function(deps, player, steps)
			steps = steps or 10
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.character:FindFirstChild("Humanoid")
			if not hrp or not humanoid then return false end

			local lookVector = hrp.CFrame.LookVector
			local targetPos = hrp.Position - lookVector * steps
			humanoid:MoveTo(targetPos)
			return true
		end),

		left = method({ T.NUMBER }, T.BOOL, function(deps, player, angle)
			return true
		end),

		right = method({ T.NUMBER }, T.BOOL, function(deps, player, angle)
			return true
		end),

		teleport = method({ T.VECTOR }, T.BOOL, function(deps, player, pos)
			if type(pos) ~= "table" or #pos ~= 2 then return false end
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local coreX, coreZ = deps.getCoreOffset()
			local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("PythonTD").Config)
			hrp.CFrame = CFrame.new(pos[1] + coreX, Config.PLATFORM_Y + 3, pos[2] + coreZ)
			return true
		end),

		scan = method({}, { T.LIST, T.ENEMY }, function(deps, player)
			if not player.character then return {} end
			local x, z = deps.getCharacterPos(player.character)

			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findInRange then
				local enemies = EnemyManager.findInRange(x, z, 50)
				local results = {}
				for _, e in ipairs(enemies) do
					table.insert(results, deps.createEnemyProxy(e))
				end
				return results
			end
			return {}
		end),

		say = method({ T.STRING }, T.NIL, function(deps, player, message)
		end),

		deposit = method({}, T.BOOL, function(deps, player)
			local interp = player.interpreter
			if not interp then return false end
			if (interp.scrapInventory or 0) <= 0 then return false end
			if not player.character then return false end

			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local coreX, coreZ = deps.getCoreOffset()
			local dist = math.sqrt((hrp.Position.X - coreX)^2 + (hrp.Position.Z - coreZ)^2)
			if dist > 15 then return false end

			local WaveManager = deps.WaveManager
			if not WaveManager then return false end

			local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("PythonTD").Config)
			local pieceValue = Config.SCRAP_PIECE_VALUE or 10
			WaveManager.addScrap(interp.scrapInventory * pieceValue)
			interp.scrapInventory = 0
			return true
		end),

		collect = method({}, T.BOOL, function(deps, player)
			if not player.character then return false end
			local hrp = player.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local interp = player.interpreter
			if not interp then return false end

			local capacity = interp.maxCapacity or 5
			if (interp.scrapInventory or 0) >= capacity then return true end

			local ScrapManager = deps.ScrapManager
			if not ScrapManager then return false end

			local pickupRange = 8
			local collected = 0

			while (interp.scrapInventory or 0) < capacity do
				local nearest = ScrapManager.findNearest(hrp.Position.X, hrp.Position.Z, pickupRange)
				if not nearest then break end
				if ScrapManager.collect(nearest.id) then
					interp.scrapInventory = (interp.scrapInventory or 0) + 1
					collected = collected + 1
				else
					break
				end
			end

			return collected > 0
		end),

		explode = method({}, T.BOOL, function(deps, player)
			if not player.character then return false end
			local PlayerCombat = deps.PlayerCombat
			if PlayerCombat and PlayerCombat.explode then
				return PlayerCombat.explode(player.playerId)
			end
			return false
		end),

		fire = method({ T.AMMO_TYPE }, T.BOOL, function(deps, player, ammoType)
			local PlayerCombat = deps.PlayerCombat
			if not PlayerCombat or not PlayerCombat.fire then return false end
			if not player.interpreter then return false end

			local targetId = player.interpreter.target
			if not targetId then return false end

			local EnemyManager = deps.EnemyManager
			local enemy = EnemyManager and EnemyManager.get and EnemyManager.get(targetId)
			if not enemy then return false end

			return PlayerCombat.fire(player.interpreter, enemy, ammoType or 1)
		end),

		set_target = method({ T.ENEMY }, T.NIL, function(deps, player, enemy)
			if player.interpreter and enemy and enemy.id then
				player.interpreter.target = enemy.id
			end
		end),

		target = method({}, { "optional", T.ENEMY }, function(deps, player)
			if not player.interpreter then return nil end
			local targetId = player.interpreter.target
			if not targetId then return nil end
			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.get then
				local enemy = EnemyManager.get(targetId)
				if enemy and enemy.hp and enemy.hp > 0 then
					return deps.createEnemyProxy(enemy)
				end
			end
			return nil
		end),

		danger = method({}, T.NUMBER, function(deps, player)
			if not player.character then return 9999 end
			local x, z = deps.getCharacterPos(player.character)
			local EnemyManager = deps.EnemyManager
			if EnemyManager and EnemyManager.findNearest then
				local enemy, dist = EnemyManager.findNearest(x, z, 100)
				if enemy then return math.floor(dist) end
			end
			return 9999
		end),
	},
}

Classes.Builtins = {
	["True"] = T.BOOL,
	["False"] = T.BOOL,
	["None"] = T.NIL,

	["print"] = { type = "Function", args = { T.ANY }, returns = T.NIL },
	["len"] = { type = "Function", args = { T.LIST }, returns = T.NUMBER },
	["range"] = { type = "Function", args = { T.NUMBER }, returns = { T.LIST, T.NUMBER } },
	["abs"] = { type = "Function", args = { T.NUMBER }, returns = T.NUMBER },
	["min"] = { type = "Function", args = { T.NUMBER, T.NUMBER }, returns = T.NUMBER },
	["max"] = { type = "Function", args = { T.NUMBER, T.NUMBER }, returns = T.NUMBER },

	["nearest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },
	["furthest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },
	["strongest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },
	["weakest"] = { type = "Function", args = { { T.LIST, T.ENEMY } }, returns = T.ENEMY },

	["BULLET"] = T.AMMO_TYPE,
	["ROCKET"] = T.AMMO_TYPE,
	["LASER"] = T.AMMO_TYPE,
	["ICE"] = T.AMMO_TYPE,
	["FREEZE"] = T.AMMO_TYPE,
	["GRENADE"] = T.AMMO_TYPE,

	["CORE"] = T.ANY,
}

Classes.EnvPatterns = {
	["^T%d+$"] = "Turret",
	["^B%d$"] = "Bot",
}

function Classes.getMethodInfo(className, methodName)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return nil end
	local member = classDef.members[methodName]
	if member and member.kind == "method" then return member end
	return nil
end

function Classes.getPropertyType(className, propName)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return nil end
	local member = classDef.members[propName]
	if member and member.kind == "prop" then return member.type end
	return nil
end

function Classes.getAllMembers(className)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return {} end

	local members = {}
	for name, member in pairs(classDef.members) do
		if member.kind == "method" then
			table.insert(members, { name = name, kind = "method", info = member })
		else
			table.insert(members, { name = name, kind = "property", type = member.type })
		end
	end
	return members
end

function Classes.getBuiltinType(name)
	if Classes.Builtins[name] then
		return Classes.Builtins[name]
	end
	for pattern, className in pairs(Classes.EnvPatterns) do
		if name:match(pattern) then
			return className
		end
	end
	return nil
end

function Classes.buildProxy(className, instance, deps)
	local classDef = Classes[className]
	if not classDef or not classDef.members then return {} end

	local data = { __type = className }

	for memberName, member in pairs(classDef.members) do
		if member.kind == "method" then
			data[memberName] = function(...)
				return member.impl(deps, instance, ...)
			end
		end
	end

	return setmetatable(data, {
		__index = function(_, key)
			local member = classDef.members[key]
			if member and member.kind == "prop" then
				return member.get(deps, instance)
			end
			return nil
		end
	})
end

return Classes
