-- BotRegistry.luau
-- Manages mobile Supply Bots for Tower Defense
-- Bots are "dumb workers" - they have no internal program.
-- They are controlled entirely by the Machinist (player's Python script).
--
-- GAMEPLAY CONCEPT:
-- Bots collect physical scrap dropped by enemies and deliver it to turrets.
-- The player's Machinist script orchestrates all bot behavior from a central location.
-- Commands: bot.supply(turret), bot.collect(scrap_id), bot.move(x,z)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local BotRegistry = {}

-- Ground level Y coordinate
local GROUND_Y = Config.PLATFORM_Y

local bots = {}
local deps = nil
local WaveManager = nil
local InterpreterModule = nil  -- For bot programs
local GameAPI = nil            -- For bot environment

local nextBotNumber = 1

-- Default program for new bots (Python!)
-- Kid-friendly with visual feedback and easy commands
local DEFAULT_PROGRAM = [[
# My helpful bot!
self.say("Ready!")
self.color("cyan")

while True:
    if self.is_full():
        self.say("Delivering!")
        self.goto(T1)
        self.supply(T1)
    else:
        s = self.scraps()
        if len(s) > 0:
            self.collect(s[0])
]]

-- Bot stats
local BotStats = {
	name = "SupplyBot",
	hp = 50,
	speed = 14,
	maxCapacity = 50, -- Can carry 50 scrap
	pickupRange = 8,
	transferRange = 10,
	cost = 75, -- Scrap cost to build
}

-- Remote events
local botStateEvent = nil
local botBuildEvent = nil
local botSellEvent = nil
local botRegisterViewerEvent = nil
local botUnregisterViewerEvent = nil

--============================================================================
-- INITIALIZATION
--============================================================================

function BotRegistry.init(dependencies, interpreterModule)
	deps = dependencies
	InterpreterModule = interpreterModule

	-- Load GameAPI for bot environment (shared modules are in ReplicatedStorage)
	local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
	GameAPI = require(PythonTD.Python.GameAPI)

	-- Create remote events
	botStateEvent = Instance.new("RemoteEvent")
	botStateEvent.Name = "BotState"
	botStateEvent.Parent = PythonTD

	botBuildEvent = Instance.new("RemoteEvent")
	botBuildEvent.Name = "BotBuild"
	botBuildEvent.Parent = PythonTD

	botSellEvent = Instance.new("RemoteEvent")
	botSellEvent.Name = "BotSell"
	botSellEvent.Parent = PythonTD

	-- Viewer events kept for compatibility but bots are no longer programmable
	botRegisterViewerEvent = Instance.new("RemoteEvent")
	botRegisterViewerEvent.Name = "BotRegisterViewer"
	botRegisterViewerEvent.Parent = PythonTD

	botUnregisterViewerEvent = Instance.new("RemoteEvent")
	botUnregisterViewerEvent.Name = "BotUnregisterViewer"
	botUnregisterViewerEvent.Parent = PythonTD

	-- Handle build requests
	botBuildEvent.OnServerEvent:Connect(function(player, x, z)
		local success, result = BotRegistry.tryBuild(player, x, z)
		botBuildEvent:FireClient(player, success, result)
	end)

	-- Handle sell requests
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

--============================================================================
-- BOT CREATION
--============================================================================

local MAX_BOTS_PER_PLAYER = 5

function BotRegistry.tryBuild(player, x, z)
	-- Count player's bots
	local myBotCount = 0
	for _, bot in pairs(bots) do
		if bot.ownerId == player.UserId then
			myBotCount = myBotCount + 1
		end
	end

	if myBotCount >= MAX_BOTS_PER_PLAYER then
		return false, "Max bots reached (" .. MAX_BOTS_PER_PLAYER .. ")"
	end

	-- Check scrap
	if WaveManager then
		local scrap = WaveManager.getScrap(player.UserId)
		if scrap < BotStats.cost then
			return false, "Not enough scrap (" .. scrap .. "/" .. BotStats.cost .. ")"
		end
		WaveManager.removeScrap(player.UserId, BotStats.cost)
	end

	-- Create the bot
	local botId = BotRegistry.create(x, z)
	if botId then
		bots[botId].ownerId = player.UserId
		bots[botId].spotId = nextBotNumber
		nextBotNumber = nextBotNumber + 1

		print("BotRegistry: Player", player.Name, "built bot", myBotCount + 1, "/", MAX_BOTS_PER_PLAYER)
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

	-- Refund: 50% cost + any scrap the bot is carrying
	local refund = math.floor(BotStats.cost * 0.5)
	local carryingScrap = bot.scrapInventory or 0
	refund = refund + carryingScrap

	if WaveManager then
		WaveManager.addScrap(player.UserId, refund)
	end

	BotRegistry.destroy(botId)

	print("BotRegistry: Player", player.Name, "sold bot for", refund, "scrap")
	BotRegistry.broadcastState()

	return true, refund
end

function BotRegistry.create(x, z)
	-- Create model
	local character = BotRegistry.createModel(x, z)
	if not character then return nil end

	-- Generate ID
	local id = game:GetService("HttpService"):GenerateGUID()

	-- Create bot data
	local bot = {
		id = id,
		character = character,
		spotId = nil,
		ownerId = nil,

		-- Bot state
		hp = BotStats.hp,
		maxHp = BotStats.hp,
		scrapInventory = 0,
		maxCapacity = BotStats.maxCapacity,
		speed = BotStats.speed,
		pickupRange = BotStats.pickupRange,
		transferRange = BotStats.transferRange,

		-- Movement state
		moveTargetX = nil,
		moveTargetZ = nil,
		isMoving = false,

		-- Command Queue: Controlled by either self.program or Machinist
		taskQueue = {},  -- { {type="SUPPLY", target=golemSpotId}, ... }
		currentTask = nil,
		waitingForTask = false,  -- When true, interpreter yields until task completes

		-- Status for UI
		status = "IDLE",

		-- Interpreter for bot programs (optional - can also be controlled by Machinist)
		interpreter = nil,

		-- Shield system
		shieldActive = false,
		shieldCooldownUntil = 0,
	}

	bots[id] = bot

	-- Create interpreter for bot programs
	if InterpreterModule then
		bot.interpreter = InterpreterModule.new(nil, true, deps)  -- isMonster=true means no player
		bot.interpreter.character = character

		-- Set up bot game environment
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

		-- Load default program
		bot.interpreter:load(DEFAULT_PROGRAM)
		bot.interpreter.lastProgram = DEFAULT_PROGRAM
	end

	-- Set BotId attribute on model (for client click detection)
	character:SetAttribute("BotId", id)

	-- Register with EntityRegistry
	if deps.EntityRegistry then
		deps.EntityRegistry.register({
			id = id,
			isBot = true,
			character = character,
			hp = bot.hp,
			maxHp = bot.maxHp,
		})
	end

	-- Create billboard
	BotRegistry.createBillboard(bot)

	print("BotRegistry: Created bot at", x, z)
	return id
end

-- Color Palette for Scrappy Bot
local COLORS = {
	RUST_ORANGE = Color3.fromRGB(215, 135, 70),
	DARK_METAL  = Color3.fromRGB(45, 50, 55),
	JOINT_GREY  = Color3.fromRGB(80, 85, 90),
	NEON_CYAN   = Color3.fromRGB(0, 255, 255),
	GOLD_SCRAP  = Color3.fromRGB(255, 215, 0),
}

function BotRegistry.createModel(x, z)
	local model = Instance.new("Model")
	model.Name = "ScrappyBot"

	-- Helper for creating blocky parts
	local function makePart(name, size, color, mat, parent, posOffset)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.Plastic
		p.Anchored = false
		p.CanCollide = false
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = model

		-- Weld to parent
		if parent then
			p.CFrame = parent.CFrame * posOffset
			local w = Instance.new("WeldConstraint")
			w.Part0 = parent
			w.Part1 = p
			w.Parent = parent
		end
		return p
	end

	-- 1. Main Root (invisible, anchored - we move this)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 2)
	hrp.Position = Vector3.new(x, GROUND_Y + 2.5, z)
	hrp.Transparency = 1
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Parent = model
	model.PrimaryPart = hrp

	-- 2. Torso (The Orange Block)
	local torso = makePart("Torso", Vector3.new(2.2, 1.8, 1.5), COLORS.RUST_ORANGE, Enum.Material.Metal, hrp, CFrame.new(0, 0, 0))

	-- Torso Vent Detail
	makePart("Vent", Vector3.new(1.4, 0.8, 0.1), COLORS.DARK_METAL, Enum.Material.DiamondPlate, torso, CFrame.new(0, -0.2, -0.76))

	-- 3. Head (Chunky, sitting on top)
	local head = makePart("Head", Vector3.new(2.4, 1.6, 1.6), COLORS.RUST_ORANGE, Enum.Material.Metal, torso, CFrame.new(0, 1.7, 0))

	-- Faceplate (Dark area)
	makePart("Faceplate", Vector3.new(2.0, 1.2, 0.1), COLORS.DARK_METAL, Enum.Material.Plastic, head, CFrame.new(0, 0, -0.8))

	-- Eyes (Glowing Cyan)
	makePart("LeftEye", Vector3.new(0.5, 0.6, 0.1), COLORS.NEON_CYAN, Enum.Material.Neon, head, CFrame.new(-0.5, 0.1, -0.86))
	makePart("RightEye", Vector3.new(0.5, 0.6, 0.1), COLORS.NEON_CYAN, Enum.Material.Neon, head, CFrame.new(0.5, 0.1, -0.86))

	-- Antenna
	makePart("AntennaStem", Vector3.new(0.1, 0.8, 0.1), COLORS.DARK_METAL, Enum.Material.Plastic, head, CFrame.new(0.5, 1.0, 0))
	makePart("AntennaBulb", Vector3.new(0.3, 0.3, 0.3), COLORS.GOLD_SCRAP, Enum.Material.Neon, head, CFrame.new(0.5, 1.5, 0))

	-- 4. Arms (Stubby industrial)
	local leftShoulder = makePart("LeftShoulder", Vector3.new(0.5, 0.5, 0.5), COLORS.JOINT_GREY, Enum.Material.Plastic, torso, CFrame.new(-1.35, 0.5, 0))
	local rightShoulder = makePart("RightShoulder", Vector3.new(0.5, 0.5, 0.5), COLORS.JOINT_GREY, Enum.Material.Plastic, torso, CFrame.new(1.35, 0.5, 0))

	makePart("LeftArm", Vector3.new(0.4, 1.2, 0.8), COLORS.RUST_ORANGE, Enum.Material.Metal, leftShoulder, CFrame.new(-0.1, -0.8, 0))
	makePart("RightArm", Vector3.new(0.4, 1.2, 0.8), COLORS.RUST_ORANGE, Enum.Material.Metal, rightShoulder, CFrame.new(0.1, -0.8, 0))

	-- 5. Feet (Chunky boots)
	makePart("LeftFoot", Vector3.new(0.8, 0.6, 1.2), COLORS.DARK_METAL, Enum.Material.DiamondPlate, torso, CFrame.new(-0.6, -1.5, 0))
	makePart("RightFoot", Vector3.new(0.8, 0.6, 1.2), COLORS.DARK_METAL, Enum.Material.DiamondPlate, torso, CFrame.new(0.6, -1.5, 0))

	-- 6. Backpack (Cargo Container)
	local backpack = makePart("Backpack", Vector3.new(1.8, 1.2, 0.8), COLORS.DARK_METAL, Enum.Material.Plastic, torso, CFrame.new(0, 0.2, 0.9))

	-- Scrap Pile (grows based on cargo)
	local scrapPile = makePart("ScrapPile", Vector3.new(1.6, 0.1, 0.6), COLORS.GOLD_SCRAP, Enum.Material.Foil, backpack, CFrame.new(0, 0.65, 0))
	scrapPile.Transparency = 1 -- Hidden initially

	-- 7. Chat Bubble Anchor
	local chatPart = Instance.new("Part")
	chatPart.Name = "ChatHead"
	chatPart.Transparency = 1
	chatPart.Size = Vector3.new(0.1, 0.1, 0.1)
	chatPart.Anchored = false
	chatPart.CanCollide = false
	chatPart.CFrame = head.CFrame * CFrame.new(0, 1.5, 0)
	chatPart.Parent = model

	local chatWeld = Instance.new("WeldConstraint")
	chatWeld.Part0 = head
	chatWeld.Part1 = chatPart
	chatWeld.Parent = head

	local bg = Instance.new("BillboardGui")
	bg.Name = "ChatBubble"
	bg.Size = UDim2.new(0, 120, 0, 40)
	bg.StudsOffset = Vector3.new(0, 0.5, 0)
	bg.AlwaysOnTop = true
	bg.Parent = chatPart

	local bubble = Instance.new("Frame")
	bubble.Name = "Bubble"
	bubble.Size = UDim2.new(1, 0, 1, 0)
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.BackgroundTransparency = 1
	bubble.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = bubble

	local chatText = Instance.new("TextLabel")
	chatText.Name = "Text"
	chatText.Size = UDim2.new(1, -10, 1, -6)
	chatText.Position = UDim2.new(0, 5, 0, 3)
	chatText.BackgroundTransparency = 1
	chatText.Text = ""
	chatText.TextColor3 = Color3.new(0.2, 0.2, 0.2)
	chatText.TextScaled = true
	chatText.Font = Enum.Font.GothamBold
	chatText.TextTransparency = 1
	chatText.Parent = bubble

	model.Parent = workspace

	-- Animation state
	model:SetAttribute("WalkCycle", 0)
	model:SetAttribute("AnimSpeed", 0)
	model:SetAttribute("BaseY", GROUND_Y + 2.5)
	model:SetAttribute("FacingAngle", 0)
	model:SetAttribute("ChatExpiry", 0)

	return model
