-- GameAPI.luau
-- Python API for tower defense game commands
-- Refactored: DRY architecture with shared builders

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameAPI = {}

--============================================================================
-- CONSTANTS
--============================================================================

GameAPI.AmmoTypes = {
	BULLET = 1,
	ROCKET = 2,
	LASER = 3,
	ICE = 4,
	FREEZE = 5,
}

-- Color name to Color3 mapping
local COLOR_MAP = {
	red = Color3.fromRGB(200, 60, 60),
	blue = Color3.fromRGB(70, 130, 200),
	green = Color3.fromRGB(70, 180, 100),
	purple = Color3.fromRGB(150, 80, 180),
	yellow = Color3.fromRGB(220, 200, 70),
	cyan = Color3.fromRGB(70, 200, 200),
	orange = Color3.fromRGB(215, 135, 70),
}
local DEFAULT_COLOR = Color3.fromRGB(215, 135, 70)

--============================================================================
-- UTILITY FUNCTIONS
--============================================================================

-- Convert any value to Python-style string representation
local function pyToString(value, depth)
	depth = depth or 0
	if depth > 3 then return "..." end

	if value == nil then
		return "None"
	elseif type(value) == "boolean" then
		return value and "True" or "False"
	elseif type(value) == "string" then
		return '"' .. value .. '"'
	elseif type(value) == "number" then
		return tostring(value)
	elseif type(value) == "function" then
		return "<function>"
	elseif type(value) == "table" then
		-- Check for special markers
		if value._isNil then
			return "None"
		elseif value._undefined then
			return "<undefined: " .. (value._name or "?") .. ">"
		elseif value._isFunction then
			return "<function " .. (value.name or "?") .. ">"
		end

		-- Check if it's an array-like table
		local isArray = true
		local maxIndex = 0
		for k, _ in pairs(value) do
			if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
				isArray = false
				break
			end
			maxIndex = math.max(maxIndex, k)
		end

		if isArray and maxIndex > 0 then
			local parts = {}
			for i = 1, maxIndex do
				table.insert(parts, pyToString(value[i], depth + 1))
			end
			return "[" .. table.concat(parts, ", ") .. "]"
		else
			local parts = {}
			local count = 0
			for k, v in pairs(value) do
				if type(k) == "string" and not k:match("^_") then
					count = count + 1
					if count <= 5 then
						if type(v) == "function" then
							table.insert(parts, k .. "()")
						else
							table.insert(parts, k .. "=" .. pyToString(v, depth + 1))
						end
					end
				end
			end
			if count > 5 then
				table.insert(parts, "...")
			end
			return #parts > 0 and ("{" .. table.concat(parts, ", ") .. "}") or "{}"
		end
	else
		return tostring(value)
	end
end

GameAPI.pyToString = pyToString

-- Get list of method names from an object
local function getMethods(obj)
	if type(obj) ~= "table" then return {} end
	local methods = {}
	for k, v in pairs(obj) do
		if type(v) == "function" and type(k) == "string" and not k:match("^_") then
			table.insert(methods, k)
		end
	end
	table.sort(methods)
	return methods
end

GameAPI.getMethods = getMethods

-- Calculate distance between two points
local function calcDistance(x1, z1, x2, z2)
	local dx = x2 - x1
	local dz = z2 - z1
	return math.sqrt(dx * dx + dz * dz)
end

-- Get HRP position from a character
local function getCharacterPos(character, defaultX, defaultZ)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position.X, hrp.Position.Z
	end
	return defaultX or 0, defaultZ or 0
end

-- Apply color to bot character parts
local function applyBotColor(character, colorName)
	if not character then return end
	local col = COLOR_MAP[colorName] or DEFAULT_COLOR

	for _, partName in ipairs({"Torso", "Head", "LeftArm", "RightArm"}) do
		local part = character:FindFirstChild(partName)
		if part then part.Color = col end
	end
end

-- Display chat bubble on a character
local function showChatBubble(character, message)
	if not character then return end
	character:SetAttribute("ChatExpiry", tick() + 3)

	local chatHead = character:FindFirstChild("ChatHead")
	local chatBubble = chatHead and chatHead:FindFirstChild("ChatBubble")
	local bubble = chatBubble and chatBubble:FindFirstChild("Bubble")
	local textLabel = bubble and bubble:FindFirstChild("Text")
	if textLabel then
		textLabel.Text = tostring(message)
	end
end

--============================================================================
-- SHARED ENVIRONMENT BUILDERS
--============================================================================

-- Add common constants to an environment
local function addConstants(env)
	env.BULLET = 1
	env.ROCKET = 2
	env.LASER = 3
	env.ICE = 4
	env.GRENADE = 5
	env.FREEZE = 6
end

-- Add common utility functions to an environment
local function addUtilities(env, interp)
	env.len = function(t)
		if type(t) == "table" or type(t) == "string" then
			return #t
		end
		return 0
	end

	env.methods = function(obj)
		return getMethods(obj)
	end

	env.print = function(...)
		local args = {...}
		local parts = {}
		for _, v in ipairs(args) do
			table.insert(parts, pyToString(v))
		end
		local line = table.concat(parts, " ")

		-- Store output as array for history
		if type(interp.output) ~= "table" then
			interp.output = {}
		end
		table.insert(interp.output, line)

		-- Keep only last 50 lines
		while #interp.output > 50 do
			table.remove(interp.output, 1)
		end
	end

	-- Python built-ins
	env.range = function(startOrStop, stop, step)
		local result = {}
		local s, e, st
		if stop == nil then
			s, e, st = 0, startOrStop, 1
		elseif step == nil then
			s, e, st = startOrStop, stop, 1
		else
			s, e, st = startOrStop, stop, step
		end
		for i = s, e - 1, st do
			table.insert(result, i)
		end
		return result
	end

	env.abs = function(x) return math.abs(x or 0) end
	env.min = function(...) return math.min(...) end
	env.max = function(...) return math.max(...) end
	env.int = function(x) return math.floor(tonumber(x) or 0) end
	env.float = function(x) return tonumber(x) or 0 end
	env.str = function(x) return tostring(x) end
end

--============================================================================
-- PROXY BUILDERS (Lazy lookups for T1-T4, B1-B4)
--============================================================================

