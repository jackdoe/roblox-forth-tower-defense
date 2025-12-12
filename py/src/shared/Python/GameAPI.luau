-- GameAPI.luau
-- Python API for tower defense game commands
-- Refactored: DRY architecture with shared builders

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
	env.FREEZE = 5
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

	-- Check if golem exists AND is alive
	local function isAlive()
		local golem = getGolem()
		if not golem then return false end
		local hp = golem.interpreter and golem.interpreter.hp or 0
		return hp > 0
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

	proxy.hp = function()
		local golem = getGolem()
		return golem and golem.interpreter and (golem.interpreter.hp or 0) or 0
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
			local ids = {}
			for _, e in ipairs(enemies) do
				table.insert(ids, e.id)
			end
			return ids
		end
		return {}
	end

	proxy.fire = function(targetId, ammoType)
		local golem = getGolem()
		if not golem then return false end
		-- Don't allow firing if dead (but not cleaned up yet)
		if not isAlive() then return false end

		ammoType = ammoType or 1
		if targetId and golem.interpreter then
			golem.interpreter.target = targetId
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

	proxy.methods = function()
		return getMethods(proxy)
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

	-- Check if bot exists AND is alive
	local function isAlive()
		local bot = getBot()
		if not bot then return false end
		return (bot.hp or 0) > 0
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

	proxy.hp = function()
		local bot = getBot()
		return bot and (bot.hp or 0) or 0
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
			return BotRegistry.issueCommand(bot.id, "MOVE", { x = worldX, z = worldZ }, true)
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

	-- Collection & Supply (all blocking - interpreter waits until task completes)
	proxy.supply = function(target)
		local bot = getBot()
		-- Don't allow supply if dead
		if not bot or not isAlive() or not BotRegistry.issueCommand then return false end

		local targetSpotId = target
		if type(target) == "table" and target.spot then
			targetSpotId = target.spot()
		end
		return BotRegistry.issueCommand(bot.id, "SUPPLY", { target = targetSpotId }, true)
	end

	proxy.collect = function(scrap)
		local bot = getBot()
		-- Don't allow collection if dead
		if not bot or not isAlive() then return false end

		-- Handle scrap object from scraps() or raw id
		local scrapId = scrap
		if type(scrap) == "table" then
			scrapId = scrap.id
		end

		if BotRegistry.issueCommand and scrapId then
			return BotRegistry.issueCommand(bot.id, "COLLECT", { target = scrapId }, true)
		end
		return false
	end

	proxy.scan = function()
		local bot = getBot()
		if not bot or not bot.character or not ScrapManager then return nil end

		local x, z = getCharacterPos(bot.character)
		local scrap = ScrapManager.findNearest(x, z)
		if scrap and scrap.position then
			-- Return user coords (relative to core)
			local userX, userZ = toUserCoords(scrap.position.X, scrap.position.Z)
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

	proxy.color = function(colorName)
		local bot = getBot()
		if bot then
			applyBotColor(bot.character, colorName)
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

	-- scraps() - Returns list of all scraps sorted by distance (closest first)
	proxy.scraps = function()
		local bot = getBot()
		if not bot or not bot.character or not ScrapManager then return {} end

		local x, z = getCharacterPos(bot.character)
		local allScraps = ScrapManager.getAll and ScrapManager.getAll() or {}

		-- Build list with distances
		local result = {}
		for _, scrap in pairs(allScraps) do
			if scrap and scrap.position and scrap.id then
				local dx = scrap.position.X - x
				local dz = scrap.position.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				table.insert(result, {
					id = scrap.id,
					distance = dist,
					x = scrap.position.X,
					z = scrap.position.Z,
				})
			end
		end

		-- Sort by distance (closest first)
		table.sort(result, function(a, b) return a.distance < b.distance end)
		return result
	end

	proxy.methods = function()
		return getMethods(proxy)
	end

	return proxy
end

-- Add T1-T4 turret proxies to an environment
local function addTurretProxies(env, deps)
	env.T1 = createTurretProxy(1, deps)
	env.T2 = createTurretProxy(2, deps)
	env.T3 = createTurretProxy(3, deps)
	env.T4 = createTurretProxy(4, deps)