end

function BotRegistry.createBillboard(bot)
	local character = bot.character
	local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not hrp then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BotBillboard"
	billboard.Size = UDim2.new(0, 80, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = hrp

	-- Background
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg

	-- Bot ID
	local idLabel = Instance.new("TextLabel")
	idLabel.Name = "IdLabel"
	idLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
	idLabel.Position = UDim2.new(0, 4, 0, 2)
	idLabel.BackgroundTransparency = 1
	idLabel.Text = "B" .. (bot.spotId or "?")
	idLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	idLabel.Font = Enum.Font.GothamBold
	idLabel.TextSize = 14
	idLabel.TextXAlignment = Enum.TextXAlignment.Left
	idLabel.Parent = bg

	-- Cargo amount
	local cargoLabel = Instance.new("TextLabel")
	cargoLabel.Name = "CargoLabel"
	cargoLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
	cargoLabel.Position = UDim2.new(0.4, 0, 0, 2)
	cargoLabel.BackgroundTransparency = 1
	cargoLabel.Text = "0/50"
	cargoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	cargoLabel.Font = Enum.Font.Code
	cargoLabel.TextSize = 12
	cargoLabel.TextXAlignment = Enum.TextXAlignment.Right
	cargoLabel.Parent = bg

	-- Cargo bar
	local cargoBarBg = Instance.new("Frame")
	cargoBarBg.Name = "CargoBarBg"
	cargoBarBg.Size = UDim2.new(0.9, 0, 0.2, 0)
	cargoBarBg.Position = UDim2.new(0.05, 0, 0.55, 0)
	cargoBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	cargoBarBg.BorderSizePixel = 0
	cargoBarBg.Parent = bg

	local cargoBar = Instance.new("Frame")
	cargoBar.Name = "CargoBar"
	cargoBar.Size = UDim2.new(0, 0, 1, 0)
	cargoBar.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	cargoBar.BorderSizePixel = 0
	cargoBar.Parent = cargoBarBg

	-- Status
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0.25, 0)
	statusLabel.Position = UDim2.new(0, 0, 0.75, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "IDLE"
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 9
	statusLabel.Parent = bg

	bot.billboard = billboard
end

--============================================================================
-- COMMAND QUEUE SYSTEM (Machinist Architecture)
--============================================================================

-- Issue a command to a bot (from Player mainframe script)
-- Commands take priority over internal interpreter
-- If blocking=true, the bot's interpreter will yield until the task completes
function BotRegistry.issueCommand(botId, commandType, args, blocking)
	local bot = bots[botId]
	if not bot then return false end

	-- Add to task queue
	table.insert(bot.taskQueue, {
		type = commandType,
		args = args or {},
		startTime = tick(),
	})

	-- If blocking, tell interpreter to wait
	if blocking then
		bot.waitingForTask = true
	end

	return true
end

-- Clear all commands from a bot
function BotRegistry.clearCommands(botId)
	local bot = bots[botId]
	if not bot then return end
	bot.taskQueue = {}
	bot.currentTask = nil
	bot.status = "IDLE"
	bot.isMoving = false
end

-- Execute current task (returns: "RUNNING", "DONE", or "FAILED")
local function executeTask(bot, dt)
	local task = bot.currentTask
	if not task then return "DONE" end

	local character = bot.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return "FAILED" end

	if task.type == "SUPPLY" then
		-- Move to golem and supply
		local spotId = task.args.target
		local GolemRegistry = deps.GolemRegistry
		if not GolemRegistry then return "FAILED" end

		local golem = GolemRegistry.getBySpotId(spotId)
		if not golem or not golem.character then return "FAILED" end

		local golemHrp = golem.character:FindFirstChild("HumanoidRootPart")
		if not golemHrp then return "FAILED" end

		-- Calculate distance
		local dx = golemHrp.Position.X - hrp.Position.X
		local dz = golemHrp.Position.Z - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= (bot.transferRange or 10) then
			-- Close enough - supply and complete
			if (bot.scrapInventory or 0) > 0 then
				BotRegistry.supplyGolem(bot.id, spotId)
			end
			bot.status = "IDLE"
			return "DONE"
		else
			-- Move towards golem
			bot.moveTargetX = golemHrp.Position.X
			bot.moveTargetZ = golemHrp.Position.Z
			bot.isMoving = true
			bot.status = "SUPPLYING"
			return "RUNNING"
		end

	elseif task.type == "COLLECT" then
		-- Move to scrap by ID and collect (legacy)
		local scrapId = task.args.target
		local ScrapManager = deps.ScrapManager
		if not ScrapManager then return "FAILED" end

		local scrap = ScrapManager.get(scrapId)
		if not scrap or not scrap.part or not scrap.part.Parent then
			bot.status = "IDLE"
			return "FAILED"
		end

		local sPos = scrap.part.Position
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

	elseif task.type == "COLLECT_AT" then
		-- Move to position and collect nearest scrap there
		local targetX = task.args.x
		local targetZ = task.args.z
		if not targetX or not targetZ then return "FAILED" end

		local dx = targetX - hrp.Position.X
		local dz = targetZ - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= (bot.pickupRange or 8) then
			-- Close enough - try to collect nearest scrap
			BotRegistry.collectScrap(bot.id)
			bot.status = "IDLE"
			return "DONE"
		else
			bot.moveTargetX = targetX
			bot.moveTargetZ = targetZ
			bot.isMoving = true
			bot.status = "COLLECTING"
			return "RUNNING"
		end

	elseif task.type == "MOVE" then
		-- Move to position
		local targetX = task.args.x
		local targetZ = task.args.z

		local dx = targetX - hrp.Position.X
		local dz = targetZ - hrp.Position.Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist < 2 then
			bot.status = "IDLE"
			return "DONE"
		else
			bot.moveTargetX = targetX
			bot.moveTargetZ = targetZ
			bot.isMoving = true
			bot.status = "MOVING"
			return "RUNNING"
		end

	elseif task.type == "IDLE" then
		-- Wait for specified time
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
	end

	bot.status = "IDLE"
	return "FAILED"
end

--============================================================================
-- UPDATE LOOP
--============================================================================

function BotRegistry.update(dt)
	for id, bot in pairs(bots) do
		local character = bot.character

		if not character or not character.Parent then
			continue
		end

		-- Dead?
		if bot.hp <= 0 then
			BotRegistry.destroy(id)
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
		if not hrp then continue end

		-- Animation state
		local isMoving = bot.isMoving
		local currentSpeed = character:GetAttribute("AnimSpeed") or 0
		local targetSpeed = isMoving and 12 or 0

		-- Smooth animation speed transition
		currentSpeed = currentSpeed + (targetSpeed - currentSpeed) * 5 * dt
		character:SetAttribute("AnimSpeed", currentSpeed)

		-- Increment walk cycle
		local walkCycle = (character:GetAttribute("WalkCycle") or 0) + currentSpeed * dt
		character:SetAttribute("WalkCycle", walkCycle)

		-- Procedural Waddle Animation
		local bounce = math.abs(math.sin(walkCycle)) * 0.25  -- Vertical hop
		local tilt = math.sin(walkCycle * 0.5) * 0.12        -- Side-to-side waddle
		local lean = isMoving and -0.08 or 0                 -- Forward lean

		local baseY = character:GetAttribute("BaseY") or 2.5
		local facingAngle = character:GetAttribute("FacingAngle") or 0

		-- Movement processing
		local newX, newZ = hrp.Position.X, hrp.Position.Z

		if bot.moveTargetX and bot.moveTargetZ then
			local dx = bot.moveTargetX - hrp.Position.X
			local dz = bot.moveTargetZ - hrp.Position.Z
			local dist = math.sqrt(dx * dx + dz * dz)

			if dist < 2 then
				-- Arrived
				bot.moveTargetX = nil
				bot.moveTargetZ = nil
				bot.isMoving = false
			else
				-- Move towards target
				local speed = bot.speed or BotStats.speed
				local moveAmount = math.min(speed * dt, dist)
				local dirX = dx / dist
				local dirZ = dz / dist

				newX = hrp.Position.X + dirX * moveAmount
				newZ = hrp.Position.Z + dirZ * moveAmount

				-- Update facing angle (towards movement direction)
				facingAngle = math.atan2(-dirX, -dirZ)
				character:SetAttribute("FacingAngle", facingAngle)
			end
		end

		-- Emote animations (spin, jump, shake)
		local emoteRotation = 0
		local emoteYOffset = 0
		local emoteTilt = 0

		if bot.emoteEndTime and tick() < bot.emoteEndTime then
			local emoteProgress = 1 - ((bot.emoteEndTime - tick()) / 2)  -- 0 to 1 over duration

			if bot.emoteType == "spin" then
				-- Spin around
				emoteRotation = emoteProgress * math.pi * 8  -- 4 full rotations
			elseif bot.emoteType == "jump" then
				-- Hop up and down
				emoteYOffset = math.sin(emoteProgress * math.pi) * 3
			elseif bot.emoteType == "shake" then
				-- Quick shake side to side
				emoteTilt = math.sin(tick() * 30) * 0.3
			end
		else
			bot.emoteType = nil
			bot.emoteEndTime = nil
		end

		-- Apply position + waddle animation via CFrame
		hrp.CFrame = CFrame.new(newX, baseY + bounce + emoteYOffset, newZ)
			* CFrame.Angles(0, facingAngle + emoteRotation, 0)  -- Face direction + spin
			* CFrame.Angles(lean, emoteTilt, -tilt)     -- Lean + waddle + shake

		-- BOT INTERPRETER (if bot has its own program running)
		-- COMMAND QUEUE (from either bot's own program or Machinist)
		if not bot.currentTask and #bot.taskQueue > 0 then
			bot.currentTask = table.remove(bot.taskQueue, 1)
		end

		if bot.currentTask then
			local taskStatus = executeTask(bot, dt)
			if taskStatus == "DONE" or taskStatus == "FAILED" then
				bot.currentTask = nil
				-- Clear waiting flag when task completes AND no more tasks pending
				if #bot.taskQueue == 0 then
					bot.waitingForTask = false
				end
			end
		end

		-- Run interpreter AFTER task processing, and only if not waiting for a task
		if bot.interpreter and not bot.waitingForTask then
			local status = bot.interpreter.status
			if status == "RUNNING" or status == "READY" then
				bot.interpreter:run(5)  -- Run 5 ticks per frame
			end
		end

		-- Update billboard
		BotRegistry.updateBillboard(bot)

		-- Cargo Visualization (Scrap pile on backpack)
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

		-- Chat Bubble Logic
		local chatHead = character:FindFirstChild("ChatHead")
		if chatHead then
			local chatBubble = chatHead:FindFirstChild("ChatBubble")
			if chatBubble then
				local bubble = chatBubble:FindFirstChild("Bubble")
				local chatText = bubble and bubble:FindFirstChild("Text")
				local chatExpiry = character:GetAttribute("ChatExpiry") or 0

				if tick() > chatExpiry then
					-- Fade out
					if bubble then bubble.BackgroundTransparency = 1 end
					if chatText then chatText.TextTransparency = 1 end
				else
					-- Show
					if bubble then bubble.BackgroundTransparency = 0.1 end
					if chatText then chatText.TextTransparency = 0 end
				end
			end
		end
	end
end

function BotRegistry.updateBillboard(bot)
	local billboard = bot.billboard
	if not billboard then return end

	local bg = billboard:FindFirstChild("Frame") or billboard:FindFirstChildOfClass("Frame")
	if not bg then return end

	-- Update ID
	local idLabel = bg:FindFirstChild("IdLabel")
	if idLabel then
		idLabel.Text = "B" .. (bot.spotId or "?")
	end

	-- Update cargo display
	local cargoLabel = bg:FindFirstChild("CargoLabel")
	if cargoLabel then
		cargoLabel.Text = (bot.scrapInventory or 0) .. "/" .. (bot.maxCapacity or 50)
	end

	-- Update cargo bar
	local cargoBarBg = bg:FindFirstChild("CargoBarBg")
	if cargoBarBg then
		local cargoBar = cargoBarBg:FindFirstChild("CargoBar")
		if cargoBar then
			local ratio = (bot.scrapInventory or 0) / (bot.maxCapacity or 50)
			cargoBar.Size = UDim2.new(ratio, 0, 1, 0)
		end
	end

	-- Update status
	local statusLabel = bg:FindFirstChild("StatusLabel")
	if statusLabel then
		local status = bot.status or "IDLE"
		if bot.isMoving then
			statusLabel.Text = "MOVING"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif (bot.scrapInventory or 0) >= (bot.maxCapacity or 50) then
			statusLabel.Text = "FULL"
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		elseif status == "COLLECTING" then
			statusLabel.Text = "COLLECT"
			statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		elseif status == "SUPPLYING" then
			statusLabel.Text = "SUPPLY"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 200)
		elseif status == "WAITING" then
			statusLabel.Text = "WAIT"
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
		else
			statusLabel.Text = "IDLE"
			statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
end

--============================================================================
-- QUERIES
--============================================================================

function BotRegistry.get(id)
	return bots[id]
end

-- Bots no longer have interpreters - they're controlled by Machinist
function BotRegistry.getInterpreter(id)
	return nil  -- Deprecated
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

-- Get all bots owned by a player (for Machinist API)
function BotRegistry.getByOwner(ownerId)
	local result = {}
	for id, bot in pairs(bots) do
		if bot.ownerId == ownerId then
			table.insert(result, bot)
		end
	end
	return result
end

-- Check if bot is idle (no task, interpreter not blocked)
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
	return BotStats
end

--============================================================================
-- BOT ACTIONS (called by Python GameAPI)
--============================================================================

-- Move bot to position (sets movement target)
function BotRegistry.moveBot(botId, x, z)
	local bot = bots[botId]
	if not bot then return end

	bot.moveTargetX = x
	bot.moveTargetZ = z
	bot.isMoving = true
	bot.status = "MOVING"
end

-- Collect scrap at bot's current position
function BotRegistry.collectScrap(botId)
	local bot = bots[botId]
	if not bot then return 0 end

	local character = bot.character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end

	local ScrapManager = deps.ScrapManager
	if not ScrapManager then return 0 end

	-- Check remaining capacity
	local currentScrap = bot.scrapInventory or 0
	local maxCapacity = bot.maxCapacity or 50
	local space = maxCapacity - currentScrap

	if space <= 0 then
		return 0  -- Already full
	end

	-- Find nearest scrap at current position
	local x, z = hrp.Position.X, hrp.Position.Z
	local scrap = ScrapManager.findNearest(x, z, bot.pickupRange or 8)

	if not scrap or not scrap.id then
		return 0  -- No scrap nearby
	end

	-- Collect the scrap directly (bot doesn't have interpreter)
	local scrapAmount = scrap.value or 1
	local toCollect = math.min(scrapAmount, space)
	bot.scrapInventory = (bot.scrapInventory or 0) + toCollect
	ScrapManager.remove(scrap.id)

	return toCollect
end

-- Supply scrap to golem
function BotRegistry.supplyGolem(botId, spotId)
	local bot = bots[botId]
	if not bot then return 0 end

	local GolemRegistry = deps.GolemRegistry
	if not GolemRegistry then return 0 end

	-- Find golem by spot ID
	local golem = GolemRegistry.getBySpotId(spotId)
	if not golem then return 0 end

	-- Check if bot is close enough
	local botChar = bot.character
	local botHrp = botChar and botChar:FindFirstChild("HumanoidRootPart")
	local golemChar = golem.character
	local golemHrp = golemChar and golemChar:FindFirstChild("HumanoidRootPart")

	if not botHrp or not golemHrp then return 0 end

	local dx = golemHrp.Position.X - botHrp.Position.X
	local dz = golemHrp.Position.Z - botHrp.Position.Z
	local dist = math.sqrt(dx * dx + dz * dz)

	if dist > (bot.transferRange or 10) then
		return 0  -- Too far
	end

	-- Transfer scrap to golem's ammo
	local scrapToGive = bot.scrapInventory or 0
	if scrapToGive <= 0 then return 0 end

	-- Convert scrap to ammo (1:5 ratio)
	local ammoToGive = scrapToGive * 5
	local ammoAdded = GolemRegistry.refillAmmo(golem.id, ammoToGive)
	local scrapUsed = math.ceil(ammoAdded / 5)

	bot.scrapInventory = (bot.scrapInventory or 0) - scrapUsed
	return scrapUsed
end

--============================================================================
-- DAMAGE & DEATH
--============================================================================

function BotRegistry.damage(botId, amount)
	local bot = bots[botId]
	if not bot then return end

	-- Shield blocks damage
	if bot.shieldActive then return end

	bot.hp = bot.hp - amount

	-- Visual Feedback: Flash red
	local char = bot.character
	if char then
		for _, p in pairs(char:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				local oldColor = p.Color
				p.Color = Color3.fromRGB(255, 50, 50)
				task.delay(0.1, function()
					if p and p.Parent then p.Color = oldColor end
				end)
			end
		end

		-- Flash eyes red
		local head = char:FindFirstChild("Head")
		if head then
			local lEye = head:FindFirstChild("LeftEye")
			local rEye = head:FindFirstChild("RightEye")
			if lEye then lEye.Color = Color3.fromRGB(255, 0, 0) end
			if rEye then rEye.Color = Color3.fromRGB(255, 0, 0) end
			task.delay(0.2, function()
				if lEye and lEye.Parent then lEye.Color = Color3.fromRGB(0, 255, 255) end
				if rEye and rEye.Parent then rEye.Color = Color3.fromRGB(0, 255, 255) end
			end)
		end
	end

	-- Update billboard
	BotRegistry.updateBillboard(bot)

	-- Check for death
	if bot.hp <= 0 then
		BotRegistry.kill(botId)
	end
end

local RESPAWN_TIME = 30  -- Respawn after 30 seconds

function BotRegistry.kill(botId)
	local bot = bots[botId]
	if not bot then return end

	-- Save info for respawn
	local ownerId = bot.ownerId
	local spotId = bot.spotId

	-- 1. Drop cargo as scrap
	local cargo = bot.scrapInventory or 0
	if cargo > 0 and deps.ScrapManager and bot.character then
		local hrp = bot.character:FindFirstChild("HumanoidRootPart")
		if hrp then
			deps.ScrapManager.spawn(hrp.Position, cargo)
		end
	end

	-- 2. Explosion effect
	if bot.character and bot.character.PrimaryPart then
		local pos = bot.character.PrimaryPart.Position
		local exp = Instance.new("Explosion")
		exp.Position = pos
		exp.BlastRadius = 0  -- Visual only
		exp.BlastPressure = 0
		exp.Parent = workspace
		game.Debris:AddItem(exp, 2)

		-- Particle burst
		local p = Instance.new("Part")
		p.Size = Vector3.new(0.1, 0.1, 0.1)
		p.Position = pos
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.Parent = workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50))
		emitter.Size = NumberSequence.new(1, 0)
		emitter.Lifetime = NumberRange.new(0.5, 1)
		emitter.Speed = NumberRange.new(10, 20)
		emitter.SpreadAngle = Vector2.new(360, 360)
		emitter.Rate = 0
		emitter.Parent = p
		emitter:Emit(30)
		game.Debris:AddItem(p, 2)
	end

	print("BotRegistry: Bot #" .. (spotId or "?") .. " destroyed! Respawning in " .. RESPAWN_TIME .. "s")

	-- Broadcast death before destroying
	BotRegistry.broadcastState()
	BotRegistry.destroy(botId)

	-- 3. Schedule respawn
	if ownerId and spotId then
		task.delay(RESPAWN_TIME, function()
			-- Respawn at core (0, 0)
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

--============================================================================
-- SHIELD ABILITY
--============================================================================

local SHIELD_COOLDOWN = 60  -- 1 minute cooldown

function BotRegistry.activateShield(botId, duration)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	duration = duration or 3  -- Default 3 seconds

	-- Already shielded?
	if bot.shieldActive then return false end

	-- On cooldown?
	if bot.shieldCooldownUntil and tick() < bot.shieldCooldownUntil then
		return false
	end

	bot.shieldActive = true
	bot.shieldExpires = tick() + duration
	bot.shieldCooldownUntil = tick() + SHIELD_COOLDOWN  -- Start cooldown

	-- Create shield visual
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

		-- Auto-remove after duration
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

--============================================================================
-- DESTRUCTION
--============================================================================

function BotRegistry.destroy(id)
	local bot = bots[id]
	if not bot then return end

	-- Unregister
	if deps.EntityRegistry then
		deps.EntityRegistry.unregister(id)
	end

	-- Destroy model
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

--============================================================================
-- STATE BROADCAST
--============================================================================

function BotRegistry.broadcastState()
	local botList = {}
	for id, bot in pairs(bots) do
		table.insert(botList, {
			id = id,
			spotId = bot.spotId,
			ownerId = bot.ownerId,
			scrapInventory = bot.scrapInventory or 0,
			maxCapacity = bot.maxCapacity or 50,
			hp = bot.hp,
			maxHp = bot.maxHp,
			status = bot.status or "IDLE",
		})
	end

	local data = {
		bots = botList,
	}

	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		botStateEvent:FireClient(player, data)
	end
end

-- Get state for a specific player (called when client requests state)
function BotRegistry.getStateForPlayer(player)
	local botList = {}
	for id, bot in pairs(bots) do
		table.insert(botList, {
			id = id,
			spotId = bot.spotId,
			ownerId = bot.ownerId,
			scrapInventory = bot.scrapInventory or 0,
			maxCapacity = bot.maxCapacity or 50,
			hp = bot.hp,
			maxHp = bot.maxHp,
			status = bot.status or "IDLE",
		})
	end
	return { bots = botList }
end

-- Send state to a specific player (called when client requests state)
function BotRegistry.sendStateToPlayer(player)
	local data = BotRegistry.getStateForPlayer(player)
	botStateEvent:FireClient(player, data)
end

--============================================================================
-- TEMPORARY BOTS (Wave-scoped, die when wave ends)
--============================================================================

function BotRegistry.killTemporaryBots()
	local count = 0
	for id, bot in pairs(bots) do
		if bot.isTemporary then
			-- Visual effect: Meltdown
			if bot.character and bot.character.PrimaryPart then
				-- Particle poof
				local exp = Instance.new("ParticleEmitter")
				exp.Texture = "rbxassetid://243098098"
				exp.Color = ColorSequence.new(Color3.fromRGB(255, 50, 50))
				exp.Size = NumberSequence.new(0.5, 0)
				exp.Lifetime = NumberRange.new(0.5)
				exp.Rate = 100
				exp.Speed = NumberRange.new(5, 10)
				exp.Parent = bot.character.PrimaryPart
				task.delay(0.2, function()
					if exp then exp.Enabled = false end
				end)
			end

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

--============================================================================
-- UPDATE HEARTBEAT
--============================================================================
-- VISUAL & FUN APIs (Kid-friendly features)
--============================================================================

-- Color map for easy color names
local colorMap = {
	red = Color3.fromRGB(255, 80, 80),
	blue = Color3.fromRGB(80, 150, 255),
	green = Color3.fromRGB(80, 255, 80),
	yellow = Color3.fromRGB(255, 255, 80),
	cyan = Color3.fromRGB(80, 255, 255),
	purple = Color3.fromRGB(180, 80, 255),
	pink = Color3.fromRGB(255, 150, 200),
	orange = Color3.fromRGB(255, 180, 80),
	white = Color3.fromRGB(240, 240, 240),
	black = Color3.fromRGB(50, 50, 50),
}

function BotRegistry.setBotColor(botId, colorName)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local col = colorMap[string.lower(colorName or "")] or colorMap.white
	bot.color = col  -- Store for respawn

	-- Apply to visual parts
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

	-- Find head or primary part
	local head = bot.character:FindFirstChild("Head") or bot.character.PrimaryPart
	if not head then return false end

	-- Check for existing or create new BillboardGui
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

		-- Fade out after 3 seconds
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
		-- Spin animation
		bot.emoteEndTime = tick() + 2
		bot.emoteType = "spin"
	elseif emoteName == "jump" or emoteName == "hop" then
		-- Hop animation
		bot.emoteEndTime = tick() + 0.5
		bot.emoteType = "jump"
	elseif emoteName == "shake" or emoteName == "shiver" then
		-- Shake animation
		bot.emoteEndTime = tick() + 1
		bot.emoteType = "shake"
	end

	return true
end

--============================================================================
-- COMBAT APIs
--============================================================================

function BotRegistry.triggerExplosion(botId, damage)
	local bot = bots[botId]
	if not bot or not bot.character then return false end

	local hrp = bot.character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local pos = hrp.Position

	-- Visual explosion
	local exp = Instance.new("Explosion")
	exp.Position = pos
	exp.BlastRadius = 0  -- We handle damage manually
	exp.BlastPressure = 0
	exp.Parent = workspace

	-- Damage enemies in radius
	local EnemyManager = deps.EnemyManager
	if EnemyManager and EnemyManager.findInRange then
		local hitList = EnemyManager.findInRange(pos.X, pos.Z, 15)  -- 15 stud radius
		for _, enemy in ipairs(hitList) do
			if EnemyManager.damage then
				EnemyManager.damage(enemy.id, damage or 200)
			end
		end
	end

	-- Kill the bot (kamikaze)
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
		-- Visual effect: beam/lightning
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

			-- Remove after brief flash
			task.delay(0.15, function()
				if beam and beam.Parent then
					beam:Destroy()
				end
			end)
		end

		-- Deal damage
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

	-- For now, just trigger the zap if that's requested
	if effectType == "zap" then
		return BotRegistry.zapEnemy(botId, 15)
	end
	return false
end

--============================================================================

function BotRegistry.startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		BotRegistry.update(dt)
	end)
end

return BotRegistry
