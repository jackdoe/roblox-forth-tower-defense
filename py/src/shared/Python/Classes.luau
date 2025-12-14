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
			local GolemRegistry = deps.GolemRegistry
			if GolemRegistry and GolemRegistry.issueCommand then
				GolemRegistry.issueCommand(turret.id, "SET_RANGE", { range = range })
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
			local GolemRegistry = deps.GolemRegistry
			if GolemRegistry and GolemRegistry.fire then
				return GolemRegistry.fire(turret.id, ammoType)
			end
			return false
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

		forward = method({ T.NUMBER }, T.BOOL, function(deps, bot, steps)
			steps = steps or 10
			if not bot.character then return false end
			local hrp = bot.character:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			local facingAngle = bot.character:GetAttribute("FacingAngle") or 0
			local dirX = -math.sin(facingAngle)
			local dirZ = -math.cos(facingAngle)
			local targetX = hrp.Position.X + dirX * steps
			local targetZ = hrp.Position.Z + dirZ * steps

			local BotRegistry = deps.BotRegistry
			if BotRegistry and BotRegistry.issueCommand then
				local success = BotRegistry.issueCommand(bot.id, "MOVE", { x = targetX, z = targetZ }, true)
				if success and bot.interpreter then
					local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
					if vm and vm.block then vm:block() end
				end
				return success
			end
			return false
		end),

		backward = method({ T.NUMBER }, T.BOOL, function(deps, bot, steps)
			return Classes.Bot.members.forward.impl(deps, bot, -(steps or 10))
		end),

		left = method({ T.NUMBER }, T.BOOL, function(deps, bot, angle)
			angle = angle or 90
			if not bot.character then return false end
			local currentAngle = bot.character:GetAttribute("FacingAngle") or 0
			bot.character:SetAttribute("FacingAngle", currentAngle + math.rad(angle))
			return true
		end),

		right = method({ T.NUMBER }, T.BOOL, function(deps, bot, angle)
			return Classes.Bot.members.left.impl(deps, bot, -(angle or 90))
		end),

		teleport = method({ T.VECTOR }, T.BOOL, function(deps, bot, pos)
			if type(pos) ~= "table" or #pos ~= 2 then return false end
			local BotRegistry = deps.BotRegistry
			if not BotRegistry or not BotRegistry.issueCommand then return false end

			local coreX, coreZ = deps.getCoreOffset()
			return BotRegistry.issueCommand(bot.id, "TELEPORT", {
				x = pos[1] + coreX,
				z = pos[2] + coreZ
			}, true)
		end),

		shock = method({ T.ENEMY }, T.BOOL, function(deps, bot, target)
			local BotRegistry = deps.BotRegistry
			if not BotRegistry or not BotRegistry.issueCommand then return false end

			local enemyId = type(target) == "table" and target.id or target
			if not enemyId then return false end

			return BotRegistry.issueCommand(bot.id, "SHOCK", { enemyId = enemyId }, true)
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
			local BotRegistry = deps.BotRegistry
			if not BotRegistry or not BotRegistry.issueCommand then return false end

			local success = BotRegistry.issueCommand(bot.id, "COLLECT_NEAREST", {}, true)
			if success and bot.interpreter then
				local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
				if vm and vm.block then vm:block() end
			end
			return success
		end),

		explode = method({}, T.BOOL, function(deps, bot)
			local BotRegistry = deps.BotRegistry
			if not BotRegistry or not BotRegistry.issueCommand then return false end

			local cargo = bot.scrapInventory or 0
			if cargo < 10 then return false end

			local success = BotRegistry.issueCommand(bot.id, "EXPLODE", {}, true)
			if success and bot.interpreter then
				local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
				if vm and vm.block then vm:block() end
			end
			return success
		end),

		say = method({ T.STRING }, T.NIL, function(deps, bot, message)
			local BotRegistry = deps.BotRegistry
			if BotRegistry and BotRegistry.setChatBubble then
				BotRegistry.setChatBubble(bot.id, tostring(message))
			end
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