-- Create an enemy entity proxy (returned by T[n].target() for rich enemy info)
-- Allows code like: if T1.target().is_boss: self.teleport(T1.target())
local function createEnemyProxy(enemy, deps)
	if not enemy then return nil end

	local EnemyManager = deps.EnemyManager
	local WaveManager = deps.WaveManager

	-- Get core position for coordinate transformation
	local function getCoreOffset()
		if WaveManager and WaveManager.getCorePosition then
			local corePos = WaveManager.getCorePosition()
			if corePos then
				return corePos.x or 150, corePos.z or 150
			end
		end
		return 150, 150
	end

	local proxy = {
		__type = "Entity",  -- For type checking in teleport
		id = enemy.id,

		-- Properties (Python-style: is_boss, is_tank, etc.)
		is_boss = (enemy.typeName == "Boss"),
		is_tank = (enemy.typeName == "Tank"),
		is_runner = (enemy.typeName == "Runner"),
		type = enemy.typeName or "Zombie",
		hp = enemy.hp or 0,
		max_hp = enemy.maxHp or 1,

		-- Status effects
		burning = enemy.burning or false,
		frozen = (enemy.slowAmount and enemy.slowAmount >= 0.5) or false,
		slowed = (enemy.slowAmount and enemy.slowAmount > 0) or false,
		oiled = enemy.oiled or false,
	}

	-- position as property (world coords, returns {x, z})
	local function getPosition()
		-- Refresh enemy data
		local e = EnemyManager and EnemyManager.get and EnemyManager.get(enemy.id)
		if e and e.character then
			local hrp = e.character:FindFirstChild("HumanoidRootPart") or e.character.PrimaryPart
			if hrp then
				local coreX, coreZ = getCoreOffset()
				return {hrp.Position.X - coreX, hrp.Position.Z - coreZ}
			end
		end
		return {0, 0}
	end

	-- Make position a function call for consistency
	proxy.position = getPosition

	-- world_position returns absolute coords (for internal use)
	proxy.world_position = function()
		local e = EnemyManager and EnemyManager.get and EnemyManager.get(enemy.id)
		if e and e.character then
			local hrp = e.character:FindFirstChild("HumanoidRootPart") or e.character.PrimaryPart
			if hrp then
				return {hrp.Position.X, hrp.Position.Z}
			end
		end
		return {0, 0}
	end

	-- alive() - check if enemy is still alive
	proxy.alive = function()
		local e = EnemyManager and EnemyManager.get and EnemyManager.get(enemy.id)
		return e and e.hp and e.hp > 0
	end

	return proxy
end

