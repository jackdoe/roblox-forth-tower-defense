-- LogisticsWords.luau
-- Forth words for player automation and logistics
-- These words let players write "macro" scripts for themselves!
--
-- EDUCATIONAL VALUE:
-- This is the "end game" - where coding becomes truly powerful
-- Kids learn that they can automate THEMSELVES:
--   "Instead of running to each turret manually, I can write a loop!"
--   "My code can check which turret needs ammo and teleport me there!"
--
-- The progression:
-- 1. Manual play (exhausting with many turrets)
-- 2. Write turret code (turrets auto-shoot)
-- 3. Write player code (YOU auto-supply turrets)
-- 4. Win by being a better programmer!

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)

local LogisticsWords = {}

function LogisticsWords.register(dict, push, pop, peek, self, deps)
	-- Only players can use these words
	local function isPlayer()
		return self.isPlayer == true and not self.isGolem
	end

	local function getGolemRegistry()
		if deps.GolemRegistry then
			return deps.GolemRegistry
		end
		pcall(function()
			deps.GolemRegistry = require(script.Parent.Parent.GolemRegistry)
		end)
		return deps.GolemRegistry
	end

	local function getWaveManager()
		if deps.WaveManager then
			return deps.WaveManager
		end
		pcall(function()
			deps.WaveManager = require(script.Parent.Parent.WaveManager)
		end)
		return deps.WaveManager
	end

	local function refreshCharacter()
		if self.player and self.player.Character then
			self.character = self.player.Character
		end
	end

	--============================================================================
	-- GOLEM QUERY WORDS
	-- Let players check on their turrets
	--============================================================================

	-- MACHINES ( -- count )
	-- How many golems are placed?
	-- Foundation for loops: "FOR 1 MACHINES DO ... LOOP"
	dict["MACHINES"] = function()
		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			push(GolemRegistry.count())
		else
			push(0)
		end
	end

	-- GOLEM-AMMO ( {golem} -- ammo )
	-- Get ammo count of golem
	-- Check if turret needs refilling
	dict["GOLEM-AMMO"] = function()
		local golemRef = pop()
		if golemRef == nil then return end

		if not TaggedValue.isGolem(golemRef) then
			self.error = "GOLEM-AMMO: Expected golem reference"
			self.status = "ERROR"
			return
		end

		local spotId = TaggedValue.getGolemSpotId(golemRef)
		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local golem = GolemRegistry.getBySpotId(spotId)
			if golem and golem.interpreter then
				push(golem.interpreter.ammo or 0)
				return
			end
		end
		push(0)
	end


	-- GOLEM-EMPTY? ( {golem} -- flag )
	-- Is this golem out of ammo?
	-- Quick check for supply loops
	dict["GOLEM-EMPTY?"] = function()
		local golemRef = pop()
		if golemRef == nil then return end

		if not TaggedValue.isGolem(golemRef) then
			self.error = "GOLEM-EMPTY?: Expected golem reference"
			self.status = "ERROR"
			return
		end

		local spotId = TaggedValue.getGolemSpotId(golemRef)
		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local golem = GolemRegistry.getBySpotId(spotId)
			if golem and golem.interpreter then
				push(golem.interpreter.ammo <= 0 and -1 or 0)
				return
			end
		end
		push(0)
	end

	-- GOLEM-LOW? ( {golem} -- flag )
	-- Is this golem running low on ammo? (< 30%)
	dict["GOLEM-LOW?"] = function()
		local golemRef = pop()
		if golemRef == nil then return end

		if not TaggedValue.isGolem(golemRef) then
			self.error = "GOLEM-LOW?: Expected golem reference"
			self.status = "ERROR"
			return
		end

		local spotId = TaggedValue.getGolemSpotId(golemRef)
		local GolemRegistry = getGolemRegistry()
		if GolemRegistry then
			local golem = GolemRegistry.getBySpotId(spotId)
			if golem and golem.interpreter then
				local ratio = golem.interpreter.ammo / golem.interpreter.maxAmmo
				push(ratio < 0.3 and -1 or 0)
				return
			end
		end
		push(0)
	end

	-- LOWEST-AMMO ( -- id )
	-- Find the golem with lowest ammo percentage
	-- Smart supply: "Who needs me most?"
	dict["LOWEST-AMMO"] = function()
		local GolemRegistry = getGolemRegistry()
		if not GolemRegistry then
			push(0)
			return
		end

		local golems = GolemRegistry.getAll()
		local neediest = nil
		local lowestRatio = 1

		for _, golem in pairs(golems) do
			if golem.interpreter then
				local ratio = golem.interpreter.ammo / golem.interpreter.maxAmmo
				if ratio < lowestRatio then
					lowestRatio = ratio
					neediest = golem
				end
			end
		end

		if neediest then
			push(neediest.spotId or 0)
		else
			push(0)
		end
	end

	--============================================================================
	-- MOVEMENT WORDS
	-- Let players teleport to turrets
	--============================================================================

	-- TELEPORT ( {golem} -- )
	-- Woosh to golem with smooth movement
	-- The power move: "No more running!"
	local TELEPORT_SPEED = 80 -- Studs per second

	dict["TELEPORT"] = function()
		local golemRef = pop()
		if golemRef == nil then return end

		if not TaggedValue.isGolem(golemRef) then
			self.error = "TELEPORT: Expected golem reference"
			self.status = "ERROR"
			return
		end

		if not isPlayer() then return end

		refreshCharacter()
		if not self.character then return end

		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		local humanoid = self.character:FindFirstChild("Humanoid")
		if not hrp or not humanoid then return end

		local GolemRegistry = getGolemRegistry()
		if not GolemRegistry then return end

		local spotId = TaggedValue.getGolemSpotId(golemRef)
		local golem = GolemRegistry.getBySpotId(spotId)
		if not golem or not golem.character then
			self.safeOutput("NO_GOLEM")
			return
		end

		local golemHrp = golem.character:FindFirstChild("HumanoidRootPart") or golem.character.PrimaryPart
		if not golemHrp then return end

		-- Block interpreter while moving
		self.blocked = true

		local startPos = hrp.Position
		-- Target position with offset so player stands beside turret
		local targetPos = Vector3.new(golemHrp.Position.X + 6, startPos.Y, golemHrp.Position.Z + 3)

		-- Calculate distance and duration
		local dist = (targetPos - startPos).Magnitude
		if dist < 1 then
			self.blocked = false
			return
		end

		local duration = dist / TELEPORT_SPEED

		-- Stop walking and anchor for smooth tween
		humanoid.WalkSpeed = 0
		humanoid:Move(Vector3.new(0, 0, 0))
		hrp.Anchored = true

		-- Calculate direction for facing
		local direction = (targetPos - startPos).Unit
		local targetCFrame = CFrame.new(targetPos, targetPos + direction)

		-- Create smooth tween
		local moveTween = TweenService:Create(hrp,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = targetCFrame }
		)

		-- Trail effect (cyan woosh)
		task.spawn(function()
			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 1.5, 0)
			a1.Position = Vector3.new(0, -1.5, 0)
			a0.Parent = hrp
			a1.Parent = hrp

			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.2
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.5, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			})
			trail.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
			trail.Parent = hrp

			task.wait(duration + 0.4)
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)

		moveTween:Play()
		moveTween.Completed:Wait()

		hrp.Anchored = false
		humanoid.WalkSpeed = deps.Config and deps.Config.MANUAL_WALKING_SPEED or 16
		self.blocked = false

		self.safeOutput("WARP->" .. spotId)
	end


	--============================================================================
	-- SUPPLY WORDS
	-- Let players refill turret ammo
	--============================================================================

	-- RELOAD ( {golem} -- )
	-- Convert player's scrap into ammo for specified golem (10 scrap = 20 ammo)
	-- Player must be near the golem
	-- Usage: G7 RELOAD or G7 DUP TELEPORT RELOAD
	dict["RELOAD"] = function()
		local golemRef = pop()
		if golemRef == nil then return end

		if not TaggedValue.isGolem(golemRef) then
			self.error = "RELOAD: Expected golem reference"
			self.status = "ERROR"
			return
		end

		if not isPlayer() then return end

		refreshCharacter()
		if not self.character then return end

		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local GolemRegistry = getGolemRegistry()
		local WaveManager = getWaveManager()
		if not GolemRegistry or not WaveManager then return end

		-- Get the golem by spot ID
		local spotId = TaggedValue.getGolemSpotId(golemRef)
		local golem = GolemRegistry.getBySpotId(spotId)
		if not golem then
			self.safeOutput("NO_GOLEM")
			return
		end

		-- Check if player is near the golem
		local golemHrp = golem.character and
			(golem.character:FindFirstChild("HumanoidRootPart") or golem.character.PrimaryPart)
		if not golemHrp then return end

		local dist = (hrp.Position - golemHrp.Position).Magnitude
		if dist > 10 then
			self.safeOutput("TOO_FAR")
			return
		end

		local interp = golem.interpreter
		if not interp then return end

		-- Check if golem needs ammo
		if interp.ammo >= interp.maxAmmo then
			self.safeOutput("FULL")
			return
		end

		-- Check player's scrap
		-- ECONOMY BUFF: 10x cheaper to shoot!
		-- New Ratio: 5 Scrap buys 100 Ammo (0.05 scrap per bullet)
		-- Previous: 10 Scrap for 20 Ammo (0.5 scrap per bullet)
		local RELOAD_COST = 5   -- Was 10. Cost halved.
		local RELOAD_AMMO = 100 -- Was 20. Amount x5.

		local scrap = WaveManager.getScrap(self.player.UserId)
		if scrap < RELOAD_COST then
			self.safeOutput("NO_SCRAP")
			return
		end

		-- Do the reload
		WaveManager.removeScrap(self.player.UserId, RELOAD_COST)
		local added = math.min(RELOAD_AMMO, interp.maxAmmo - interp.ammo)
		interp.ammo = interp.ammo + added

		self.safeOutput("+" .. added)

		-- Visual effect (green for scrap conversion)
		task.spawn(function()
			local beam = Instance.new("Part")
			beam.Name = "ReloadBeam"
			beam.Size = Vector3.new(0.5, 4, 0.5)
			beam.Position = golemHrp.Position + Vector3.new(0, 2, 0)
			beam.Anchored = true
			beam.CanCollide = false
			beam.Material = Enum.Material.Neon
			beam.Color = Color3.fromRGB(100, 255, 100) -- Green for scrap
			beam.Transparency = 0.3
			beam.Parent = workspace

			for i = 1, 8 do
				beam.Transparency = 0.3 + i * 0.08
				beam.Size = beam.Size - Vector3.new(0.05, 0, 0.05)
				task.wait(0.03)
			end

			beam:Destroy()
		end)
	end

	--============================================================================
	-- ECONOMY WORDS
	-- Check and spend scrap
	--============================================================================

	-- SCRAP ( -- n )
	-- Get current scrap count
	dict["SCRAP"] = function()
		local WaveManager = getWaveManager()
		if WaveManager and self.player then
			push(WaveManager.getScrap(self.player.UserId))
		else
			push(0)
		end
	end

	-- BUILD ( -- )
	-- Enter placement mode to build a new golem
	-- Player will see a ghost turret preview and click to place
	dict["BUILD"] = function()
		if not isPlayer() then return end
		if not self.player then return end

		-- Fire event to client to enter placement mode
		if deps.enterBuildModeEvent then
			deps.enterBuildModeEvent:FireClient(self.player)
			self.safeOutput("PLACEMENT MODE")
		end
	end

	--============================================================================
	-- GAME STATE WORDS
	-- Check wave progress and core status
	--============================================================================

	-- WAVE ( -- n )
	-- Current wave number
	dict["WAVE"] = function()
		local WaveManager = getWaveManager()
		if WaveManager then
			push(WaveManager.getState().waveNumber)
		else
			push(0)
		end
	end

	-- CORE-HP ( -- n )
	-- Current Core HP
	dict["CORE-HP"] = function()
		local WaveManager = getWaveManager()
		if WaveManager then
			local hp, _ = WaveManager.getCoreHp()
			push(hp or 0)
		else
			push(0)
		end
	end

	-- ENEMIES-LEFT ( -- n )
	-- Enemies remaining in current wave
	dict["ENEMIES-LEFT"] = function()
		local WaveManager = getWaveManager()
		if WaveManager then
			push(WaveManager.getState().enemiesRemaining or 0)
		else
			push(0)
		end
	end

	-- BUILDING? ( -- flag )
	-- Are we in build phase?
	dict["BUILDING?"] = function()
		local WaveManager = getWaveManager()
		if WaveManager then
			push(WaveManager.getPhase() == "BUILD" and -1 or 0)
		else
			push(0)
		end
	end

	-- FIGHTING? ( -- flag )
	-- Are we in combat phase?
	dict["FIGHTING?"] = function()
		local WaveManager = getWaveManager()
		if WaveManager then
			push(WaveManager.getPhase() == "COMBAT" and -1 or 0)
		else
			push(0)
		end
	end

	-- READY ( -- )
	-- Signal player is ready to start (in lobby)
	dict["READY"] = function()
		if not isPlayer() then return end

		local WaveManager = getWaveManager()
		if WaveManager and self.player then
			WaveManager.playerReady(self.player.UserId)
			self.safeOutput("READY!")
		end
	end
end

return LogisticsWords
