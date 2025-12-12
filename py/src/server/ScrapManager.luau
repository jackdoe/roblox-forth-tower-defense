-- ScrapManager.luau
-- Manages physical scrap drops in the world
-- Scrap drops when enemies die and must be collected by Supply Bots!

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local ScrapManager = {}

-- Ground level Y coordinate
local GROUND_Y = Config.PLATFORM_Y

local scrapPiles = {} -- id -> ScrapData
local deps = nil

-- Spatial partitioning for efficient lookups
local GRID_CELL_SIZE = 20
local scrapGrid = {} -- "gx_gz" -> { scrapData, ... }

-- Scrap visual settings
local SCRAP_LIFETIME = 60 -- Seconds before auto-despawn
local SCRAP_COLLECT_RANGE = 8 -- Studs

--============================================================================
-- INITIALIZATION
--============================================================================

function ScrapManager.init(dependencies)
	deps = dependencies
	print("ScrapManager: Initialized")
end

--============================================================================
-- HELPERS
--============================================================================

local function getGridKey(x, z)
	local gx = math.floor(x / GRID_CELL_SIZE)
	local gz = math.floor(z / GRID_CELL_SIZE)
	return gx .. "_" .. gz
end

local function addToGrid(scrap)
	if not scrap.part or not scrap.part.Parent then return end
	local pos = scrap.part.Position
	local key = getGridKey(pos.X, pos.Z)
	if not scrapGrid[key] then
		scrapGrid[key] = {}
	end
	table.insert(scrapGrid[key], scrap)
end

local function removeFromGrid(scrap)
	if not scrap.gridKey then return end
	local cell = scrapGrid[scrap.gridKey]
	if cell then
		for i, s in ipairs(cell) do
			if s.id == scrap.id then
				table.remove(cell, i)
				break
			end
		end
	end
end

local function rebuildGrid()
	table.clear(scrapGrid)
	for id, scrap in pairs(scrapPiles) do
		if scrap.part and scrap.part.Parent then
			local pos = scrap.part.Position
			local key = getGridKey(pos.X, pos.Z)
			scrap.gridKey = key
			if not scrapGrid[key] then
				scrapGrid[key] = {}
			end
			table.insert(scrapGrid[key], scrap)
		end
	end
end

--============================================================================
-- SPAWNING
--============================================================================

function ScrapManager.spawn(position, amount)
	local id = game:GetService("HttpService"):GenerateGUID()

	-- Create visual scrap pile
	local part = Instance.new("Part")
	part.Name = "Scrap_" .. id
	part.Size = Vector3.new(1.5, 1.5, 1.5)
	part.Position = position + Vector3.new(0, 2, 0) -- Spawn slightly above ground
	part.Color = Color3.fromRGB(255, 200, 50) -- Gold/Scrap color
	part.Material = Enum.Material.Metal
	part.Anchored = false
	part.CanCollide = true
	part.Shape = Enum.PartType.Block

	-- Add a slight glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 0.5
	light.Range = 6
	light.Parent = part

	-- Scatter physics - make it bounce and roll
	part.Velocity = Vector3.new(
		(math.random() - 0.5) * 20,
		15 + math.random() * 10,
		(math.random() - 0.5) * 20
	)
	part.RotVelocity = Vector3.new(
		math.random() * 5,
		math.random() * 5,
		math.random() * 5
	)

	part.Parent = workspace

	-- Make it settle and become anchored after physics settles
	task.delay(2, function()
		if part and part.Parent then
			part.Anchored = true
			part.CanCollide = false -- Bots walk through it
		end
	end)

	-- Billboard showing amount
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 50, 0, 20)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = tostring(amount)
	label.TextColor3 = Color3.fromRGB(255, 255, 200)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	-- Create scrap data
	local scrapData = {
		id = id,
		part = part,
		amount = amount,
		created = tick(),
		gridKey = nil,
	}

	scrapPiles[id] = scrapData

	-- Auto-cleanup after lifetime
	task.delay(SCRAP_LIFETIME, function()
		if scrapPiles[id] then
			ScrapManager.remove(id)
		end
	end)

	return id
end

