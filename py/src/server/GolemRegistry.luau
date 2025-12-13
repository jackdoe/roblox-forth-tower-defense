-- GolemRegistry.luau
-- Manages programmable turrets (Golems) for Tower Defense
-- Each Golem has its own Interpreter running Python code!

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

-- Import Python GameAPI for creating game environments
local Python = nil  -- Loaded after ReplicatedStorage is ready

local GolemRegistry = {}

-- Ground level Y coordinate
local GROUND_Y = Config.PLATFORM_Y

local golems = {}
local deps = nil
local Interpreter = nil
local WaveManager = nil
local EnemyManager = nil

-- Free placement system
local mapData = nil
local restrictedZones = {}
local golemMinDistance = 8
local nextGolemNumber = 1 -- For generating sequential IDs

-- Single golem type - weapons are determined by ammo used
-- Buffed for "Action Strategy" feel
local GolemStats = {
	name = "Golem",
	modelName = "Turret", -- Use turret model for all
	hp = 200,          -- Was 100. More durable.
	maxAmmo = 300,     -- Was 100. Capacity tripled.
	range = 40,        -- Was 30. See enemies sooner.
	cost = 100,        -- Keep cost low for army building.
}

-- Ammo type stats (damage, cost, fireRate, range bonus, effect)
-- Buffed for "Big Boom" feel - special weapons are viable primary weapons
local AmmoStats = {
	[1] = {                              -- BULLET
		name = "BULLET",
		damage = 15,                     -- Was 10. Machine gun feel.
		ammoCost = 1,
		fireRate = 0.2,                  -- Was 0.3. Shoots faster.
		color = Color3.fromRGB(255, 255, 200), -- Yellow tracer
	},
	[2] = {                              -- ROCKET
		name = "ROCKET",
		damage = 80,                     -- Was 50. Big boom!
		ammoCost = 4,                    -- Was 5. Slightly cheaper.
		fireRate = 1.0,
		splashRadius = 12,               -- Was 8. Bigger BOOM.
		color = Color3.fromRGB(255, 100, 50), -- Orange tracer
	},
	[3] = {                              -- LASER
		name = "LASER",
		damage = 40,                     -- Was 25. Sniper damage.
		ammoCost = 2,
		fireRate = 0.1,                  -- Was 0.5. LASER BEAM (rapid fire).
		color = Color3.fromRGB(255, 50, 50), -- Red beam
	},
	[4] = {                              -- ICE
		name = "ICE",
		damage = 20,                     -- Was 15.
		ammoCost = 2,                    -- Was 3. Cheaper crowd control.
		fireRate = 0.4,                  -- Was 0.6. Faster freeze.
		slowAmount = 0.6,                -- Was 0.5. Reduces speed by 60%
		slowDuration = 4.0,              -- Was 3. 4 seconds freeze.
		color = Color3.fromRGB(100, 200, 255), -- Cyan/ice blue
	},
	[5] = {                              -- FREEZE (Strategic Utility)
		name = "FREEZE",
		damage = 0,                      -- No damage! Pure utility.
		ammoCost = 1,                    -- Cheap
		fireRate = 0.1,                  -- Fast spray
		slowAmount = 0.3,                -- Slows TO 70% speed (30% reduction)
		slowDuration = 3.0,
		color = Color3.fromRGB(0, 255, 255), -- Cyan
	},
}

-- Default program for new golems (Python!)
local DEFAULT_PROGRAM = [[
# Shoot nearest, reload when low
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]]

-- Remote events
local golemStateEvent = nil
local golemPlaceAtEvent = nil -- Free placement
local golemSellEvent = nil    -- Sell/delete golem
local golemFullStateEvent = nil
local golemRegisterViewerEvent = nil
local golemUnregisterViewerEvent = nil

-- Viewer management for Golem Mind Mode
local golemViewers = {} -- {golemId -> {player1, player2, ...}}

-- Active boosts (from BOOST word)
local activeBoosts = {} -- { golemId = { multiplier = 2, expires = tick() + 10 } }

--============================================================================
-- INITIALIZATION
--============================================================================

function GolemRegistry.init(dependencies, interpreterModule)
	deps = dependencies
	Interpreter = interpreterModule

	-- Load Python module
	local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
	Python = require(PythonTD.Python)

	-- Create remote events

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

	-- Handle free placement requests
	golemPlaceAtEvent.OnServerEvent:Connect(function(player, x, z)
		local success, result = GolemRegistry.tryPlaceAt(player, x, z)
		-- Send result back to player
		golemPlaceAtEvent:FireClient(player, success, result)
	end)

	-- Handle sell requests
	golemSellEvent.OnServerEvent:Connect(function(player, golemId)
		local success, result = GolemRegistry.sellGolem(player, golemId)
		golemSellEvent:FireClient(player, success, result)
	end)

	-- Handle viewer registration (Golem Mind Mode)
	golemRegisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
		if not golemViewers[golemId] then
			golemViewers[golemId] = {}
		end
		table.insert(golemViewers[golemId], player)
		print("GolemRegistry: Player", player.Name, "registered as viewer for golem", golemId)
	end)

	-- Handle viewer unregistration
	golemUnregisterViewerEvent.OnServerEvent:Connect(function(player, golemId)
		if golemViewers[golemId] then
			for i, p in ipairs(golemViewers[golemId]) do
				if p == player then
					table.remove(golemViewers[golemId], i)
					print("GolemRegistry: Player", player.Name, "unregistered from golem", golemId)
					break
				end
			end
		end
	end)

	print("GolemRegistry: Initialized")
end

function GolemRegistry.setWaveManager(waveMgr)
	WaveManager = waveMgr
