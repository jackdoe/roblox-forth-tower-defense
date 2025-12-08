-- GolemWords.luau
-- Forth words for programmable turrets (Golems)
-- These words let players write targeting algorithms!
--
-- EDUCATIONAL VALUE:
-- Kids learn to think algorithmically:
--   "Should I target the nearest enemy, or the weakest?"
--   "What if I conserve ammo when enemies are far away?"
--   "How do I prioritize tanks over runners?"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)

local GolemWords = {}

function GolemWords.register(dict, push, pop, peek, self, deps)
	-- Only golems can use these words
	local function isGolem()
		return self.isGolem == true
	end

	local function getGolemRegistry()
		-- Get GolemRegistry from deps or require it
		if deps.GolemRegistry then
			return deps.GolemRegistry
		end
		pcall(function()
			deps.GolemRegistry = require(script.Parent.Parent.GolemRegistry)
		end)
		return deps.GolemRegistry
	end

	local function getEnemyManager()
		if deps.EnemyManager then
			return deps.EnemyManager
		end
		pcall(function()
			deps.EnemyManager = require(script.Parent.Parent.EnemyManager)
		end)
		return deps.EnemyManager
	end

	local function getMyPosition()
		if not self.character then return nil, nil end
		local hrp = self.character:FindFirstChild("HumanoidRootPart") or self.character.PrimaryPart
		if not hrp then return nil, nil end
		return hrp.Position.X, hrp.Position.Z
	end

	--============================================================================
	-- SENSING WORDS
	-- These help the Golem "see" enemies
	--============================================================================

	-- SCAN ( -- count )
	-- Count how many enemies are in range
	-- This is the foundation: "Are there any threats?"
	dict["SCAN"] = function()
		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(0)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(0)
			return
		end

		local range = self.range or 25
		local enemies = EnemyManager.findInRange(myX, myZ, range)
		push(#enemies)
	end

	-- NEAREST ( -- id )
	-- Get the ID of the nearest enemy
	-- Simple but effective: "Shoot the closest threat!"
	dict["NEAREST"] = function()
		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(0)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(0)
			return
		end

		local range = self.range or 25
		local enemy = EnemyManager.findNearest(myX, myZ, range)

		if enemy then
			push(enemy.id)
		else
			push(0)
		end
	end

	-- WEAKEST ( -- id )
	-- Get the ID of the enemy with lowest HP
	-- Strategic: "Finish off the wounded ones first!"
	dict["WEAKEST"] = function()
		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(0)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(0)
			return
		end

		local range = self.range or 25
		local enemy = EnemyManager.findWeakest(myX, myZ, range)

		if enemy then
			push(enemy.id)
		else
			push(0)
		end
	end

	-- STRONGEST ( -- id )
	-- Get the ID of the enemy with highest HP
	-- For snipers: "Take down the big threats first!"
	dict["STRONGEST"] = function()
		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(0)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(0)
			return
		end

		local range = self.range or 25
		local enemies = EnemyManager.findInRange(myX, myZ, range)

		local strongest = nil
		local highestHp = 0

		for _, enemy in ipairs(enemies) do
			if enemy.hp > highestHp then
				highestHp = enemy.hp
				strongest = enemy
			end
		end

		if strongest then
			push(strongest.id)
		else
			push(0)
		end
	end

	-- CLOSEST-TO-CORE ( -- id )
	-- Get the enemy closest to the Core
	-- Advanced: "Stop the one about to score!"
	dict["CLOSEST-TO-CORE"] = function()
		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		local WaveManager = deps.WaveManager
		if not EnemyManager or not WaveManager then
			push(0)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(0)
			return
		end

		local corePos = WaveManager.getCorePosition()
		if not corePos then
			push(0)
			return
		end

		local range = self.range or 25
		local enemies = EnemyManager.findInRange(myX, myZ, range)

		local closest = nil
		local closestDistSq = math.huge  -- Use squared distance

		for _, enemy in ipairs(enemies) do
			local hrp = enemy.character and enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - corePos.x
				local dz = hrp.Position.Z - corePos.z
				local distSq = dx * dx + dz * dz  -- No sqrt needed for comparison
				if distSq < closestDistSq then
					closestDistSq = distSq
					closest = enemy
				end
			end
		end

		if closest then
			push(closest.id)
		else
			push(0)
		end
	end

	-- ENEMY-HP ( id -- hp )
	-- Get the HP of a specific enemy
	-- For conditional logic: "Is it worth shooting?"
	dict["ENEMY-HP"] = function()
		local id = pop()
		if id == nil then return end

		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(0)
			return
		end

		local enemy = EnemyManager.get(id)
		if enemy then
			push(enemy.hp)
		else
			push(0)
		end
	end

	-- ENEMY-DIST ( id -- dist )
	-- Get distance to a specific enemy
	-- For range-based logic: "Is it close enough?"
	dict["ENEMY-DIST"] = function()
		local id = pop()
		if id == nil then return end

		if not isGolem() then
			push(999)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(999)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(999)
			return
		end

		local enemy = EnemyManager.get(id)
		if enemy and enemy.character then
			local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dx = hrp.Position.X - myX
				local dz = hrp.Position.Z - myZ
				-- sqrt needed here because we return the actual distance value
				local dist = math.sqrt(dx * dx + dz * dz)
				push(math.floor(dist))
				return
			end
		end

		push(999)
	end

	--============================================================================
	-- TARGETING WORDS
	-- These control where the Golem aims
	--============================================================================

	-- TARGET ( id -- )
	-- Set the current target enemy
	-- This makes the turret rotate to face the enemy
	dict["TARGET"] = function()
		local id = pop()
		if id == nil then return end

		if not isGolem() then return end

		-- Validate target exists
		local EnemyManager = getEnemyManager()
		if EnemyManager then
			local enemy = EnemyManager.get(id)
			if enemy and enemy.hp > 0 then
				self.target = id
			else
				self.target = nil
			end
		end
	end

	-- TARGET? ( -- id )
	-- Get current target (or 0 if none)
	dict["TARGET?"] = function()
		if isGolem() and self.target then
			push(self.target)
		else
			push(0)
		end
	end

	-- CLEAR-TARGET ( -- )
	-- Clear the current target
	dict["CLEAR-TARGET"] = function()
		if isGolem() then
			self.target = nil
		end
	end

	--============================================================================
	-- FIRING WORDS
	-- These control shooting
	--============================================================================

	--============================================================================
	-- AMMO TYPE WORDS
	-- Push ammo type onto stack for use with FIRE
	--============================================================================

	-- BULLET ( -- ammo )
	-- Cheap, fast, low damage
	dict["BULLET"] = function()
		push(TaggedValue.createBullet())
	end

	-- ROCKET ( -- ammo )
	-- Expensive, slow, high damage, AOE
	dict["ROCKET"] = function()
		push(TaggedValue.createRocket())
	end

	-- LASER ( -- ammo )
	-- Medium cost, medium damage, extended range
	dict["LASER"] = function()
		push(TaggedValue.createLaser())
	end

	-- ICE ( -- ammo )
	-- Slows enemies on hit, good for crowd control
	dict["ICE"] = function()
		push(TaggedValue.createIce())
	end

	-- FREEZE ( -- ammo )
	-- Utility ammo: No damage, but slows enemy to 70% speed
	-- Cheap and fast - for strategic slowing
	dict["FREEZE"] = function()
		push(TaggedValue.createFreeze())
	end

	-- FIRE ( ammo -- )
	-- Shoot at current target using specified ammo type
	-- Usage: BULLET FIRE or ROCKET FIRE or LASER FIRE
	dict["FIRE"] = function()
		if not isGolem() then
			pop()  -- Consume the ammo type anyway
			return
		end

		local ammoValue = pop()
		if ammoValue == nil then return end

		-- Get ammo type (1=BULLET, 2=ROCKET, 3=LASER)
		local ammoType = TaggedValue.getAmmoType(ammoValue) or 1

		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			GolemRegistry.fire(self.id, ammoType)
		end
	end

	-- FIRE? ( ammo -- flag )
	-- Try to fire, returns -1 if successful, 0 if failed
	-- Useful for: "Did I actually hit?"
	dict["FIRE?"] = function()
		if not isGolem() then
			pop()
			push(0)
			return
		end

		local ammoValue = pop()
		if ammoValue == nil then
			push(0)
			return
		end

		local ammoType = TaggedValue.getAmmoType(ammoValue) or 1

		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local success = GolemRegistry.fire(self.id, ammoType)
			push(success and -1 or 0)
		else
			push(0)
		end
	end

	-- 2FIRE ( ammo ammo -- )
	-- Fire TWO shots at once (consumes two ammo from stack)
	-- Unlocked at wave 3
	-- Usage: BULLET BULLET 2FIRE or BULLET ROCKET 2FIRE
	dict["2FIRE"] = function()
		if not isGolem() then
			pop()
			pop()
			return
		end

		local ammo2 = pop()
		local ammo1 = pop()
		if ammo1 == nil or ammo2 == nil then return end

		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local type1 = TaggedValue.getAmmoType(ammo1) or 1
			local type2 = TaggedValue.getAmmoType(ammo2) or 1
			GolemRegistry.fire(self.id, type1)
			-- Small delay between shots for visual effect
			-- skipCooldown=true so burst fire works properly
			task.delay(0.05, function()
				GolemRegistry.fire(self.id, type2, true)
			end)
		end
	end

	-- 3FIRE ( ammo ammo ammo -- )
	-- Fire THREE shots at once
	-- Unlocked at wave 6
	dict["3FIRE"] = function()
		if not isGolem() then
			pop()
			pop()
			pop()
			return
		end

		local ammo3 = pop()
		local ammo2 = pop()
		local ammo1 = pop()
		if ammo1 == nil or ammo2 == nil or ammo3 == nil then return end

		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local type1 = TaggedValue.getAmmoType(ammo1) or 1
			local type2 = TaggedValue.getAmmoType(ammo2) or 1
			local type3 = TaggedValue.getAmmoType(ammo3) or 1
			GolemRegistry.fire(self.id, type1)
			-- skipCooldown=true so burst fire works properly
			task.delay(0.05, function()
				GolemRegistry.fire(self.id, type2, true)
			end)
			task.delay(0.10, function()
				GolemRegistry.fire(self.id, type3, true)
			end)
		end
	end

	-- 4FIRE ( ammo ammo ammo ammo -- )
	-- Fire FOUR shots at once
	-- Unlocked at wave 10
	dict["4FIRE"] = function()
		if not isGolem() then
			pop(); pop(); pop(); pop()
			return
		end

		local ammo4 = pop()
		local ammo3 = pop()
		local ammo2 = pop()
		local ammo1 = pop()
		if ammo1 == nil or ammo2 == nil or ammo3 == nil or ammo4 == nil then return end

		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local type1 = TaggedValue.getAmmoType(ammo1) or 1
			local type2 = TaggedValue.getAmmoType(ammo2) or 1
			local type3 = TaggedValue.getAmmoType(ammo3) or 1
			local type4 = TaggedValue.getAmmoType(ammo4) or 1
			GolemRegistry.fire(self.id, type1)
			task.delay(0.05, function()
				GolemRegistry.fire(self.id, type2, true)
			end)
			task.delay(0.10, function()
				GolemRegistry.fire(self.id, type3, true)
			end)
			task.delay(0.15, function()
				GolemRegistry.fire(self.id, type4, true)
			end)
		end
	end

	-- 5FIRE ( ammo ammo ammo ammo ammo -- )
	-- Fire FIVE shots at once
	-- Unlocked at wave 20
	dict["5FIRE"] = function()
		if not isGolem() then
			pop(); pop(); pop(); pop(); pop()
			return
		end

		local ammo5 = pop()
		local ammo4 = pop()
		local ammo3 = pop()
		local ammo2 = pop()
		local ammo1 = pop()
		if ammo1 == nil or ammo2 == nil or ammo3 == nil or ammo4 == nil or ammo5 == nil then return end

		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local type1 = TaggedValue.getAmmoType(ammo1) or 1
			local type2 = TaggedValue.getAmmoType(ammo2) or 1
			local type3 = TaggedValue.getAmmoType(ammo3) or 1
			local type4 = TaggedValue.getAmmoType(ammo4) or 1
			local type5 = TaggedValue.getAmmoType(ammo5) or 1
			GolemRegistry.fire(self.id, type1)
			task.delay(0.05, function()
				GolemRegistry.fire(self.id, type2, true)
			end)
			task.delay(0.10, function()
				GolemRegistry.fire(self.id, type3, true)
			end)
			task.delay(0.15, function()
				GolemRegistry.fire(self.id, type4, true)
			end)
			task.delay(0.20, function()
				GolemRegistry.fire(self.id, type5, true)
			end)
		end
	end

	--============================================================================
	-- STATUS WORDS
	-- These let the Golem check its own state
	--============================================================================

	-- AMMO? ( -- n )
	-- Get current ammo count
	-- Essential for: "Should I keep shooting?"
	dict["AMMO?"] = function()
		if isGolem() then
			push(self.ammo or 0)
		else
			push(0)
		end
	end

	-- MAX-AMMO ( -- n )
	-- Get max ammo capacity
	dict["MAX-AMMO"] = function()
		if isGolem() then
			push(self.maxAmmo or 0)
		else
			push(0)
		end
	end

	-- UPGRADE-AMMO-CAPACITY ( -- )
	-- Upgrade golem's max ammo to 600
	-- Unlocked at wave 15
	dict["UPGRADE-AMMO-CAPACITY"] = function()
		if isGolem() then
			if (self.maxAmmo or 300) < 600 then
				self.maxAmmo = 600
				self.safeOutput("UPGRADED:600")
			end
		end
	end

	-- MAX-AMMO-CAPACITY ( -- )
	-- Upgrade golem's max ammo to 900 (maximum)
	-- Unlocked at wave 25
	dict["MAX-AMMO-CAPACITY"] = function()
		if isGolem() then
			if (self.maxAmmo or 300) < 900 then
				self.maxAmmo = 900
				self.safeOutput("MAXED:900")
			end
		end
	end

	-- AMMO-LOW? ( -- flag )
	-- True if ammo < 30%
	-- Convenient check: "Am I running low?"
	dict["AMMO-LOW?"] = function()
		if isGolem() then
			local ratio = (self.ammo or 0) / (self.maxAmmo or 1)
			push(ratio < 0.3 and -1 or 0)
		else
			push(0)
		end
	end

	-- EMPTY? ( -- flag )
	-- True if completely out of ammo
	dict["EMPTY?"] = function()
		if isGolem() then
			push((self.ammo or 0) <= 0 and -1 or 0)
		else
			push(0)
		end
	end

	-- SET-RANGE ( n -- )
	-- Set the turret's effective range.
	-- Strategy: Lower range = Higher damage (Shotgun). Higher range = Lower damage (Sniper).
	-- Clamped between 10 and 60.
	dict["SET-RANGE"] = function()
		local r = pop()
		if r == nil then return end

		if not isGolem() then return end

		-- Clamp range
		if r < 10 then r = 10 end
		if r > 60 then r = 60 end

		self.dynamicRange = r
	end

	-- RANGE ( -- n )
	-- Get this golem's current dynamic range
	dict["RANGE"] = function()
		if isGolem() then
			push(self.dynamicRange or self.range or 40)
		else
			push(0)
		end
	end

	-- MY-HP ( -- n )
	-- Get this golem's current HP
	dict["MY-HP"] = function()
		if isGolem() then
			push(self.hp or 0)
		else
			push(0)
		end
	end

	-- MY-ID ( -- n )
	-- Get this golem's spot ID (for communication)
	dict["MY-ID"] = function()
		if isGolem() then
			-- Try to get spot ID from GolemRegistry
			local GolemRegistry = getGolemRegistry()
			if GolemRegistry then
				local golem = GolemRegistry.get(self.id)
				if golem then
					push(golem.spotId or 0)
					return
				end
			end
		end
		push(0)
	end

	--============================================================================
	-- ADVANCED WORDS
	-- For sophisticated targeting strategies
	--============================================================================

	-- ENEMIES ( -- count )
	-- Alias for SCAN (more readable in some contexts)
	dict["ENEMIES"] = dict["SCAN"]

	-- THREAT? ( -- flag )
	-- Are there any enemies in range?
	-- Quick check for: "Should I be shooting?"
	dict["THREAT?"] = function()
		if not isGolem() then
			push(0)
			return
		end

		local EnemyManager = getEnemyManager()
		if not EnemyManager then
			push(0)
			return
		end

		local myX, myZ = getMyPosition()
		if not myX then
			push(0)
			return
		end

		local range = self.range or 25
		local enemies = EnemyManager.findInRange(myX, myZ, range)
		push(#enemies > 0 and -1 or 0)
	end

	-- CONSERVE ( threshold -- )
	-- Only fire if enemies are closer than threshold
	-- Teaches resource management: "Don't waste ammo on distant targets"
	dict["CONSERVE"] = function()
		local threshold = pop()
		if threshold == nil then return end

		if not isGolem() then return end

		if self.target then
			-- Check distance to target
			local EnemyManager = getEnemyManager()
			if not EnemyManager then return end

			local myX, myZ = getMyPosition()
			if not myX then return end

			local enemy = EnemyManager.get(self.target)
			if enemy and enemy.character then
				local hrp = enemy.character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dx = hrp.Position.X - myX
					local dz = hrp.Position.Z - myZ
					local distSq = dx * dx + dz * dz
					local thresholdSq = threshold * threshold  -- Squared comparison

					if distSq <= thresholdSq then
						-- Close enough, fire!
						local GolemRegistry = getGolemRegistry()
						if GolemRegistry then
							GolemRegistry.fire(self.id)
						end
					end
					-- If too far, don't fire (conserve ammo)
				end
			end
		end
	end

	--============================================================================
	-- EXAMPLE PROGRAMS (as comments for education)
	--============================================================================

	-- Basic turret:
	-- BEGIN SCAN 0 > IF NEAREST TARGET FIRE THEN AGAIN

	-- Smart turret (prioritize weak):
	-- BEGIN SCAN 0 > IF WEAKEST TARGET FIRE THEN AGAIN

	-- Sniper (save ammo for big targets):
	-- BEGIN SCAN 0 > IF STRONGEST DUP ENEMY-HP 100 > IF TARGET FIRE ELSE DROP THEN THEN AGAIN

	-- Conserving turret:
	-- BEGIN THREAT? IF NEAREST TARGET 15 CONSERVE THEN AGAIN

	-- Core defender:
	-- BEGIN SCAN 0 > IF CLOSEST-TO-CORE TARGET FIRE THEN AGAIN
end

return GolemWords