--============================================================================
-- REMOVAL
--============================================================================

function ScrapManager.remove(id)
	local scrap = scrapPiles[id]
	if not scrap then return end

	removeFromGrid(scrap)

	if scrap.part then
		-- Fade out effect
		task.spawn(function()
			local part = scrap.part
			if part and part.Parent then
				local tween = TweenService:Create(part, TweenInfo.new(0.3), {
					Transparency = 1,
					Size = Vector3.new(0.1, 0.1, 0.1),
				})
				tween:Play()
				tween.Completed:Wait()
				part:Destroy()
			end
		end)
	end

	scrapPiles[id] = nil
end

--============================================================================
-- COLLECTION (called by bots)
--============================================================================

function ScrapManager.collect(id, collectorInterp)
	local scrap = scrapPiles[id]
	if not scrap then return 0 end

	-- Calculate how much can be collected
	local available = scrap.amount
	local capacity = (collectorInterp.maxCapacity or 50) - (collectorInterp.scrapInventory or 0)
	local toCollect = math.min(available, capacity)

	if toCollect <= 0 then
		return 0 -- Bot is full
	end

	-- Transfer scrap
	scrap.amount = scrap.amount - toCollect
	collectorInterp.scrapInventory = (collectorInterp.scrapInventory or 0) + toCollect

	-- Update billboard or remove if empty
	if scrap.amount <= 0 then
		ScrapManager.remove(id)
	else
		-- Update label
		local billboard = scrap.part and scrap.part:FindFirstChild("BillboardGui")
		if billboard then
			local label = billboard:FindFirstChild("TextLabel")
			if label then
				label.Text = tostring(scrap.amount)
			end
		end
	end

	return toCollect
end

--============================================================================
-- QUERIES
--============================================================================

function ScrapManager.get(id)
	return scrapPiles[id]
end

function ScrapManager.getAll()
	return scrapPiles
end

function ScrapManager.count()
	local n = 0
	for _ in pairs(scrapPiles) do n = n + 1 end
	return n
end

function ScrapManager.findNearest(x, z, maxRange)
	local nearest = nil
	local nearestDistSq = maxRange and (maxRange * maxRange) or math.huge

	-- Simple linear search through all scrap (grid may be stale for new scrap)
	for id, scrap in pairs(scrapPiles) do
		if scrap.part and scrap.part.Parent and scrap.amount > 0 then
			local pos = scrap.part.Position
			local dx = pos.X - x
			local dz = pos.Z - z
			local distSq = dx * dx + dz * dz
			if distSq < nearestDistSq then
				nearestDistSq = distSq
				nearest = scrap
			end
		end
	end

	return nearest, nearest and math.sqrt(nearestDistSq) or (maxRange or math.huge)
end

function ScrapManager.findInRange(x, z, range)
	local results = {}
	local rangeSq = range * range

	-- Simple linear search through all scrap
	for id, scrap in pairs(scrapPiles) do
		if scrap.part and scrap.part.Parent and scrap.amount > 0 then
			local pos = scrap.part.Position
			local dx = pos.X - x
			local dz = pos.Z - z
			local distSq = dx * dx + dz * dz
			if distSq <= rangeSq then
				table.insert(results, scrap)
			end
		end
	end

	return results
end

function ScrapManager.getTotalScrapOnGround()
	local total = 0
	for _, scrap in pairs(scrapPiles) do
		total = total + scrap.amount
	end
	return total
end

--============================================================================
-- UPDATE LOOP
--============================================================================

function ScrapManager.update(dt)
	-- Rebuild spatial grid periodically (scrap doesn't move after settling)
	rebuildGrid()
end

function ScrapManager.startUpdateLoop()
	-- Update grid every second (scrap is mostly static)
	task.spawn(function()
		while true do
			rebuildGrid()
			task.wait(1)
		end
	end)
end

--============================================================================
-- CLEAR
--============================================================================

function ScrapManager.clear()
	for id, scrap in pairs(scrapPiles) do
		if scrap.part then
			scrap.part:Destroy()
		end
	end
	scrapPiles = {}
	table.clear(scrapGrid)
end

return ScrapManager