end

-- Expose events for main.server to listen to
function GolemRegistry.getViewerEvents()
	return golemRegisterViewerEvent, golemUnregisterViewerEvent
end

function GolemRegistry.setEnemyManager(enemyMgr)
	EnemyManager = enemyMgr
end

function GolemRegistry.setMapData(map)
	mapData = map
	restrictedZones = map.restrictedZones or {}
	golemMinDistance = map.golemMinDistance or 8
	print("GolemRegistry: Map data loaded with", #restrictedZones, "restricted zones")
end

--============================================================================
-- ZONE VALIDATION (for free placement)
--============================================================================

local function isPointInCircle(px, pz, cx, cz, radius)
	local dx = px - cx
	local dz = pz - cz
	return (dx * dx + dz * dz) <= (radius * radius)
end

local function isPointInRect(px, pz, x1, z1, x2, z2)
	return px >= x1 and px <= x2 and pz >= z1 and pz <= z2
end

local function isPointNearLine(px, pz, x1, z1, x2, z2, width)
	-- Calculate distance from point to line segment
	local dx = x2 - x1
	local dz = z2 - z1
	local len2 = dx * dx + dz * dz

	if len2 == 0 then
		-- Line is a point
		return isPointInCircle(px, pz, x1, z1, width / 2)
	end

	-- Project point onto line
	local t = math.max(0, math.min(1, ((px - x1) * dx + (pz - z1) * dz) / len2))
	local projX = x1 + t * dx
	local projZ = z1 + t * dz

	local distX = px - projX
	local distZ = pz - projZ
	local dist = math.sqrt(distX * distX + distZ * distZ)

	return dist <= (width / 2)
end

function GolemRegistry.isInRestrictedZone(x, z)
	if not mapData then return false end

	local mapWidth = (mapData.width or 50) * 6 -- Assuming 6 studs per cell
	local mapHeight = (mapData.height or 50) * 6

	for _, zone in ipairs(restrictedZones) do
		-- SKIP PATH RESTRICTIONS - enemies walk through turrets, so paths are buildable!
		-- Only block "core" and "boundary" zones
		if zone.reason == "path" then
			continue
		end

		if zone.type == "circle" then
			if isPointInCircle(x, z, zone.x, zone.z, zone.radius) then
				return true, zone.reason
			end
		elseif zone.type == "rect" then
			if isPointInRect(x, z, zone.x1, zone.z1, zone.x2, zone.z2) then
				return true, zone.reason
			end
		elseif zone.type == "line" then
			-- Skip line restrictions (these are typically paths)
			continue
		elseif zone.type == "boundary" then
			local margin = zone.margin or 10
			if x < margin or x > mapWidth - margin or z < margin or z > mapHeight - margin then
				return true, zone.reason
			end
		end
	end

	return false
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
	-- Check restricted zones
	local inZone, reason = GolemRegistry.isInRestrictedZone(x, z)
	if inZone then
		return false, "Cannot build here: " .. (reason or "restricted area")
	end

	-- Check distance from other golems
	if GolemRegistry.isTooCloseToOtherGolem(x, z) then
		return false, "Too close to another golem"
	end

	return true
end

--============================================================================
-- GOLEM CREATION
--============================================================================

-- Maximum turrets per player
local MAX_TURRETS = 10

-- Place golem at any valid position
function GolemRegistry.tryPlaceAt(player, x, z)
	-- 1. CAP CHECK: Count how many golems this player owns
	local myTurretCount = 0
	for _, golem in pairs(golems) do
		if golem.ownerId == player.UserId then
			myTurretCount = myTurretCount + 1
		end
	end

	if myTurretCount >= MAX_TURRETS then
		return false, "Max turrets reached (" .. MAX_TURRETS .. ")"
	end

	-- 2. Validate placement position
	local canPlace, reason = GolemRegistry.canPlaceAt(x, z)
	if not canPlace then
		return false, reason
	end

	-- 3. Check player has enough scrap
	if WaveManager then
		local scrap = WaveManager.getScrap()
		if scrap < GolemStats.cost then
			return false, "Not enough scrap (" .. scrap .. "/" .. GolemStats.cost .. ")"
		end

		-- Deduct cost
		WaveManager.removeScrap(GolemStats.cost)
	end

	-- 4. Create the golem
	local golemId = GolemRegistry.create(x, z)
	if golemId then
		-- Assign a sequential number for display
		golems[golemId].spotId = nextGolemNumber
		golems[golemId].ownerId = player.UserId
		nextGolemNumber = nextGolemNumber + 1

		-- Set attribute for client lookup
		GolemRegistry.setGolemAttribute(golems[golemId])

		print("GolemRegistry: Player", player.Name, "placed golem", myTurretCount + 1, "/", MAX_TURRETS)
		GolemRegistry.broadcastState()
		return true, golemId
	end

	return false, "Failed to create golem"
end

-- Sell a golem and reclaim scraps (partial refund)
function GolemRegistry.sellGolem(player, golemId)
	local golem = golems[golemId]
	if not golem then
		return false, "Golem not found"
	end

	-- Check ownership
	if golem.ownerId ~= player.UserId then
		return false, "You don't own this golem"
	end

	-- Calculate refund (75% of cost)
	local refund = math.floor(GolemStats.cost * 0.75)

	-- Refund scrap
	if WaveManager then
		WaveManager.addScrap(refund)
	end

	-- Destroy the golem
	GolemRegistry.destroy(golemId)

	print("GolemRegistry: Player", player.Name, "sold golem for", refund, "scrap")
	GolemRegistry.broadcastState()

	return true, refund
end

function GolemRegistry.create(x, z)
	-- Create model
	local character = GolemRegistry.createModel(x, z)
	if not character then return nil end

	-- Create interpreter for this golem
	local interp = Interpreter.new(nil, true, deps) -- isMonster = true for tick rate
	interp.character = character
	interp.isGolem = true

	-- Golem-specific state (unified for all golems)
	interp.hp = GolemStats.hp
	interp.maxHp = GolemStats.hp
	interp.ammo = GolemStats.maxAmmo
	interp.maxAmmo = GolemStats.maxAmmo
	interp.range = GolemStats.range
	interp.dynamicRange = GolemStats.range
	interp.lastFireTime = 0
	interp.lastAmmoType = nil -- Track last ammo type for fire rate
	interp.target = nil    -- Current target enemy ID
	interp.status = "IDLE"

	-- Generate ID
	local id = game:GetService("HttpService"):GenerateGUID()
	interp.id = id

	-- Create golem data
	local golem = {
		id = id,
		interpreter = interp,
		character = character,
		typeData = GolemStats,
		spotId = nil,
		ownerId = nil,

		-- Visual state
		facingAngle = 0,
		targetAngle = 0,
		barrelTilt = 0,

		-- Command Queue: External commands from Player mainframe
		taskQueue = {},  -- { {type="SET_MODE", args={mode="rapid"}}, ... }
		currentTask = nil,
		-- Override mode (set by mainframe, overrides internal program temporarily)
		overrideMode = nil,  -- "rapid", "eco", "sniper", etc.
	}

	golems[id] = golem

	-- Set up Python game environment for this golem
	if Python and Python.createGolemEnvironment then
		local envDeps = {
			GolemRegistry = GolemRegistry,
			EnemyManager = EnemyManager,
			WaveManager = WaveManager,
		}
		local gameEnv = Python.createGolemEnvironment(golem, envDeps)
		interp:setGameEnvironment(gameEnv)
	end

	-- Load default program
	interp:load(DEFAULT_PROGRAM)
	interp.lastProgram = DEFAULT_PROGRAM

	-- Register with EntityRegistry
	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = id,
			isGolem = true,
			character = character,
			hp = interp.hp,
			maxHp = interp.maxHp,
		})
	end

	-- Create billboard
	GolemRegistry.createBillboard(golem)

	print("GolemRegistry: Created golem at", x, z)
	return id