-- Create a turret proxy (used by bot/player environments for T1-T4, and for turret's self)
-- If directGolem is provided, uses that instead of looking up by spotId
local function createTurretProxy(spotId, deps, directGolem)
	local GolemRegistry = deps.GolemRegistry
	local EnemyManager = deps.EnemyManager
	local WaveManager = deps.WaveManager
	local proxy = {}

	-- Get core position for coordinate transformation (0,0 = core)
	local function getCoreOffset()
		if WaveManager and WaveManager.getCorePosition then
			local corePos = WaveManager.getCorePosition()
			if corePos then
				return corePos.x or 150, corePos.z or 150
			end
		end
		return 150, 150  -- Default core position
	end

	-- Transform world coords to user coords (relative to core)
	local function toUserCoords(worldX, worldZ)
		local coreX, coreZ = getCoreOffset()
		return worldX - coreX, worldZ - coreZ
	end

	local function getGolem()
		if directGolem then return directGolem end
		return GolemRegistry and GolemRegistry.getBySpotId and GolemRegistry.getBySpotId(spotId)
	end

	-- Turrets are always alive (no HP system)
	local function isAlive()
		return getGolem() ~= nil
	end

	-- Basic properties
	proxy.exists = function() return getGolem() ~= nil end
	proxy.alive = function() return isAlive() end
	proxy.spot = function() return spotId end

	proxy.id = function()
		local golem = getGolem()
		return golem and golem.id
	end

	proxy.position = function()
		local golem = getGolem()
		if golem and golem.character then
			local worldX, worldZ = getCharacterPos(golem.character)
			local userX, userZ = toUserCoords(worldX, worldZ)
			return {userX, userZ}
		end
		return {0, 0}
	end

	proxy.ammo = function()
		local golem = getGolem()
		return golem and golem.interpreter and (golem.interpreter.ammo or 0) or 0
	end

	proxy.max_ammo = function()
		local golem = getGolem()
		return golem and golem.interpreter and (golem.interpreter.maxAmmo or 300) or 300
	end

	proxy.range = function()
		local golem = getGolem()
		return golem and golem.interpreter and (golem.interpreter.dynamicRange or 40) or 40
	end

	proxy.is_empty = function()
		return proxy.ammo() <= 0
	end

	proxy.ammo_ratio = function()
		local max = proxy.max_ammo()
		return max > 0 and (proxy.ammo() / max) or 0
	end

	-- Commands
	proxy.set_range = function(range)
		local golem = getGolem()
		if golem and GolemRegistry.issueCommand then
			return GolemRegistry.issueCommand(golem.id, "SET_RANGE", { range = range })
		end
		return false
	end

	proxy.scan = function()
		local golem = getGolem()
		if not golem or not golem.character then return {} end
		local x, z = getCharacterPos(golem.character)
		local range = golem.interpreter and (golem.interpreter.dynamicRange or 40) or 40

		if EnemyManager and EnemyManager.findInRange then
			local enemies = EnemyManager.findInRange(x, z, range)
			local results = {}
			for _, e in ipairs(enemies) do
				-- Return enemy objects with id, type, hp, and status effects
				table.insert(results, {
					id = e.id,
					type = e.typeName or "Zombie",  -- Enemy type (Zombie, Runner, Tank, Boss)
					hp = e.hp or 0,
					max_hp = e.maxHp or 1,
					-- Status effects (for bot combos)
					burning = e.burning or false,  -- From LASER
					frozen = (e.slowAmount and e.slowAmount >= 0.5) or false,  -- From ICE (heavily slowed)
					slowed = (e.slowAmount and e.slowAmount > 0) or false,  -- Any slow effect
					oiled = e.oiled or false,  -- From ROCKET (for shock combo)
				})
			end
			return results
		end
		return {}
	end

	proxy.fire = function(enemy, ammoType)
		local golem = getGolem()
		if not golem then return false end
		if not isAlive() then return false end

		ammoType = ammoType or 1
		if enemy and enemy.id and golem.interpreter then
			golem.interpreter.target = enemy.id
		end
		if GolemRegistry and GolemRegistry.fire then
			return GolemRegistry.fire(golem.id, ammoType)
		end
		return false
	end

	proxy.danger = function()
		local golem = getGolem()
		if not golem or not golem.character then return 9999 end
		local x, z = getCharacterPos(golem.character)
		if EnemyManager and EnemyManager.findNearest then
			local enemy, dist = EnemyManager.findNearest(x, z, 100)
			if enemy then return dist end
		end
		return 9999
	end

	-- Get current target as an entity proxy
	-- Returns an enemy proxy with is_boss, position(), hp, etc.
	-- Usage: target = T1.target(); if target and target.is_boss: ...
	proxy.target = function()
		local golem = getGolem()
		if not golem or not golem.interpreter then return nil end

		local targetId = golem.interpreter.target
		if not targetId then return nil end

		if EnemyManager and EnemyManager.get then
			local enemy = EnemyManager.get(targetId)
			if enemy and enemy.hp and enemy.hp > 0 then
				return createEnemyProxy(enemy, deps)
			end
		end
		return nil
	end

	proxy.methods = function()
		return getMethods(proxy)
	end

	-- Reload ammo from core stockpile
	-- BLOCKING: waits until stockpile has resources, then delays based on amount
	-- Delay formula: 1 second base + amount/50 seconds (so reload(50) = 2s, reload(200) = 5s)
	-- Returns amount reloaded
	proxy.reload = function(amount)
		local golem = getGolem()
		if not golem or not isAlive() then return 0 end

		local interp = golem.interpreter
		if not interp then return 0 end

		-- Calculate how much we need
		local needed = (interp.maxAmmo or 300) - (interp.ammo or 0)
		if needed <= 0 then return 0 end

		-- Amount to try to reload (default: fill up)
		amount = amount or needed
		local toReload = math.min(amount, needed)

		-- Set up blocking reload state
		-- The reload happens over time, checking stockpile each tick
		interp.reloadPending = {
			amount = toReload,
			startTime = tick(),
			-- Delay: 1 second base + amount/50 (faster for small amounts)
			duration = 1 + (toReload / 50),
			collected = 0,
		}

		-- Block the VM (if this is called from the golem's own environment)
		local vm = interp.runtime and interp.runtime.vm
		if vm and vm.block then
			vm:block()
		end

		return toReload  -- Returns expected amount (actual collection happens over time)
	end

	-- Check reload cooldown remaining (now shows reload progress)
	proxy.reload_cooldown = function()
		local golem = getGolem()
		if not golem then return 0 end

		local interp = golem.interpreter
		if not interp or not interp.reloadPending then return 0 end

		local elapsed = tick() - interp.reloadPending.startTime
		local remaining = interp.reloadPending.duration - elapsed
		return remaining > 0 and math.ceil(remaining) or 0
	end

	return proxy
end

-- Create a bot proxy (used by player environment for B1-B4, and for bot's self)
-- If directBot is provided, uses that instead of looking up by spotId
local function createBotProxy(spotId, deps, directBot)
	local BotRegistry = deps.BotRegistry
	local ScrapManager = deps.ScrapManager
	local EnemyManager = deps.EnemyManager
	local WaveManager = deps.WaveManager
	local proxy = {}

	-- Get core position for coordinate transformation (0,0 = core)
	local function getCoreOffset()
		if WaveManager and WaveManager.getCorePosition then
			local corePos = WaveManager.getCorePosition()
			if corePos then
				return corePos.x or 150, corePos.z or 150
			end
		end
		return 150, 150  -- Default core position
	end

	-- Transform world coords to user coords (relative to core)
	local function toUserCoords(worldX, worldZ)
		local coreX, coreZ = getCoreOffset()
		return worldX - coreX, worldZ - coreZ
	end

	-- Transform user coords to world coords
	local function toWorldCoords(userX, userZ)
		local coreX, coreZ = getCoreOffset()
		return userX + coreX, userZ + coreZ
	end

	local function getBot()
		if directBot then return directBot end
		return BotRegistry and BotRegistry.getBySpotId and BotRegistry.getBySpotId(spotId)
	end

	-- Bots are always alive (no HP system)
	local function isAlive()
		return getBot() ~= nil
	end

	-- Basic properties
	proxy.exists = function() return getBot() ~= nil end
	proxy.spot = function() return spotId end

	proxy.id = function()
		local bot = getBot()
		return bot and bot.id
	end

	proxy.position = function()
		local bot = getBot()
		if bot and bot.character then
			local worldX, worldZ = getCharacterPos(bot.character)
			local userX, userZ = toUserCoords(worldX, worldZ)
			return {userX, userZ}
		end
		return {0, 0}
	end

	proxy.cargo = function()
		local bot = getBot()
		return bot and (bot.scrapInventory or 0) or 0
	end

	proxy.max_cargo = function()
		local bot = getBot()
		return bot and (bot.maxCapacity or 50) or 50
	end

	-- State queries
	proxy.is_idle = function()
		local bot = getBot()
		return bot and BotRegistry.isIdle and BotRegistry.isIdle(bot.id) or true
	end

	proxy.is_full = function()
		local bot = getBot()
		return bot and (bot.scrapInventory or 0) >= (bot.maxCapacity or 50) or false
	end

	proxy.is_moving = function()
		local bot = getBot()
		return bot and bot.isMoving or false
	end

	proxy.alive = function()
		return isAlive()
	end

	proxy.status = function()
		local bot = getBot()
		return bot and (bot.status or "IDLE") or "NONE"
	end

	-- Movement commands (blocking - interpreter waits until movement completes)
	-- Coordinates are relative to core (0,0 = core position)
	proxy.move = function(x, z)
		if type(x) == "table" then
			z = x[2]
			x = x[1]
		end
		local bot = getBot()
		-- Don't allow movement if dead (but not cleaned up yet)
		if not bot or not isAlive() then return false end
		if BotRegistry.issueCommand and x and z then
			-- Transform user coords to world coords
			local worldX, worldZ = toWorldCoords(x, z)
			local success = BotRegistry.issueCommand(bot.id, "MOVE", { x = worldX, z = worldZ }, true)
			-- Block the VM until movement completes
			if success and bot.interpreter then
				local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
				if vm and vm.block then
					vm:block()
				end
			end
			return success
		end
		return false
	end

	proxy.goto = function(target, z)
		-- Accept raw coordinates: goto(x, z)
		if type(target) == "number" and type(z) == "number" then
			return proxy.move(target, z)
		end
		-- Accept array: goto([x, z])
		if type(target) == "table" and target[1] and target[2] then
			return proxy.move(target[1], target[2])
		end
		-- Accept object with position method: goto(T1)
		if type(target) == "table" and target.position then
			local pos = target.position()
			return proxy.move(pos[1], pos[2])
		end
		return false
	end

	proxy.stop = function()
		local bot = getBot()
		if bot and BotRegistry.clearCommands then
			BotRegistry.clearCommands(bot.id)
		end
	end

	proxy.flee = function()
		return proxy.move(0, 0)
	end

	-- collect(pos) - Move to position [x,z], collect ANY scrap in pickup range, return to core to deposit
	-- BLOCKING: VM waits until entire collect cycle completes (go to area -> pick up nearby -> return -> deposit)
	-- If the specific scrap is gone, will still pick up any other scrap in the area
	proxy.collect = function(pos)
		local bot = getBot()
		if not bot or not isAlive() then return false end

		-- Accept [x, z] position from scraps() - this is a hint for where to go
		if type(pos) == "table" and pos[1] and pos[2] then
			local worldX, worldZ = toWorldCoords(pos[1], pos[2])
			if BotRegistry.issueCommand then
				local success = BotRegistry.issueCommand(bot.id, "COLLECT_AREA", { x = worldX, z = worldZ }, true)
				-- Block the VM until collect task completes
				if success and bot.interpreter then
					local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
					if vm and vm.block then
						vm:block()
					end
				end
				return success
			end
		end
		return false
	end

	-- collect_nearest() - Find and collect the nearest scrap (does NOT return to core)
	-- BLOCKING: VM waits until bot reaches scrap and picks it up
	-- Use supply(CORE) separately to deposit, or explode() to use as fuel
	proxy.collect_nearest = function()
		local bot = getBot()
		if not bot or not isAlive() then return false end

		-- Find nearest scrap from bot's current position
		local hrp = bot.character and bot.character:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end

		local scrap = ScrapManager and ScrapManager.findNearest(hrp.Position.X, hrp.Position.Z)
		if not scrap or not scrap.part then return false end

		-- Go to that scrap's position and pick it up
		local worldX, worldZ = scrap.part.Position.X, scrap.part.Position.Z
		if BotRegistry.issueCommand then
			local success = BotRegistry.issueCommand(bot.id, "COLLECT_AREA", { x = worldX, z = worldZ }, true)
			-- Block the VM until collect task completes
			if success and bot.interpreter then
				local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
				if vm and vm.block then
					vm:block()
				end
			end
			return success
		end
		return false
	end

	-- supply(CORE) - Go to core and deposit all carried scrap
	-- BLOCKING: VM waits until bot reaches core and deposits
	proxy.supply = function(target)
		local bot = getBot()
		if not bot or not isAlive() then return false end

		-- For now, only CORE is supported as target
		-- target can be the CORE constant or nil (defaults to core)
		if BotRegistry.issueCommand then
			local success = BotRegistry.issueCommand(bot.id, "SUPPLY_CORE", {}, true)
			-- Block the VM until supply task completes
			if success and bot.interpreter then
				local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
				if vm and vm.block then
					vm:block()
				end
			end
			return success
		end
		return false
	end

	proxy.scan = function()
		local bot = getBot()
		if not bot or not bot.character or not ScrapManager then return nil end

		local x, z = getCharacterPos(bot.character)
		local scrap = ScrapManager.findNearest(x, z)
		if scrap and scrap.part and scrap.part.Parent then
			-- Return user coords (relative to core)
			local userX, userZ = toUserCoords(scrap.part.Position.X, scrap.part.Position.Z)
			return {userX, userZ}
		end
		return nil
	end

	-- Danger / Survival
	proxy.danger = function()
		local bot = getBot()
		if not bot or not bot.character then return 9999 end
		local x, z = getCharacterPos(bot.character)

		if EnemyManager and EnemyManager.findNearest then
			local enemy, dist = EnemyManager.findNearest(x, z, 50)
			if enemy then return dist end
		end
		return 9999
	end

	proxy.shield = function(duration)
		local bot = getBot()
		if bot and BotRegistry.activateShield then
			return BotRegistry.activateShield(bot.id, duration or 3)
		end
		return false
	end

	proxy.shielded = function()
		local bot = getBot()
		return bot and bot.shieldActive or false
	end

	proxy.shield_ready = function()
		local bot = getBot()
		if not bot or bot.shieldActive then return false end
		if bot.shieldCooldownUntil and tick() < bot.shieldCooldownUntil then
			return false
		end
		return true
	end

	-- Shock attack! Moves to enemy, then shocks. Combos with ROCKET (oiled) and LASER (burning)
	-- BLOCKING: Bot moves to enemy, shocks, then is stunned for 2 seconds.
	-- Accepts: enemy object from scan() (has .id), or raw enemy ID
	-- Returns true if shock was executed, false if failed
	proxy.shock = function(target)
		local bot = getBot()
		if not bot or not isAlive() then return false end
		if not BotRegistry or not BotRegistry.issueCommand then return false end

		-- Extract enemy ID from target object or use directly
		local enemyId = target
		if type(target) == "table" and target.id then
			enemyId = target.id
		end
		if not enemyId then return false end

		-- Issue SHOCK command - includes move-to-enemy + shock + stun
		-- The BotRegistry handles the movement and shocking sequence
		return BotRegistry.issueCommand(bot.id, "SHOCK", { enemyId = enemyId }, true)
	end

	-- Explode! Use carried scrap as fuel for AOE damage
	-- BLOCKING: Bot explodes, deals damage to all enemies in range, loses cargo
	-- Damage = cargo * 2, Range = 15 studs
	-- Requires at least 10 scrap to explode
	-- Bot survives but is stunned briefly after exploding
	proxy.explode = function()
		local bot = getBot()
		if not bot or not isAlive() then return false end
		if not BotRegistry or not BotRegistry.issueCommand then return false end

		-- Check if we have enough scrap
		local cargo = bot.scrapInventory or 0
		if cargo < 10 then
			return false
		end

		-- Issue EXPLODE command
		local success = BotRegistry.issueCommand(bot.id, "EXPLODE", {}, true)
		-- Block the VM until explode completes (including stun)
		if success and bot.interpreter then
			local vm = bot.interpreter.runtime and bot.interpreter.runtime.vm
			if vm and vm.block then
				vm:block()
			end
		end
		return success
	end

	proxy.distance = function(target)
		local bot = getBot()
		if not bot or not bot.character then return 9999 end
		local bx, bz = getCharacterPos(bot.character)

		local tx, tz
		if type(target) == "table" then
			if target.position then
				local pos = target.position()
				tx, tz = pos[1], pos[2]
			elseif target[1] and target[2] then
				tx, tz = target[1], target[2]
			end
		end

		if tx and tz then
			return calcDistance(bx, bz, tx, tz)
		end
		return 9999
	end

	-- Personality
	proxy.say = function(message)
		local bot = getBot()
		if bot then
			showChatBubble(bot.character, message)
		end
	end

	proxy.emote = function(emoteType)
		local bot = getBot()
		if not bot or not bot.character then return end
		local char = bot.character

		if emoteType == "happy" then
			local baseY = char:GetAttribute("BaseY") or 2.5
			task.spawn(function()
				char:SetAttribute("BaseY", baseY + 1.5)
				task.wait(0.2)
				char:SetAttribute("BaseY", baseY)
			end)
		elseif emoteType == "panic" then
			local head = char:FindFirstChild("Head")
			if head then
				local lEye = head:FindFirstChild("LeftEye")
				local rEye = head:FindFirstChild("RightEye")
				if lEye and rEye then
					local oldColor = lEye.Color
					lEye.Color = Color3.fromRGB(255, 50, 50)
					rEye.Color = Color3.fromRGB(255, 50, 50)
					task.delay(1.5, function()
						if lEye and lEye.Parent then lEye.Color = oldColor end
						if rEye and rEye.Parent then rEye.Color = oldColor end
					end)
				end
			end
		elseif emoteType == "spin" then
			task.spawn(function()
				local startAngle = char:GetAttribute("FacingAngle") or 0
				for i = 1, 20 do
					char:SetAttribute("FacingAngle", startAngle + (i / 20) * math.pi * 2)
					task.wait(0.02)
				end
				char:SetAttribute("FacingAngle", startAngle)
			end)
		end
	end

	-- =========================================================
	-- TURTLE-STYLE MOVEMENT (Like Python turtle!)
	-- =========================================================

	-- forward(steps) - Move forward in facing direction (blocking)
	proxy.forward = function(steps)
		steps = steps or 10
		local bot = getBot()
		if not bot or not isAlive() or not bot.character then return false end
		local hrp = bot.character:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end

		-- Get current facing direction from FacingAngle attribute
		local facingAngle = bot.character:GetAttribute("FacingAngle") or 0

		-- Calculate target position in world coords
		local dirX = -math.sin(facingAngle)
		local dirZ = -math.cos(facingAngle)
		local targetX = hrp.Position.X + dirX * steps
		local targetZ = hrp.Position.Z + dirZ * steps

		if BotRegistry and BotRegistry.issueCommand then
			return BotRegistry.issueCommand(bot.id, "MOVE", { x = targetX, z = targetZ }, true)
		end
		return false
	end

	-- backward(steps) - Move backward (blocking)
	proxy.backward = function(steps)
		return proxy.forward(-(steps or 10))
	end

	-- left(angle) - Turn left (in degrees)
	proxy.left = function(angle)
		angle = angle or 90
		local bot = getBot()
		if not bot or not bot.character then return false end

		local currentAngle = bot.character:GetAttribute("FacingAngle") or 0
		local newAngle = currentAngle + math.rad(angle)
		bot.character:SetAttribute("FacingAngle", newAngle)
		return true
	end

	-- right(angle) - Turn right (in degrees)
	proxy.right = function(angle)
		return proxy.left(-(angle or 90))
	end

	-- =========================================================
	-- SCRAP COLLECTION
	-- =========================================================

	-- scraps() - Returns list of [x, z] positions sorted by distance (closest first)
	proxy.scraps = function()
		local bot = getBot()
		if not bot or not bot.character or not ScrapManager then return {} end

		local x, z = getCharacterPos(bot.character)
		local allScraps = ScrapManager.getAll and ScrapManager.getAll() or {}

		-- Build list with distances
		local temp = {}
		for _, scrap in pairs(allScraps) do
			if scrap and scrap.part and scrap.part.Parent then
				local sPos = scrap.part.Position
				local dx = sPos.X - x
				local dz = sPos.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				-- Convert to user coords (relative to core)
				local userX, userZ = toUserCoords(sPos.X, sPos.Z)
				table.insert(temp, {
					pos = {math.floor(userX), math.floor(userZ)},
					dist = dist,
				})
			end
		end

		-- Sort by distance (closest first)
		table.sort(temp, function(a, b) return a.dist < b.dist end)

		-- Return just the positions
		local result = {}
		for _, item in ipairs(temp) do
			table.insert(result, item.pos)
		end
		return result
	end

	proxy.methods = function()
		return getMethods(proxy)
	end

	return proxy
end

-- Add lazy-loaded T[n] turret proxies (T1-T30) using metatable
-- Instead of creating 30 proxies upfront, we create them on-demand when accessed
-- This saves memory when only a few turrets are used
local function addLazyTurretProxies(env, deps)
	-- Cache for already-created proxies
	local turretProxyCache = {}

	-- Set metatable for lazy loading
	local mt = getmetatable(env) or {}
	local oldIndex = mt.__index

	mt.__index = function(t, key)
		-- Check for T[n] pattern (T1, T2, ... T30)
		local spotId = string.match(key, "^T(%d+)$")
		if spotId then
			local num = tonumber(spotId)
			if num and num >= 1 and num <= 30 then
				-- Return cached proxy or create new one
				if not turretProxyCache[num] then
					turretProxyCache[num] = createTurretProxy(num, deps)
				end
				return turretProxyCache[num]
			end
		end

		-- Fall back to previous __index if it exists
		if oldIndex then
			if type(oldIndex) == "function" then
				return oldIndex(t, key)
			else
				return oldIndex[key]
			end
		end
		return nil
	end

	setmetatable(env, mt)
end

-- Alias for clarity
local addTurretProxies = addLazyTurretProxies

-- Add B1-B4 bot proxies to an environment
local function addBotProxies(env, deps)
	env.B1 = createBotProxy(1, deps)
	env.B2 = createBotProxy(2, deps)
	env.B3 = createBotProxy(3, deps)
	env.B4 = createBotProxy(4, deps)
end

-- Add CORE reference
local function addCore(env, deps)
	local WaveManager = deps.WaveManager
	env.CORE = {
		position = function() return {0, 0} end,
		hp = function()
			return WaveManager and WaveManager.getCoreHealth and WaveManager.getCoreHealth() or 100
		end,
		max_hp = function() return 100 end,
	}
end

--============================================================================
-- GOLEM (TURRET) ENVIRONMENT
--============================================================================

function GameAPI.createGolemEnvironment(golem, deps)
	local interp = golem.interpreter
	local EnemyManager = deps.EnemyManager

	local env = {}

	-- Use the same proxy as T1-T4, but with direct golem reference
	local selfObj = createTurretProxy(golem.spotId, deps, golem)
	env.self = selfObj

	-- Helper for enemy position lookups
	local function getGolemPos()
		return getCharacterPos(golem.character, 150, 150)
	end

	local function getEnemyPos(enemyId)
		if EnemyManager and EnemyManager.get then
			local enemy = EnemyManager.get(enemyId)
			if enemy and enemy.character then
				local hrp = enemy.character:FindFirstChild("HumanoidRootPart") or enemy.character.PrimaryPart
				if hrp then
					return hrp.Position.X, hrp.Position.Z
				end
			end
		end
		return nil, nil
	end

	-- Enemy targeting utilities (turret-specific helpers)
	-- These now work with enemy objects from scan() which have {id, type, hp, max_hp}
	env.nearest = function(enemyList)
		enemyList = enemyList or selfObj.scan()
		if #enemyList == 0 then return nil end

		local gx, gz = getGolemPos()
		local nearestEnemy, nearestDist = nil, math.huge

		for _, enemy in ipairs(enemyList) do
			local ex, ez = getEnemyPos(enemy.id)
			if ex then
				local dist = calcDistance(gx, gz, ex, ez)
				if dist < nearestDist then
					nearestDist = dist
					nearestEnemy = enemy
				end
			end
		end
		return nearestEnemy
	end

	env.weakest = function(enemyList)
		enemyList = enemyList or selfObj.scan()
		if #enemyList == 0 then return nil end

		local weakestEnemy, lowestHp = nil, math.huge
		for _, enemy in ipairs(enemyList) do
			if enemy.hp < lowestHp then
				lowestHp = enemy.hp
				weakestEnemy = enemy
			end
		end
		return weakestEnemy
	end

	env.strongest = function(enemyList)
		enemyList = enemyList or selfObj.scan()
		if #enemyList == 0 then return nil end

		local strongestEnemy, highestHp = nil, 0
		for _, enemy in ipairs(enemyList) do
			if enemy.hp > highestHp then
				highestHp = enemy.hp
				strongestEnemy = enemy
			end
		end
		return strongestEnemy
	end

	-- Add shared functionality
	addConstants(env)
	addUtilities(env, interp)

	return env
end

--============================================================================
-- BOT ENVIRONMENT
--============================================================================

function GameAPI.createBotEnvironment(bot, deps)
	local env = {}
	local BotRegistry = deps.BotRegistry
	local ScrapManager = deps.ScrapManager
	local GolemRegistry = deps.GolemRegistry
	local EnemyManager = deps.EnemyManager
	local WaveManager = deps.WaveManager

	-- Use the same proxy as B1-B4, but with direct bot reference
	env.self = createBotProxy(bot.spotId, deps, bot)

	-- Helper to get fresh bot reference
	local function getBot()
		return BotRegistry and BotRegistry.get and BotRegistry.get(bot.id)
	end

	-- Helper to get bot's HRP
	local function getHRP()
		local b = getBot()
		if b and b.character then
			return b.character:FindFirstChild("HumanoidRootPart")
		end
		return nil
	end

	-- =========================================================
	-- VISUAL & FUN METHODS (Instant gratification for kids!)
	-- =========================================================

	-- self.say("Hello!") - Shows a chat bubble above the bot
	env.self.say = function(message)
		if BotRegistry and BotRegistry.setChatBubble then
			return BotRegistry.setChatBubble(bot.id, tostring(message))
		end
		return false
	end

	-- self.dance() - Makes the bot spin
	env.self.dance = function()
		if BotRegistry and BotRegistry.playEmote then
			return BotRegistry.playEmote(bot.id, "dance")
		end
		return false
	end

	-- self.jump() - Makes the bot hop
	env.self.jump = function()
		if BotRegistry and BotRegistry.playEmote then
			return BotRegistry.playEmote(bot.id, "jump")
		end
		return false
	end

	-- self.shake() - Makes the bot shake/shiver
	env.self.shake = function()
		if BotRegistry and BotRegistry.playEmote then
			return BotRegistry.playEmote(bot.id, "shake")
		end
		return false
	end

	-- =========================================================
	-- HIGH-LEVEL "MACRO" METHODS (Easy for kids - no coordinates!)
	-- Note: forward/backward/left/right/scraps are in the proxy
	-- =========================================================

	-- self.go_home() - Move to the core (blocking)
	env.self.go_home = function()
		local coreX, coreZ = 150, 150
		if WaveManager and WaveManager.getCorePosition then
			local corePos = WaveManager.getCorePosition()
			if corePos then
				coreX = corePos.x or 150
				coreZ = corePos.z or 150
			end
		end
		if BotRegistry and BotRegistry.issueCommand then
			return BotRegistry.issueCommand(bot.id, "MOVE", { x = coreX, z = coreZ }, true)
		end
		return false
	end

	-- self.goto(target) - Go to a turret or position (blocking)
	env.self.goto = function(target)
		if not target then return false end

		-- If target has a position method (like T1), use it
		if type(target) == "table" and target.position then
			local pos = target.position()
			if pos then
				-- Position is already in world coords from the proxy
				local coreX, coreZ = 150, 150
				if WaveManager and WaveManager.getCorePosition then
					local corePos = WaveManager.getCorePosition()
					if corePos then
						coreX = corePos.x or 150
						coreZ = corePos.z or 150
					end
				end
				local worldX = pos[1] + coreX
				local worldZ = pos[2] + coreZ
				if BotRegistry and BotRegistry.issueCommand then
					return BotRegistry.issueCommand(bot.id, "MOVE", { x = worldX, z = worldZ }, true)
				end
			end
		end
		return false
	end

	-- self.wait(seconds) - Wait for some time
	env.self.wait = function(seconds)
		if BotRegistry and BotRegistry.issueCommand then
			return BotRegistry.issueCommand(bot.id, "IDLE", { duration = seconds or 1 }, true)
		end
		return false
	end

	-- self.teleport(target) - Instant teleport to target
	-- target can be: entity proxy (T1.target()), turret proxy (T1), or {x, z} coords
	-- Usage: self.teleport(T1.target())  -- teleport to enemy
	--        self.teleport(T1)           -- teleport to turret position
	--        self.teleport({10, 20})     -- teleport to coordinates
	env.self.teleport = function(target)
		if not target then return false end
		if not BotRegistry or not BotRegistry.issueCommand then return false end

		-- Handle different target types
		if type(target) == "table" then
			-- Entity proxy with world_position (from T1.target())
			if target.__type == "Entity" then
				return BotRegistry.issueCommand(bot.id, "TELEPORT", { target = target }, true)
			-- Turret/bot proxy with position function
			elseif target.position and type(target.position) == "function" then
				local pos = target.position()
				if pos then
					local coreX, coreZ = 150, 150
					if WaveManager and WaveManager.getCorePosition then
						local corePos = WaveManager.getCorePosition()
						if corePos then
							coreX = corePos.x or 150
							coreZ = corePos.z or 150
						end
					end
					return BotRegistry.issueCommand(bot.id, "TELEPORT", {
						x = pos[1] + coreX,
						z = pos[2] + coreZ
					}, true)
				end
			-- Raw coordinates {x, z}
			elseif #target == 2 then
				local coreX, coreZ = 150, 150
				if WaveManager and WaveManager.getCorePosition then
					local corePos = WaveManager.getCorePosition()
					if corePos then
						coreX = corePos.x or 150
						coreZ = corePos.z or 150
					end
				end
				return BotRegistry.issueCommand(bot.id, "TELEPORT", {
					x = target[1] + coreX,
					z = target[2] + coreZ
				}, true)
			end
		end
		return false
	end

	-- =========================================================
	-- COMBAT ABILITIES (For aggressive playstyles)
	-- =========================================================

	-- self.explode() - Kamikaze attack! Bot dies but damages nearby enemies
	env.self.explode = function(damage)
		env.self.say("BOOM!")
		if BotRegistry and BotRegistry.triggerExplosion then
			return BotRegistry.triggerExplosion(bot.id, damage or 200)
		end
		return false
	end

	-- self.zap() - Short range electric shock to nearest enemy
	env.self.zap = function()
		if BotRegistry and BotRegistry.zapEnemy then
			return BotRegistry.zapEnemy(bot.id, 10)
		end
		return false
	end

	-- self.attack() - Attack nearest enemy (uses zap)
	env.self.attack = function()
		return env.self.zap()
	end

	-- =========================================================
	-- SENSOR METHODS (What can I see?)
	-- =========================================================

	-- self.enemies_nearby() - Count enemies within range
	env.self.enemies_nearby = function(range)
		if not EnemyManager or not EnemyManager.findInRange then return 0 end
		local hrp = getHRP()
		if not hrp then return 0 end

		local enemies = EnemyManager.findInRange(hrp.Position.X, hrp.Position.Z, range or 20)
		return #enemies
	end

	-- self.scrap_nearby() - Is there scrap within range?
	env.self.scrap_nearby = function(range)
		if not ScrapManager then return false end
		local hrp = getHRP()
		if not hrp then return false end

		local scrap = ScrapManager.findNearest(hrp.Position.X, hrp.Position.Z)
		if scrap and scrap.part and scrap.part.Parent then
			local sPos = scrap.part.Position
			local dx = sPos.X - hrp.Position.X
			local dz = sPos.Z - hrp.Position.Z
			local dist = math.sqrt(dx * dx + dz * dz)
			return dist <= (range or 50)
		end
		return false
	end

	-- Add turret references (T1-T4) for bot scripts
	addTurretProxies(env, deps)
	addCore(env, deps)
	addConstants(env)
	addUtilities(env, bot.interpreter or { output = "", runtime = {} })

	return env
end

--============================================================================
-- PLAYER ENVIRONMENT
--============================================================================

function GameAPI.createPlayerEnvironment(player, interp, deps)
	local ScrapManager = deps.ScrapManager
	local GolemRegistry = deps.GolemRegistry
	local WaveManager = deps.WaveManager

	local env = {}
	env.self = {}

	-- Helper to get player position
	local function getPlayerPos()
		local char = interp.character
		return getCharacterPos(char, 150, 150)
	end

	-- Helper to get HRP
	local function getHRP()
		local char = interp.character
		if char then
			return char:FindFirstChild("HumanoidRootPart")
		end
		return nil
	end

	-- Get core position for coordinate transformation
	local function getCoreOffset()
		if WaveManager and WaveManager.getCorePosition then
			local corePos = WaveManager.getCorePosition()
			if corePos then
				return corePos.x or 150, corePos.z or 150
			end
		end
		return 150, 150
	end

	-- Internal move function (uses world coords)
	-- Sends event to client for smooth movement with woosh effect
	-- BLOCKING: VM waits until client signals movement complete
	local function moveInternal(x, z)
		if not x or not z then return end

		local vm = interp.runtime and interp.runtime.vm
		local PythonTD = ReplicatedStorage:FindFirstChild("PythonTD")
		local teleportEvent = PythonTD and PythonTD:FindFirstChild("PlayerTeleport")

		if teleportEvent and interp.player then
			-- Block VM until movement completes
			if vm then vm:block() end
			teleportEvent:FireClient(interp.player, x, z)
		end
	end

	-- =========================================================
	-- SELF METHODS (player calls these with self.method())
	-- =========================================================

	-- self.position() - Get player's position relative to core
	env.self.position = function()
		local x, z = getPlayerPos()
		local coreX, coreZ = getCoreOffset()
		return {x - coreX, z - coreZ}
	end

	-- self.cargo() - Get scrap inventory
	env.self.cargo = function()
		return interp.scrapInventory or 0
	end

	-- self.max_cargo() - Get max capacity
	env.self.max_cargo = function()
		return interp.maxCapacity or 50
	end

	-- self.is_full() - Check if inventory full
	env.self.is_full = function()
		return (interp.scrapInventory or 0) >= (interp.maxCapacity or 50)
	end

	-- =========================================================
	-- TURTLE-STYLE MOVEMENT
	-- =========================================================

	-- self.forward(steps) - Move forward (blocking)
	env.self.forward = function(dist)
		dist = dist or 10
		local hrp = getHRP()
		if hrp then
			local dir = hrp.CFrame.LookVector
			local newPos = hrp.Position + dir * dist
			moveInternal(newPos.X, newPos.Z)
		end
	end

	-- self.backward(steps) - Move backward (blocking)
	env.self.backward = function(dist)
		env.self.forward(-(dist or 10))
	end

	-- self.left(angle) - Turn left (in degrees)
	env.self.left = function(deg)
		deg = deg or 90
		local hrp = getHRP()
		if hrp then
			hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(deg), 0)
		end
	end

	-- self.right(angle) - Turn right (in degrees)
	env.self.right = function(deg)
		env.self.left(-(deg or 90))
	end

	-- self.goto(target) - Go to a turret, bot, or position
	env.self.goto = function(target)
		if not target then return false end
		-- If target has position method (like T1, B1)
		if type(target) == "table" and target.position then
			local pos = target.position()
			if pos then
				local coreX, coreZ = getCoreOffset()
				moveInternal(pos[1] + coreX, pos[2] + coreZ)
				return true
			end
		end
		-- If target is array [x, z]
		if type(target) == "table" and target[1] and target[2] then
			local coreX, coreZ = getCoreOffset()
			moveInternal(target[1] + coreX, target[2] + coreZ)
			return true
		end
		return false
	end

	-- =========================================================
	-- SCRAP & SUPPLY
	-- =========================================================

	-- self.scraps() - Get all scraps as [x, z] positions sorted by distance
	env.self.scraps = function()
		local x, z = getPlayerPos()
		local coreX, coreZ = getCoreOffset()
		local allScraps = ScrapManager and ScrapManager.getAll and ScrapManager.getAll() or {}

		local temp = {}
		for _, scrap in pairs(allScraps) do
			if scrap and scrap.part and scrap.part.Parent then
				local sPos = scrap.part.Position
				local dx = sPos.X - x
				local dz = sPos.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				-- Convert to user coords (relative to core)
				table.insert(temp, {
					pos = {math.floor(sPos.X - coreX), math.floor(sPos.Z - coreZ)},
					dist = dist,
					worldX = sPos.X,
					worldZ = sPos.Z,
				})
			end
		end

		table.sort(temp, function(a, b) return a.dist < b.dist end)

		-- Return just positions
		local result = {}
		for _, item in ipairs(temp) do
			table.insert(result, item.pos)
		end
		return result
	end

	-- self.collect(pos) - Move to [x,z] position and collect nearest scrap
	env.self.collect = function(pos)
		if not ScrapManager then return 0 end

		-- Accept [x, z] position from scraps()
		if type(pos) == "table" and pos[1] and pos[2] then
			local coreX, coreZ = getCoreOffset()
			local worldX = pos[1] + coreX
			local worldZ = pos[2] + coreZ

			-- Move to position
			moveInternal(worldX, worldZ)

			-- Find and collect nearest scrap at that location
			local nearest = ScrapManager.findNearest(worldX, worldZ)
			if nearest and nearest.part then
				local dx = nearest.part.Position.X - worldX
				local dz = nearest.part.Position.Z - worldZ
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < 10 then
					return ScrapManager.collect(nearest.id, interp) or 0
				end
			end
		end
		return 0
	end

	-- NOTE: Turrets auto-reload from core stockpile (no manual supply needed)

	-- =========================================================
	-- COMBAT
	-- =========================================================

	-- self.hit() - Melee attack nearest enemy
	env.self.hit = function()
		if deps.attackHitEvent and interp.character then
			local hrp = getHRP()
			if hrp and deps.EnemyManager then
				local x, z = getPlayerPos()
				local enemy = deps.EnemyManager.findNearest(x, z, 6)
				if enemy then
					deps.EnemyManager.damage(enemy.id, deps.Config.ATTACK_DAMAGE)
					return true
				end
			end
		end
		return false
	end

	-- self.scan() - Find enemies in range (like turrets)
	env.self.scan = function()
		local hrp = getHRP()
		if not hrp or not deps.EnemyManager then return {} end

		local x, z = getPlayerPos()
		local range = 50  -- Player has 50 stud range

		local enemies = deps.EnemyManager.findInRange(x, z, range)
		local results = {}
		for _, e in ipairs(enemies) do
			table.insert(results, {
				id = e.id,
				type = e.typeName or "Zombie",
				hp = e.hp or 0,
				max_hp = e.maxHp or 1,
				burning = e.burning or false,
				frozen = (e.slowAmount and e.slowAmount >= 0.5) or false,
				slowed = (e.slowAmount and e.slowAmount > 0) or false,
				oiled = e.oiled or false,
			})
		end
		return results
	end

	-- nearest(enemies) - Get nearest enemy from list
	env.nearest = function(enemyList)
		if not enemyList or #enemyList == 0 then return nil end

		local hrp = getHRP()
		if not hrp or not deps.EnemyManager then return enemyList[1] end

		local px, pz = getPlayerPos()
		local nearestEnemy, nearestDist = nil, math.huge

		for _, enemy in ipairs(enemyList) do
			local fullEnemy = deps.EnemyManager.get(enemy.id)
			if fullEnemy and fullEnemy.character then
				local eHrp = fullEnemy.character:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local dx = eHrp.Position.X - px
					local dz = eHrp.Position.Z - pz
					local dist = math.sqrt(dx * dx + dz * dz)
					if dist < nearestDist then
						nearestDist = dist
						nearestEnemy = enemy
					end
				end
			end
		end
		return nearestEnemy or enemyList[1]
	end

	-- weakest(enemies) - Get enemy with lowest HP
	env.weakest = function(enemyList)
		if not enemyList or #enemyList == 0 then return nil end

		local weakestEnemy, lowestHp = nil, math.huge
		for _, enemy in ipairs(enemyList) do
			if enemy.hp < lowestHp then
				lowestHp = enemy.hp
				weakestEnemy = enemy
			end
		end
		return weakestEnemy
	end

	-- strongest(enemies) - Get enemy with highest HP
	env.strongest = function(enemyList)
		if not enemyList or #enemyList == 0 then return nil end

		local strongestEnemy, highestHp = nil, 0
		for _, enemy in ipairs(enemyList) do
			if enemy.hp > highestHp then
				highestHp = enemy.hp
				strongestEnemy = enemy
			end
		end
		return strongestEnemy
	end

	-- self.fire(enemy, ammoType) - Ranged attack with projectile
	-- enemy: target from scan() (optional, will auto-target if nil)
	-- ammoType: 1=BULLET, 2=ROCKET, 3=LASER, 4=GRENADE, 5=ICE
	env.self.fire = function(enemy, ammoType)
		-- Handle old call style: self.fire(ammoType)
		if type(enemy) == "number" then
			ammoType = enemy
			enemy = nil
		end

		ammoType = ammoType or 1
		local hrp = getHRP()
		if not hrp or not deps.EnemyManager then return false end

		local lookDir = hrp.CFrame.LookVector

		-- If no enemy specified, find one in front of player
		if not enemy then
			local x, z = getPlayerPos()

			local enemies = deps.EnemyManager.findInRange(x, z, 50)
			local bestScore = -1

			for _, e in ipairs(enemies) do
				local eChar = e.character
				local eHrp = eChar and eChar:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local toEnemy = (eHrp.Position - hrp.Position).Unit
					local dot = lookDir.X * toEnemy.X + lookDir.Z * toEnemy.Z
					-- Only consider enemies in FRONT (dot > 0.3 = roughly 70 degree cone)
					if dot > 0.3 then
						local dist = (eHrp.Position - hrp.Position).Magnitude
						local score = dot * (1 - dist / 50)
						if score > bestScore then
							bestScore = score
							enemy = e
						end
					end
				end
			end
		else
			-- Convert from scan() result to full enemy
			enemy = deps.EnemyManager.get(enemy.id)

			-- Check if enemy is in front of player (can't shoot behind)
			if enemy and enemy.character then
				local eHrp = enemy.character:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local toEnemy = (eHrp.Position - hrp.Position).Unit
					local dot = lookDir.X * toEnemy.X + lookDir.Z * toEnemy.Z
					-- Must be in front (dot > 0.3 = roughly 70 degree cone)
					if dot <= 0.3 then
						return false  -- Enemy is behind player, can't shoot
					end
				end
			end
		end

		if not enemy then return false end

		-- Fire at the enemy using PlayerCombat module
		if deps.PlayerCombat and deps.PlayerCombat.fire then
			return deps.PlayerCombat.fire(interp, enemy, ammoType)
		end

		return false
	end

	-- Add all shared functionality
	addConstants(env)
	addUtilities(env, interp)
	addTurretProxies(env, deps)
	addBotProxies(env, deps)
	addCore(env, deps)

	return env
end

return GameAPI