end

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
	env.nearest = function(enemyList)
		enemyList = enemyList or selfObj.scan()
		if #enemyList == 0 then return nil end

		local gx, gz = getGolemPos()
		local nearestId, nearestDist = nil, math.huge

		for _, enemyId in ipairs(enemyList) do
			local ex, ez = getEnemyPos(enemyId)
			if ex then
				local dist = calcDistance(gx, gz, ex, ez)
				if dist < nearestDist then
					nearestDist = dist
					nearestId = enemyId
				end
			end
		end
		return nearestId
	end

	env.weakest = function(enemyList)
		enemyList = enemyList or selfObj.scan()
		if #enemyList == 0 then return nil end

		local weakestId, lowestHp = nil, math.huge
		for _, enemyId in ipairs(enemyList) do
			local enemy = EnemyManager.get(enemyId)
			if enemy and enemy.hp < lowestHp then
				lowestHp = enemy.hp
				weakestId = enemyId
			end
		end
		return weakestId
	end

	env.strongest = function(enemyList)
		enemyList = enemyList or selfObj.scan()
		if #enemyList == 0 then return nil end

		local strongestId, highestHp = nil, 0
		for _, enemyId in ipairs(enemyList) do
			local enemy = EnemyManager.get(enemyId)
			if enemy and enemy.hp > highestHp then
				highestHp = enemy.hp
				strongestId = enemyId
			end
		end
		return strongestId
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

	-- self.color("red") - Changes body color
	env.self.color = function(colorName)
		if BotRegistry and BotRegistry.setBotColor then
			return BotRegistry.setBotColor(bot.id, colorName)
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
		if scrap and scrap.position then
			local dx = scrap.position.X - hrp.Position.X
			local dz = scrap.position.Z - hrp.Position.Z
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
	local function moveInternal(x, z)
		if not x or not z then return end
		local char = interp.character
		if char then
			local humanoid = char:FindFirstChild("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if humanoid and hrp then
				local done = false
				humanoid:MoveTo(Vector3.new(x, hrp.Position.Y, z))
				local conn = humanoid.MoveToFinished:Connect(function()
					done = true
				end)
				while not done do
					interp.runtime.waitUntil = os.clock() + 0.1
					coroutine.yield()
				end
				conn:Disconnect()
			end
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

	-- self.scraps() - Get all scraps sorted by distance
	env.self.scraps = function()
		local x, z = getPlayerPos()
		local allScraps = ScrapManager and ScrapManager.getAll and ScrapManager.getAll() or {}

		local result = {}
		for _, scrap in pairs(allScraps) do
			if scrap and scrap.position and scrap.id then
				local dx = scrap.position.X - x
				local dz = scrap.position.Z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				table.insert(result, {
					id = scrap.id,
					distance = dist,
					x = scrap.position.X,
					z = scrap.position.Z,
				})
			end
		end

		table.sort(result, function(a, b) return a.distance < b.distance end)
		return result
	end

	-- self.collect(scrap) - Collect a specific scrap (from scraps() list)
	env.self.collect = function(scrap)
		if not ScrapManager then return 0 end

		-- If scrap is from scraps() list, it has id field
		local scrapId = scrap
		if type(scrap) == "table" then
			scrapId = scrap.id
		end

		-- Find the scrap
		local target = ScrapManager.get and ScrapManager.get(scrapId)
		if target and target.position then
			-- Move to scrap
			moveInternal(target.position.X, target.position.Z)
			-- Collect it
			return ScrapManager.collect(scrapId, interp) or 0
		end
		return 0
	end

	-- self.supply(turret) - Supply ammo to a turret
	env.self.supply = function(target)
		if not GolemRegistry then return 0 end

		local spotId = target
		if type(target) == "table" and target.spot then
			spotId = target.spot()
		end

		local golem = GolemRegistry.getBySpotId(spotId)
		if golem then
			-- Move to golem first
			if golem.character then
				local gx, gz = getCharacterPos(golem.character)
				moveInternal(gx, gz)
			end
			-- Supply
			local amount = GolemRegistry.refillAmmo(golem.id, interp.scrapInventory or 0)
			interp.scrapInventory = (interp.scrapInventory or 0) - amount
			return amount
		end
		return 0
	end

	-- =========================================================
	-- COMBAT
	-- =========================================================

	-- self.hit() - Attack nearest enemy
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

	-- Add all shared functionality
	addConstants(env)
	addUtilities(env, interp)
	addTurretProxies(env, deps)
	addBotProxies(env, deps)
	addCore(env, deps)

	return env
end

return GameAPI