end

function GolemRegistry.createModel(x, z)
	local model = Instance.new("Model")
	model.Name = "HeavyBunkerTurret"

	-- Helper to weld parts easily
	local function weldTo(part0, part1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = part0
		w.Part1 = part1
		w.Parent = part0
	end

	-- Color Palette based on image
	local armorColor = Color3.fromRGB(200, 200, 210) -- Light Grey/White Armor
	local darkColor = Color3.fromRGB(50, 50, 55)  -- Dark Grey mechanical parts
	local neonColor = Color3.fromRGB(0, 255, 255) -- Cyan for lights (optional pop)

	-- 1. ROOT (Invisible center)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4, 4, 4)
	root.Position = Vector3.new(x, GROUND_Y + 2, z)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	-- ==========================================
	-- 2. THE BASE (Hexagonal Skirt)
	-- ==========================================

	-- Central Pillar (Hides gaps inside the skirt)
	local basePillar = Instance.new("Part")
	basePillar.Name = "BasePillar"
	basePillar.Shape = Enum.PartType.Cylinder
	basePillar.Size = Vector3.new(3, 3.5, 3.5) -- Height, Dia, Dia (Rotated)
	basePillar.Position = Vector3.new(x, GROUND_Y + 1.5, z)
	basePillar.Orientation = Vector3.new(0, 0, 90)
	basePillar.Material = Enum.Material.Metal
	basePillar.Color = darkColor
	basePillar.Anchored = true
	basePillar.Parent = model

	-- The 6 Armor Plates (Wedges)
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		local radius = 2.2 -- How far out the plates sit

		local wedge = Instance.new("WedgePart")
		wedge.Name = "ArmorSkirt"
		wedge.Size = Vector3.new(2, 2.5, 2) -- Width, Height, Thickness
		wedge.Material = Enum.Material.Metal
		wedge.Color = armorColor
		wedge.Anchored = true
		wedge.CanCollide = true -- The base can be solid

		-- Position: Center + Offset
		local offset = Vector3.new(math.sin(angle) * radius, GROUND_Y + 1.25, math.cos(angle) * radius)
		local pos = Vector3.new(x, 0, z) + offset

		-- Orientation: Look at center, then flip so slope faces outward
		wedge.CFrame = CFrame.lookAt(pos, Vector3.new(x, GROUND_Y, z))
		wedge.Parent = model

		-- Add the "Vent" detail between plates (from image)
		local vent = Instance.new("Part")
		vent.Size = Vector3.new(0.5, 1.5, 0.2)
		vent.Color = darkColor
		vent.Material = Enum.Material.Neon                -- Make it glow slightly
		vent.Anchored = true
		vent.CFrame = wedge.CFrame * CFrame.new(1.1, -0.5, 0.5) -- Position in the gap
		vent.Parent = model
	end

	-- ==========================================
	-- 3. THE TURRET HEAD (Rotating Assembly)
	-- ==========================================

	-- Main Rotating Block (The "Head")
	local head = Instance.new("Part")
	head.Name = "Head" -- SCRIPT LOOKS FOR THIS NAME
	head.Size = Vector3.new(2.5, 2.5, 3)
	head.Position = Vector3.new(x, GROUND_Y + 3.5, z)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.Metal
	head.Color = armorColor
	head.Parent = model

	-- Detail: Top Hatch
	local hatch = Instance.new("Part")
	hatch.Size = Vector3.new(1.5, 0.2, 1.5)
	hatch.Color = darkColor
	hatch.CFrame = head.CFrame * CFrame.new(0, 1.3, 0)
	hatch.Anchored = false -- Must be unanchored for weld to work
	hatch.CanCollide = false
	hatch.Parent = model
	weldTo(head, hatch)

	-- Detail: Side "Ears" (The large cylinders on the sides)
	for _, side in ipairs({ -1, 1 }) do
		local ear = Instance.new("Part")
		ear.Shape = Enum.PartType.Cylinder
		ear.Size = Vector3.new(1, 2.5, 2.5) -- Height (X axis relative), Dia, Dia
		ear.Color = armorColor
		ear.Material = Enum.Material.Metal
		ear.Anchored = false -- Must be unanchored for weld to work
		ear.CanCollide = false
		-- Rotate cylinder so flat side faces out (Z axis rotation)
		ear.CFrame = head.CFrame * CFrame.new(side * 1.5, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		ear.Parent = model
		weldTo(head, ear)

		-- Inner darker circle on the ear
		local earCap = Instance.new("Part")
		earCap.Shape = Enum.PartType.Cylinder
		earCap.Size = Vector3.new(1.1, 1.5, 1.5)
		earCap.Color = darkColor
		earCap.Material = Enum.Material.Metal
		earCap.Anchored = false -- Must be unanchored for weld to work
		earCap.CanCollide = false
		earCap.CFrame = head.CFrame * CFrame.new(side * 1.5, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		earCap.Parent = model
		weldTo(head, earCap)
	end

	-- ==========================================
	-- 4. THE BARREL (Gun Assembly)
	-- ==========================================

	-- Gun Mantlet (The boxy part connecting barrel to head)
	local mantlet = Instance.new("Part")
	mantlet.Size = Vector3.new(1.2, 1.2, 1.5)
	mantlet.Color = darkColor
	mantlet.Material = Enum.Material.DiamondPlate
	mantlet.Anchored = false                         -- Must be unanchored for weld to work
	mantlet.CanCollide = false
	mantlet.CFrame = head.CFrame * CFrame.new(0, 0, -2) -- Stick out front
	mantlet.Parent = model
	weldTo(head, mantlet)                            -- Weld to head so it rotates

	-- The Main Barrel
	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"              -- SCRIPT LOOKS FOR THIS NAME
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3, 0.8, 0.8) -- Height (Length), Dia, Dia (Rotated)
	barrel.Color = armorColor           -- White barrel like image
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = false             -- Must be unanchored for weld to work
	barrel.CanCollide = false
	-- Cylinder default orientation is sideways, rotate to point forward
	barrel.CFrame = mantlet.CFrame * CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(90), 0)
	barrel.Parent = model
	weldTo(head, barrel)

	-- Muzzle Brake (The tip)
	local tip = Instance.new("Part")
	tip.Name = "Tip"                 -- Used for muzzle flash origin
	tip.Shape = Enum.PartType.Cylinder
	tip.Size = Vector3.new(1, 1.2, 1.2) -- Slightly fatter than barrel
	tip.Color = darkColor
	tip.Material = Enum.Material.Metal
	tip.Anchored = false                          -- Must be unanchored for weld to work
	tip.CanCollide = false
	tip.CFrame = barrel.CFrame * CFrame.new(2, 0, 0) -- Relative to barrel cylinder (X is length)
	tip.Parent = model
	weldTo(head, tip)

	-- Detail: Dark ring inside barrel (fake hole)
	local hole = Instance.new("Part")
	hole.Shape = Enum.PartType.Cylinder
	hole.Size = Vector3.new(0.1, 0.6, 0.6)
	hole.Color = Color3.new(0, 0, 0)
	hole.Anchored = false -- Must be unanchored for weld to work
	hole.CanCollide = false
	hole.CFrame = tip.CFrame * CFrame.new(0.5, 0, 0)
	hole.Parent = model
	weldTo(head, hole)

	-- Position and parent
	model.Parent = workspace

	return model
end

-- Set GolemId attribute after creation (called from create())
function GolemRegistry.setGolemAttribute(golem)
	if golem and golem.character then
		golem.character:SetAttribute("GolemId", golem.id)
		golem.character:SetAttribute("SpotId", golem.spotId)
	end
end

function GolemRegistry.createBillboard(golem)
	local character = golem.character
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	-- Billboard GUI
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GolemBillboard"
	billboard.Size = UDim2.new(0, 120, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = hrp

	-- Background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	-- ID Label (big, prominent)
	local idLabel = Instance.new("TextLabel")
	idLabel.Name = "IdLabel"
	idLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
	idLabel.Position = UDim2.new(0, 4, 0, 2)
	idLabel.BackgroundTransparency = 1
	idLabel.Text = "#" .. (golem.spotId or "?")
	idLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	idLabel.Font = Enum.Font.GothamBold
	idLabel.TextSize = 18
	idLabel.TextXAlignment = Enum.TextXAlignment.Left
	idLabel.Parent = bg

	-- Status Label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0.6, 0, 0.3, 0)
	statusLabel.Position = UDim2.new(0.35, 0, 0.05, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "IDLE"
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 10
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Parent = bg

	-- Power Bar (based on range - lower range = more power)
	local powerBg = Instance.new("Frame")
	powerBg.Name = "PowerBarBg"
	powerBg.Size = UDim2.new(0.9, 0, 0.15, 0)
	powerBg.Position = UDim2.new(0.05, 0, 0.4, 0)
	powerBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	powerBg.BorderSizePixel = 0
	powerBg.Parent = bg

	local powerBar = Instance.new("Frame")
	powerBar.Name = "PowerBar"
	powerBar.Size = UDim2.new(1, 0, 1, 0)
	powerBar.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	powerBar.BorderSizePixel = 0
	powerBar.Parent = powerBg

	-- Ammo Bar
	local ammoBg = Instance.new("Frame")
	ammoBg.Name = "AmmoBarBg"
	ammoBg.Size = UDim2.new(0.9, 0, 0.15, 0)
	ammoBg.Position = UDim2.new(0.05, 0, 0.6, 0)
	ammoBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	ammoBg.BorderSizePixel = 0
	ammoBg.Parent = bg

	local ammoBar = Instance.new("Frame")
	ammoBar.Name = "AmmoBar"
	ammoBar.Size = UDim2.new(1, 0, 1, 0)
	ammoBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	ammoBar.BorderSizePixel = 0
	ammoBar.Parent = ammoBg

	-- Power/Range label (shows multiplier and range)
	local powerLabel = Instance.new("TextLabel")
	powerLabel.Name = "PowerLabel"
	powerLabel.Size = UDim2.new(1, 0, 0.2, 0)
	powerLabel.Position = UDim2.new(0, 0, 0.78, 0)
	powerLabel.BackgroundTransparency = 1
	powerLabel.Text = "1.0x @ 40"
	powerLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	powerLabel.Font = Enum.Font.Code
	powerLabel.TextSize = 9
	powerLabel.Parent = bg

	golem.billboard = billboard
end

--============================================================================
-- COMMAND QUEUE SYSTEM (Machinist Architecture)
--============================================================================

-- Issue a command to a golem (from Player mainframe script)
function GolemRegistry.issueCommand(golemId, commandType, args)
	local golem = golems[golemId]
	if not golem then return false end

	-- Add to task queue
	table.insert(golem.taskQueue, {
		type = commandType,
		args = args or {},
		startTime = tick(),
	})
	return true
end

-- Set golem mode (rapid, eco, sniper, etc.)
-- Modes affect fire rate and ammo consumption
function GolemRegistry.setMode(golemId, mode)
	local golem = golems[golemId]
	if not golem then return false end

	golem.overrideMode = mode
	local interp = golem.interpreter

	-- Apply mode settings
	if mode == "rapid" then
		interp.dynamicRange = 30  -- Short range
		interp.fireRateMultiplier = 2.0  -- Double fire rate
	elseif mode == "eco" then
		interp.dynamicRange = 40  -- Normal range
		interp.fireRateMultiplier = 0.5  -- Half fire rate, saves ammo
	elseif mode == "sniper" then
		interp.dynamicRange = 60  -- Long range
		interp.fireRateMultiplier = 0.75
	elseif mode == "shotgun" then
		interp.dynamicRange = 15  -- Very short range
		interp.fireRateMultiplier = 1.5
	else
		-- Reset to default
		golem.overrideMode = nil
		interp.dynamicRange = 40
		interp.fireRateMultiplier = 1.0
	end

	return true
end

-- Force golem to target specific enemy
function GolemRegistry.forceTarget(golemId, enemyId)
	local golem = golems[golemId]
	if not golem then return false end
	golem.interpreter.target = enemyId
	return true
end

-- Clear all commands from a golem
function GolemRegistry.clearCommands(golemId)
	local golem = golems[golemId]
	if not golem then return end
	golem.taskQueue = {}
	golem.currentTask = nil
	golem.overrideMode = nil
	golem.interpreter.fireRateMultiplier = 1.0
end

-- Execute golem task (returns: "RUNNING", "DONE", or "FAILED")
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

-- Get all golems owned by a player (for Machinist API)
function GolemRegistry.getByOwner(ownerId)
	local result = {}
	for id, golem in pairs(golems) do
		if golem.ownerId == ownerId then
			table.insert(result, golem)
		end
	end
	return result
end

-- Check if golem is currently firing
function GolemRegistry.isFiring(golemId)
	local golem = golems[golemId]
	if not golem then return false end
	return golem.interpreter.target ~= nil
end

--============================================================================
-- UPDATE LOOP
--============================================================================

function GolemRegistry.update(dt)
	for id, golem in pairs(golems) do
		local interp = golem.interpreter
		local character = golem.character

		if not character or not character.Parent then
			continue
		end

		-- Dead?
		if interp.hp <= 0 then
			GolemRegistry.destroy(id)
			continue
		end

		-- RELOAD PROCESSING
		-- If reload is pending, wait for stockpile and collect over time
		if interp.reloadPending then
			local reload = interp.reloadPending
			local elapsed = tick() - reload.startTime

			-- Try to pull from stockpile each tick until we have enough
			if reload.collected < reload.amount then
				local stillNeed = reload.amount - reload.collected
				if WaveManager and WaveManager.removeCoreStockpile then
					local taken = WaveManager.removeCoreStockpile(math.min(stillNeed, 10))  -- Take up to 10 per tick
					if taken > 0 then
						reload.collected = reload.collected + taken
						interp.ammo = (interp.ammo or 0) + taken
					end
				end
			end

			-- Check if reload is complete (collected enough AND duration elapsed)
			if reload.collected >= reload.amount and elapsed >= reload.duration then
				interp.reloadPending = nil
				-- Unblock the VM
				local vm = interp.runtime and interp.runtime.vm
				if vm and vm.unblock then
					vm:unblock()
				end
			end
			-- No timeout - reload waits forever until stockpile has resources
		end

		-- COMMAND QUEUE PROCESSING (Machinist Architecture)
		-- Process any queued commands from Player mainframe
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

		-- Only run interpreter if not paused
		if not interp.paused then
			-- Auto-restart looping programs when done (but NOT when error - let error show!)
			if interp.status == "DONE" then
				interp:reset()
				-- Re-load the program to restart
				if interp.lastProgram then
					interp:load(interp.lastProgram)
				end
			end
			-- Don't auto-restart on ERROR - let user see the error on billboard

			-- Golems run at their own tick rate
			golem.tickAccum = (golem.tickAccum or 0) + dt
			if golem.tickAccum >= (deps.Config.GOLEM_TICK_RATE or 0.1) then
				golem.tickAccum = 0
				if interp.status == "READY" or interp.status == "RUNNING" then
					local freeSteps = deps.Config.GOLEM_FREE_STEPS_PER_TICK or 8
					interp:run(deps.Config.GOLEM_TICKS_PER_UPDATE or 1, freeSteps)
				end
			end
		end

		-- Update visual aiming
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

		-- Smooth rotation toward target
		local angleDiff = golem.targetAngle - golem.facingAngle
		while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
		while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
		golem.facingAngle = golem.facingAngle + angleDiff * 0.15

		-- Update head rotation (welded parts follow automatically)
		local head = character:FindFirstChild("Head")
		if head then
			local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
			if hrp then
				-- Set head CFrame - all welded parts (ears, mantlet, barrel, tip) follow
				head.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0)) *
					CFrame.Angles(0, golem.facingAngle, 0)
			end
		end

		-- Update billboard
		GolemRegistry.updateBillboard(golem)
	end
end

function GolemRegistry.updateBillboard(golem)
	local billboard = golem.billboard
	if not billboard then return end

	local interp = golem.interpreter
	local bg = billboard:FindFirstChild("Background")
	if not bg then return end

	-- Update ID
	local idLabel = bg:FindFirstChild("IdLabel")
	if idLabel then
		idLabel.Text = "#" .. (golem.spotId or "?")
	end

	-- Update status
	local statusLabel = bg:FindFirstChild("StatusLabel")
	if statusLabel then
		if interp.error and interp.error ~= "" then
			-- Show error message (truncate to 25 chars)
			local errorMsg = interp.error:sub(1, 25)
			statusLabel.Text = "ERR: " .. errorMsg
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif interp.status == "RUNNING" then
			statusLabel.Text = "RUNNING"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif interp.ammo <= 0 then
			statusLabel.Text = "EMPTY"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif interp.target then
			statusLabel.Text = "FIRING"
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		else
			statusLabel.Text = "IDLE"
			statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end

	-- Update Power bar (based on dynamicRange)
	-- Range 10 = 4x power, Range 40 = 1x power, Range 60 = 0.66x power
	local powerBarBg = bg:FindFirstChild("PowerBarBg")
	if powerBarBg then
		local powerBar = powerBarBg:FindFirstChild("PowerBar")
		if powerBar then
			local currentRange = interp.dynamicRange or 40
			local powerMultiplier = 40 / currentRange
			-- Normalize to bar: 0.66x = 0.165, 1x = 0.25, 4x = 1.0
			-- Map range 10-60 to bar 1.0-0.166
			local barRatio = math.clamp((60 - currentRange) / 50, 0, 1)
			powerBar.Size = UDim2.new(barRatio, 0, 1, 0)

			-- Color based on power level
			if powerMultiplier >= 2 then
				powerBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- Red = High damage
			elseif powerMultiplier >= 1 then
				powerBar.BackgroundColor3 = Color3.fromRGB(255, 200, 100) -- Orange = Normal
			else
				powerBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255) -- Blue = Long range
			end
		end
	end

	-- Update Ammo bar
	local ammoBarBg = bg:FindFirstChild("AmmoBarBg")
	if ammoBarBg then
		local ammoBar = ammoBarBg:FindFirstChild("AmmoBar")
		if ammoBar then
			local ratio = interp.ammo / interp.maxAmmo
			ammoBar.Size = UDim2.new(ratio, 0, 1, 0)
			if ratio > 0.3 then
				ammoBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
			else
				ammoBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			end
		end
	end

	-- Update power label (shows multiplier and range)
	local powerLabel = bg:FindFirstChild("PowerLabel")
	if powerLabel then
		local currentRange = interp.dynamicRange or 40
		local powerMultiplier = 40 / currentRange
		powerLabel.Text = string.format("%.1fx @ %d", powerMultiplier, currentRange)
	end
end

--============================================================================
-- GOLEM ACTIONS (called by GolemWords)
--============================================================================

function GolemRegistry.fire(golemId, ammoType, skipCooldown)
	local golem = golems[golemId]
	if not golem then return false end

	-- Get ammo stats (default to BULLET if invalid)
	local ammoStats = AmmoStats[ammoType] or AmmoStats[1]

	local interp = golem.interpreter

	-- 1. Determine Range and Damage Multiplier
	-- Math:
	-- 10 Range = 4.0x Damage (Shotgun)
	-- 40 Range = 1.0x Damage (Standard)
	-- 60 Range = 0.66x Damage (Sniper)
	local baseRange = 40 -- Standard range
	local currentRange = interp.dynamicRange or baseRange
	local damageMult = baseRange / currentRange

	-- Check if enough ammo
	if interp.ammo < ammoStats.ammoCost then
		return false
	end

	-- Check for active boost (from BOOST word) or mode override
	local fireRateMult = interp.fireRateMultiplier or 1
	local boost = activeBoosts[golemId]
	if boost then
		if tick() < boost.expires then
			fireRateMult = fireRateMult * boost.multiplier
		else
			activeBoosts[golemId] = nil -- Expired
		end
	end

	-- Check fire rate (per ammo type) - skip for burst fire (2FIRE, 3FIRE)
	local now = tick()
	local adjustedFireRate = ammoStats.fireRate / fireRateMult
	if not skipCooldown and now - interp.lastFireTime < adjustedFireRate then
		return false
	end

	-- Check target is valid
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

	-- Check Actual Distance against Dynamic Range
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

	-- Fire! Consume ammo
	interp.ammo = interp.ammo - ammoStats.ammoCost
	interp.lastFireTime = now

	-- Calculate Final Damage
	local finalDamage = math.floor(ammoStats.damage * damageMult)

	-- Deal damage (splash for rockets)
	if ammoStats.splashRadius and ammoStats.splashRadius > 0 then
		-- AOE damage for rockets
		local enemies = EnemyManager.getAll and EnemyManager.getAll() or {}
		for _, e in pairs(enemies) do
			if e.hp > 0 and e.character then
				local eHrp = e.character:FindFirstChild("HumanoidRootPart")
				if eHrp then
					local eDist = (eHrp.Position - enemyHrp.Position).Magnitude
					if eDist <= ammoStats.splashRadius then
						-- Check shatter combo (frozen + rocket = 1.5x damage)
						local damageToApply = finalDamage
						if EnemyManager.checkShatterCombo then
							damageToApply = EnemyManager.checkShatterCombo(e.id, finalDamage)
						end
						-- Damage falls off with distance
						local falloff = 1 - (eDist / ammoStats.splashRadius) * 0.5
						EnemyManager.damage(e.id, math.floor(damageToApply * falloff), golemId)
						-- ROCKET applies "oiled" status (for shock combo)
						if EnemyManager.applyOiled then
							EnemyManager.applyOiled(e.id, 5)
						end
					end
				end
			end
		end
	else
		-- Single target damage
		if finalDamage > 0 then
			EnemyManager.damage(interp.target, finalDamage, golemId)
		end
	end

	-- Apply slow effect for ICE/FREEZE ammo
	if ammoStats.slowAmount and ammoStats.slowDuration then
		EnemyManager.applySlow(interp.target, ammoStats.slowAmount, ammoStats.slowDuration)
	end

	-- LASER applies "burning" status (DoT + chain lightning combo)
	if ammoType == 3 and EnemyManager.applyBurning then
		EnemyManager.applyBurning(interp.target, 3, 5) -- 3 seconds, 5 damage per tick
	end

	-- Visual effect
	GolemRegistry.createMuzzleFlash(golem, enemyHrp.Position, ammoStats)

	return true
end

function GolemRegistry.createMuzzleFlash(golem, targetPos, ammoStats)
	local character = golem.character
	local barrel = character:FindFirstChild("Barrel")
	-- If we have a dedicated tip, use that as origin
	local tip = character:FindFirstChild("Tip")
	local origin = tip and tip.Position or (barrel and barrel.Position) or character.PrimaryPart.Position
	local color = ammoStats and ammoStats.color or Color3.fromRGB(255, 255, 200)

	-- 1. Flash - expanding ball
	task.spawn(function()
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.new(1, 1, 1)
		flash.Position = origin
		flash.Anchored = true
		flash.CanCollide = false
		flash.Material = Enum.Material.Neon
		flash.Color = color
		flash.Transparency = 0.2
		flash.Parent = workspace

		-- Expand and fade
		local tween = TweenService:Create(flash, TweenInfo.new(0.1), { Size = Vector3.new(3, 3, 3), Transparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		flash:Destroy()
	end)

	-- 2. Beam/Tracer
	local dist = (targetPos - origin).Magnitude

	local beamPart = Instance.new("Part")
	beamPart.Name = "LaserBeam"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = color
	beamPart.Size = Vector3.new(0.2, 0.2, dist)
	beamPart.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -dist / 2)
	beamPart.Parent = workspace

	-- Rockets are thicker and have explosion
	if ammoStats and ammoStats.splashRadius then
		beamPart.Size = Vector3.new(0.4, 0.4, dist)

		task.spawn(function()
			task.wait(0.05)
			beamPart:Destroy()

			-- Explosion
			local explosion = Instance.new("Part")
			explosion.Name = "Explosion"
			explosion.Shape = Enum.PartType.Ball
			explosion.Size = Vector3.new(2, 2, 2)
			explosion.Position = targetPos
			explosion.Anchored = true
			explosion.CanCollide = false
			explosion.Material = Enum.Material.Neon
			explosion.Color = color
			explosion.Parent = workspace

			-- Tween explosion expand and fade
			local explodeTween = TweenService:Create(explosion, TweenInfo.new(0.15), {
				Size = Vector3.new(12, 12, 12),
				Transparency = 1,
			})
			explodeTween:Play()
			explodeTween.Completed:Wait()
			explosion:Destroy()
		end)
	else
		-- Beam fade out
		local tween = TweenService:Create(beamPart, TweenInfo.new(0.15),
			{ Transparency = 1, Size = Vector3.new(0, 0, dist) })
		tween:Play()
		task.delay(0.15, function()
			beamPart:Destroy()
		end)
	end
end

--============================================================================
-- PROGRAM MANAGEMENT
--============================================================================

function GolemRegistry.uploadProgram(golemId, source, autoStart)
	local golem = golems[golemId]
	if not golem then return false, "Golem not found" end

	local interp = golem.interpreter
	local success = interp:load(source)

	if success then
		-- Start program immediately if autoStart is true (default behavior)
		if autoStart ~= false then
			interp.paused = false
		end
		print("GolemRegistry: Uploaded new program to golem", golemId)
		return true
	else
		return false, interp.error or "Compilation failed"
	end
end

function GolemRegistry.getProgram(golemId)
	local golem = golems[golemId]
	if not golem then return nil end

	-- Return the source code
	return golem.interpreter.source or ""
end

--============================================================================
-- QUERIES
--============================================================================

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

-- Apply a temporary fire rate boost (from BOOST word)
function GolemRegistry.applyBoost(golemId, multiplier, duration)
	activeBoosts[golemId] = {
		multiplier = multiplier,
		expires = tick() + duration
	}

	-- Visual Effect: OVERDRIVE!
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

		-- Tween text up
		TweenService:Create(p, TweenInfo.new(1), {
			Position = p.Position + Vector3.new(0, 5, 0)
		}):Play()
	end

	print("GolemRegistry: Turret #" .. golemId .. " BOOSTED " .. multiplier .. "x for " .. duration .. "s")
end

--============================================================================
-- DESTRUCTION
--============================================================================

function GolemRegistry.destroy(id)
	local golem = golems[id]
	if not golem then return end

	-- Unregister
	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(id)
	end

	-- Destroy model
	if golem.character then
		golem.character:Destroy()
	end

	golems[id] = nil
	print("GolemRegistry: Destroyed golem", id)
end

function GolemRegistry.clear()
	for id in pairs(golems) do
		GolemRegistry.destroy(id)
	end

	-- Reset golem counter
	nextGolemNumber = 1
end

--============================================================================
-- ZONE VISUALIZATION
--============================================================================

function GolemRegistry.createZoneVisuals()
	if not mapData then return end

	-- Clear existing visuals
	local existingFolder = workspace:FindFirstChild("ZoneVisuals")
	if existingFolder then
		existingFolder:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "ZoneVisuals"
	folder.Parent = workspace

	local pathMaterial = Enum.Material.ForceField
	-- local pathColor = Color3.fromRGB(255, 100, 100)  -- Red tint for paths
	local pathColor = Color3.fromRGB(50, 200, 255)
	local pathTransparency = 0.85

	for i, zone in ipairs(restrictedZones) do
		if zone.type == "circle" and zone.reason ~= "boundary" then
			local part = Instance.new("Part")
			part.Name = "Zone_" .. i .. "_" .. zone.reason
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.5, zone.radius * 2, zone.radius * 2)
			part.Position = Vector3.new(zone.x, GROUND_Y + 0.3, zone.z)
			part.Orientation = Vector3.new(0, 0, 90)
			part.Anchored = true
			part.CanCollide = false
			part.Material = pathMaterial
			part.Color = zone.reason == "core" and Color3.fromRGB(100, 200, 255) or pathColor
			part.Transparency = pathTransparency
			part.Parent = folder
		elseif zone.type == "rect" then
			local width = zone.x2 - zone.x1
			local depth = zone.z2 - zone.z1
			local part = Instance.new("Part")
			part.Name = "Zone_" .. i .. "_" .. zone.reason
			part.Size = Vector3.new(width, 0.5, depth)
			part.Position = Vector3.new(zone.x1 + width / 2, GROUND_Y + 0.3, zone.z1 + depth / 2)
			part.Anchored = true
			part.CanCollide = false
			part.Material = pathMaterial
			part.Color = pathColor
			part.Transparency = pathTransparency
			part.Parent = folder
		elseif zone.type == "line" then
			-- Create a series of parts along the line
			local dx = zone.x2 - zone.x1
			local dz = zone.z2 - zone.z1
			local length = math.sqrt(dx * dx + dz * dz)
			local angle = math.atan2(dx, dz)

			local part = Instance.new("Part")
			part.Name = "Zone_" .. i .. "_" .. zone.reason
			part.Size = Vector3.new(zone.width, 0.5, length)
			part.Position = Vector3.new((zone.x1 + zone.x2) / 2, GROUND_Y + 0.3, (zone.z1 + zone.z2) / 2)
			part.Orientation = Vector3.new(0, math.deg(angle), 0)
			part.Anchored = true
			part.CanCollide = false
			part.Material = pathMaterial
			part.Color = pathColor
			part.Transparency = pathTransparency
			part.Parent = folder
		end
	end

	print("GolemRegistry: Created zone visuals")
end

--============================================================================
-- STATE BROADCAST
--============================================================================

-- Returns current state data (used by RequestState)
function GolemRegistry.getStateForPlayer(player)
	local golemList = {}
	for id, golem in pairs(golems) do
		local interp = golem.interpreter
		table.insert(golemList, {
			id = id,
			spotId = golem.spotId,
			typeName = golem.typeData.name,
			hp = interp.hp,
			maxHp = interp.maxHp,
			ammo = interp.ammo,
			maxAmmo = interp.maxAmmo,
			dynamicRange = interp.dynamicRange or 40,
			status = interp.ammo <= 0 and "EMPTY" or (interp.target and "FIRING" or "IDLE"),
		})
	end
	return { golems = golemList }
end

function GolemRegistry.broadcastState()
	local data = GolemRegistry.getStateForPlayer(nil)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		golemStateEvent:FireClient(player, data)
	end
end

-- Send state to a specific player (called when client requests state)
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
	return GolemStats
end

--============================================================================
-- UPDATE HEARTBEAT
--============================================================================

function GolemRegistry.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		GolemRegistry.update(dt)
		-- Note: Full interpreter state is now sent by main.server based on playerViewingGolem
	end)
end

return GolemRegistry
