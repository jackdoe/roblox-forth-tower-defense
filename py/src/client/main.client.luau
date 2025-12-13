-- main.client.luau
-- Client entry point for PythonTD: Iron Defense (Tower Defense)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for modules
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local SoundConfig = require(PythonTD.SoundConfig)
local HelpDatabase = require(PythonTD.HelpDatabase)

-- Client modules
local EditorPanel = require(script.Parent.UI.EditorPanel)
local ProgramPanel = require(script.Parent.UI.ProgramPanel)
local BytecodePanel = require(script.Parent.UI.BytecodePanel)
local UnitListPanel = require(script.Parent.UI.UnitListPanel)
local Effects = require(script.Parent.Effects)
local PlayerHpBillboard = require(script.Parent.PlayerHpBillboard)
local DragModule = require(script.Parent.UI.DragModule)

-- Wait for RemoteEvents
local runProgramEvent = PythonTD:WaitForChild("RunProgram")
local pauseProgramEvent = PythonTD:WaitForChild("PauseProgram")
local stepProgramEvent = PythonTD:WaitForChild("StepProgram")
local resetProgramEvent = PythonTD:WaitForChild("ResetProgram")
local stateUpdateEvent = PythonTD:WaitForChild("StateUpdate")
local attackHitEvent = PythonTD:WaitForChild("AttackHit")
local playerHurtEvent = PythonTD:WaitForChild("PlayerHurt")
local beepEvent = PythonTD:WaitForChild("Beep")
local playAnimationEvent = PythonTD:WaitForChild("PlayAnimation")
local manualAttackEvent = PythonTD:WaitForChild("ManualAttack")

-- TD-specific events
local golemStateEvent = PythonTD:WaitForChild("GolemState")
local playerReadyEvent = PythonTD:WaitForChild("PlayerReady")
local skipBuildEvent = PythonTD:WaitForChild("SkipBuild")
local golemPlaceAtEvent = PythonTD:WaitForChild("GolemPlaceAt")
local golemSellEvent = PythonTD:WaitForChild("GolemSell")
local enterBuildModeEvent = PythonTD:WaitForChild("EnterBuildMode")
local playerTeleportEvent = PythonTD:WaitForChild("PlayerTeleport")
local playerMoveCompleteEvent = PythonTD:WaitForChild("PlayerMoveComplete")

-- Golem Mind Mode events (viewer registration)
local golemRegisterViewerEvent = PythonTD:WaitForChild("GolemRegisterViewer")
local golemUnregisterViewerEvent = PythonTD:WaitForChild("GolemUnregisterViewer")
local golemMoveEvent = PythonTD:WaitForChild("GolemMove")

-- State request (client asks server for current state when ready)
local requestStateEvent = PythonTD:WaitForChild("RequestState")

-- Bot events (Supply Bots)
local botStateEvent = PythonTD:WaitForChild("BotState")
local botBuildEvent = PythonTD:WaitForChild("BotBuild")
local botSellEvent = PythonTD:WaitForChild("BotSell")

-- Bot Mind Mode events (viewer registration)
local botRegisterViewerEvent = PythonTD:WaitForChild("BotRegisterViewer")
local botUnregisterViewerEvent = PythonTD:WaitForChild("BotUnregisterViewer")

-- Track golem states for inspection
local golemStates = {}

-- Track bot states for inspection
local botStates = {}
local botStatesRaw = {} -- List format for UI panel

-- Placement mode state
local placementMode = false
local ghostTurret = nil

-- Track current interpreter target (player, golem, or bot)
-- UI callbacks use this to know which interpreter to apply operations to
local currentInterpreterTarget = {
	type = "player", -- "player", "golem", or "bot"
	golemId = nil,
	botId = nil,
	spotId = nil,
}

-- Save player program when entering golem mind
local savedPlayerProgram = nil
local golemProgramLoaded = false
local playerProgramLoaded = false

-- Range indicator for golem mind mode
local golemMindRangeRing = nil

-- Create main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PythonTDGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Forward declarations
local editor, program
local showHelp -- Forward declaration for help button callback
local showBytecodePanel -- Forward declaration for step button callback

-- Helper to show/hide IDE based on target type
local function updateIDEVisibility()
	local isPlayer = (currentInterpreterTarget.type == "player")
	if editor and editor.frame then
		editor.frame.Visible = not isPlayer
	end
	if program and program.frame then
		program.frame.Visible = not isPlayer
	end
	if bytecodePanel then
		bytecodePanel:setVisible(not isPlayer and bytecodeVisible)
	end
end

-- Create UI panels with callbacks
editor = EditorPanel.create(screenGui, {
	onLoad = function(source)
		-- Turrets are read-only, only bots can be programmed
		if currentInterpreterTarget.type == "golem" then
			print("Turrets are read-only - cannot upload program")
			return
		end
		-- Upload to bot (or player if ever enabled)
		runProgramEvent:FireServer(source, currentInterpreterTarget)
	end,

	onStep = function(source)
		-- Server handles loading/pausing if needed
		stepProgramEvent:FireServer(source, currentInterpreterTarget)
		-- Auto-open bytecode panel when stepping (unless user manually closed it)
		showBytecodePanel()
	end,

	onPause = function()
		pauseProgramEvent:FireServer(currentInterpreterTarget)
	end,

	onReset = function()
		resetProgramEvent:FireServer()
	end,

	onHelp = function()
		showHelp(nil) -- Show general help
	end,
})

program = ProgramPanel.create(screenGui)
local bytecodePanel = BytecodePanel.create(screenGui)

-- Hide IDE initially (player mode = no IDE)
updateIDEVisibility()

-- Bytecode panel toggle state
-- Hidden by default, auto-opens when stepping through code
local bytecodeVisible = false
local bytecodeUserOverride = false  -- True if user manually toggled (respect their choice)
bytecodePanel:setVisible(bytecodeVisible)
program:setBytecodeVisible(bytecodeVisible)

-- Function to show bytecode panel (for step button)
showBytecodePanel = function()
	if not bytecodeUserOverride then
		bytecodeVisible = true
		bytecodePanel:setVisible(true)
		program:setBytecodeVisible(true)
	end
end

-- Wire up bytecode toggle button
program.onBytecodeToggle = function()
	bytecodeVisible = not bytecodeVisible
	bytecodeUserOverride = true  -- User manually toggled, respect their choice
	bytecodePanel:setVisible(bytecodeVisible)
	program:setBytecodeVisible(bytecodeVisible)
end

-- Forward declarations for mind mode callbacks
local enterGolemMindWrapper
local enterBotMindWrapper

-- Unit List Panel (shows both Turrets and Bots)
local unitList = UnitListPanel.create(screenGui, {
	onSelectGolem = function(golemId)
		-- When clicking a turret in the list, enter golem mind mode
		if enterGolemMindWrapper then
			enterGolemMindWrapper(golemId)
		end
	end,
	onSelectBot = function(botId)
		-- When clicking a bot in the list, enter bot mind mode
		if enterBotMindWrapper then
			enterBotMindWrapper(botId)
		end
	end,
})

--============================================================================
-- TOWER DEFENSE HUD - Unified Panel (Bottom Left)
--============================================================================

local currentScrap = 0       -- Track locally for UI updates
local currentTurretCount = 0 -- Track turret count for cap display
local MAX_TURRETS = 10
local currentBotCount = 0 -- Track bot count for cap display
local MAX_BOTS = 5

-- Main panel container
local tdPanel = Instance.new("Frame")
tdPanel.Name = "TDPanel"
tdPanel.Size = UDim2.new(0, 200, 0, 260)
tdPanel.Position = UDim2.new(0, 10, 1, -270)
tdPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
tdPanel.BackgroundTransparency = 0.1
tdPanel.BorderSizePixel = 0
tdPanel.Parent = screenGui

local tdPanelCorner = Instance.new("UICorner")
tdPanelCorner.CornerRadius = UDim.new(0, 8)
tdPanelCorner.Parent = tdPanel

local tdPanelStroke = Instance.new("UIStroke")
tdPanelStroke.Color = Color3.fromRGB(60, 60, 80)
tdPanelStroke.Thickness = 1
tdPanelStroke.Parent = tdPanel

-- Wave header (big and prominent)
local waveLabel = Instance.new("TextLabel")
waveLabel.Name = "Wave"
waveLabel.Size = UDim2.new(1, 0, 0, 28)
waveLabel.Position = UDim2.new(0, 0, 0, 6)
waveLabel.BackgroundTransparency = 1
waveLabel.Text = "WAVE 0"
waveLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
waveLabel.Font = Enum.Font.GothamBold
waveLabel.TextSize = 20
waveLabel.Parent = tdPanel

-- Phase label (below wave)
local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.Size = UDim2.new(1, 0, 0, 16)
phaseLabel.Position = UDim2.new(0, 0, 0, 32)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = "LOBBY"
phaseLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
phaseLabel.Font = Enum.Font.GothamBold
phaseLabel.TextSize = 12
phaseLabel.Parent = tdPanel

-- Divider line
local divider1 = Instance.new("Frame")
divider1.Size = UDim2.new(0.9, 0, 0, 1)
divider1.Position = UDim2.new(0.05, 0, 0, 52)
divider1.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
divider1.BorderSizePixel = 0
divider1.Parent = tdPanel

-- Core HP row
local coreLabel = Instance.new("TextLabel")
coreLabel.Name = "Core"
coreLabel.Size = UDim2.new(1, -10, 0, 18)
coreLabel.Position = UDim2.new(0, 5, 0, 58)
coreLabel.BackgroundTransparency = 1
coreLabel.Text = "CORE: 1000/1000"
coreLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
coreLabel.TextXAlignment = Enum.TextXAlignment.Left
coreLabel.Font = Enum.Font.Code
coreLabel.TextSize = 12
coreLabel.Parent = tdPanel

-- Enemies row
local enemiesLabel = Instance.new("TextLabel")
enemiesLabel.Name = "Enemies"
enemiesLabel.Size = UDim2.new(1, -10, 0, 18)
enemiesLabel.Position = UDim2.new(0, 5, 0, 76)
enemiesLabel.BackgroundTransparency = 1
enemiesLabel.Text = "ENEMIES: 0"
enemiesLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
enemiesLabel.TextXAlignment = Enum.TextXAlignment.Left
enemiesLabel.Font = Enum.Font.Code
enemiesLabel.TextSize = 12
enemiesLabel.Parent = tdPanel

-- Turrets row (shows current / max turrets)
local turretsLabel = Instance.new("TextLabel")
turretsLabel.Name = "Turrets"
turretsLabel.Size = UDim2.new(1, -10, 0, 18)
turretsLabel.Position = UDim2.new(0, 5, 0, 94)
turretsLabel.BackgroundTransparency = 1
turretsLabel.Text = "TURRETS: 0/10"
turretsLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
turretsLabel.TextXAlignment = Enum.TextXAlignment.Left
turretsLabel.Font = Enum.Font.Code
turretsLabel.TextSize = 12
turretsLabel.Parent = tdPanel

-- Scrap row (currency - prominent)
local scrapLabel = Instance.new("TextLabel")
scrapLabel.Name = "Scrap"
scrapLabel.Size = UDim2.new(1, -10, 0, 22)
scrapLabel.Position = UDim2.new(0, 5, 0, 114)
scrapLabel.BackgroundTransparency = 1
scrapLabel.Text = "SCRAP: 600"
scrapLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
scrapLabel.TextXAlignment = Enum.TextXAlignment.Left
scrapLabel.Font = Enum.Font.GothamBold
scrapLabel.TextSize = 14
scrapLabel.Parent = tdPanel

-- Bag row (player's physical scrap inventory - cyan)
local bagLabel = Instance.new("TextLabel")
bagLabel.Name = "Bag"
bagLabel.Size = UDim2.new(1, -10, 0, 18)
bagLabel.Position = UDim2.new(0, 5, 0, 136)
bagLabel.BackgroundTransparency = 1
bagLabel.Text = "BAG: 0/50"
bagLabel.TextColor3 = Color3.fromRGB(0, 200, 255) -- Cyan for physical inventory
bagLabel.TextXAlignment = Enum.TextXAlignment.Left
bagLabel.Font = Enum.Font.Code
bagLabel.TextSize = 12
bagLabel.Parent = tdPanel

-- Timer row (build phase countdown)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, -10, 0, 18)
timerLabel.Position = UDim2.new(0, 5, 0, 154)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Font = Enum.Font.Code
timerLabel.TextSize = 12
timerLabel.Parent = tdPanel

-- Divider line 2
local divider2 = Instance.new("Frame")
divider2.Size = UDim2.new(0.9, 0, 0, 1)
divider2.Position = UDim2.new(0.05, 0, 0, 176)
divider2.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
divider2.BorderSizePixel = 0
divider2.Parent = tdPanel

-- BUILD TURRET BUTTON (left half) - HIDDEN: Pre-placed units, no building phase
local buildBtn = Instance.new("TextButton")
buildBtn.Name = "BuildButton"
buildBtn.Size = UDim2.new(0.44, 0, 0, 32)
buildBtn.Position = UDim2.new(0.03, 0, 0, 184)
buildBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
buildBtn.BorderSizePixel = 0
buildBtn.Text = "TURRET [B]"
buildBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buildBtn.Font = Enum.Font.GothamBold
buildBtn.TextSize = 11
buildBtn.Visible = false -- HIDDEN: No building phase
buildBtn.Parent = tdPanel

local buildBtnCorner = Instance.new("UICorner")
buildBtnCorner.CornerRadius = UDim.new(0, 6)
buildBtnCorner.Parent = buildBtn

-- BUILD BOT BUTTON (right half) - HIDDEN: Pre-placed units, no building phase
local buildBotBtn = Instance.new("TextButton")
buildBotBtn.Name = "BuildBotButton"
buildBotBtn.Size = UDim2.new(0.44, 0, 0, 32)
buildBotBtn.Position = UDim2.new(0.53, 0, 0, 184)
buildBotBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 180)
buildBotBtn.BorderSizePixel = 0
buildBotBtn.Text = "BOT [N]"
buildBotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buildBotBtn.Font = Enum.Font.GothamBold
buildBotBtn.TextSize = 11
buildBotBtn.Visible = false -- HIDDEN: No building phase
buildBotBtn.Parent = tdPanel

local buildBotBtnCorner = Instance.new("UICorner")
buildBotBtnCorner.CornerRadius = UDim.new(0, 6)
buildBotBtnCorner.Parent = buildBotBtn

-- READY BUTTON (for LOBBY phase - replaces build button position)
local readyButton = Instance.new("TextButton")
readyButton.Name = "ReadyButton"
readyButton.Size = UDim2.new(0.9, 0, 0, 32)
readyButton.Position = UDim2.new(0.05, 0, 0, 220)
readyButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
readyButton.BorderSizePixel = 0
readyButton.Text = "READY"
readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
readyButton.Font = Enum.Font.GothamBold
readyButton.TextSize = 13
readyButton.Visible = false
readyButton.Parent = tdPanel

local readyCorner = Instance.new("UICorner")
readyCorner.CornerRadius = UDim.new(0, 6)
readyCorner.Parent = readyButton

-- SKIP BUTTON (for BUILD phase)
local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipButton"
skipButton.Size = UDim2.new(0.9, 0, 0, 32)
skipButton.Position = UDim2.new(0.05, 0, 0, 220)
skipButton.BackgroundColor3 = Color3.fromRGB(180, 120, 50)
skipButton.BorderSizePixel = 0
skipButton.Text = "SKIP BUILD"
skipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
skipButton.Font = Enum.Font.GothamBold
skipButton.TextSize = 13
skipButton.Visible = false
skipButton.Parent = tdPanel

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 6)
skipCorner.Parent = skipButton

-- Forward declarations for placement mode functions
local enterPlacementMode, exitPlacementMode
local enterBotPlacementMode, exitBotPlacementMode

-- Bot placement state
local botPlacementMode = false
local ghostBot = nil

buildBtn.MouseButton1Click:Connect(function()
	if botPlacementMode then exitBotPlacementMode() end
	if placementMode then
		exitPlacementMode()
	else
		enterPlacementMode()
	end
end)

buildBotBtn.MouseButton1Click:Connect(function()
	if placementMode then exitPlacementMode() end
	if botPlacementMode then
		exitBotPlacementMode()
	else
		enterBotPlacementMode()
	end
end)

readyButton.MouseButton1Click:Connect(function()
	playerReadyEvent:FireServer()
	readyButton.Text = "WAITING..."
	readyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
end)

skipButton.MouseButton1Click:Connect(function()
	skipBuildEvent:FireServer()
end)

-- Update button appearance based on Scrap and caps (runs every frame)
-- NOTE: Build buttons are now hidden since we have pre-placed units
game:GetService("RunService").Heartbeat:Connect(function()
	-- Building is disabled - buttons stay hidden
	-- Keep this loop minimal since buttons are not visible
end)

-- Track current phase for button visibility
local currentPhase = "LOBBY"

-- PLAYERS PANEL removed - cleaner UI

--============================================================================
-- DEATH OVERLAY
--============================================================================

local deathOverlay = Instance.new("Frame")
deathOverlay.Name = "DeathOverlay"
deathOverlay.Size = UDim2.new(1, 0, 0, 60)
deathOverlay.Position = UDim2.new(0, 0, 0.4, 0)
deathOverlay.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
deathOverlay.BackgroundTransparency = 0.3
deathOverlay.BorderSizePixel = 0
deathOverlay.Visible = false
deathOverlay.ZIndex = 50
deathOverlay.Parent = screenGui

local deathLabel = Instance.new("TextLabel")
deathLabel.Name = "DeathText"
deathLabel.Size = UDim2.new(1, 0, 1, 0)
deathLabel.BackgroundTransparency = 1
deathLabel.Text = "YOU DIED"
deathLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
deathLabel.Font = Enum.Font.GothamBold
deathLabel.TextSize = 28
deathLabel.Parent = deathOverlay

local respawnLabel = Instance.new("TextLabel")
respawnLabel.Name = "RespawnText"
respawnLabel.Size = UDim2.new(1, 0, 0, 20)
respawnLabel.Position = UDim2.new(0, 0, 0.55, 0)
respawnLabel.BackgroundTransparency = 1
respawnLabel.Text = "Respawning in 10..."
respawnLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
respawnLabel.Font = Enum.Font.Gotham
respawnLabel.TextSize = 14
respawnLabel.Parent = screenGui
respawnLabel.ZIndex = 51
respawnLabel.Visible = false

--============================================================================
-- GAME OVER / VICTORY OVERLAYS
--============================================================================

local gameOverOverlay = Instance.new("Frame")
gameOverOverlay.Name = "GameOverOverlay"
gameOverOverlay.Size = UDim2.new(1, 0, 0, 100)
gameOverOverlay.Position = UDim2.new(0, 0, 0.35, 0)
gameOverOverlay.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
gameOverOverlay.BackgroundTransparency = 0.2
gameOverOverlay.BorderSizePixel = 0
gameOverOverlay.Visible = false
gameOverOverlay.ZIndex = 100
gameOverOverlay.Parent = screenGui

local gameOverLabel = Instance.new("TextLabel")
gameOverLabel.Size = UDim2.new(1, 0, 0.6, 0)
gameOverLabel.BackgroundTransparency = 1
gameOverLabel.Text = "CORE DESTROYED"
gameOverLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
gameOverLabel.Font = Enum.Font.GothamBold
gameOverLabel.TextSize = 36
gameOverLabel.Parent = gameOverOverlay

local restartCountdownLabel = Instance.new("TextLabel")
restartCountdownLabel.Size = UDim2.new(1, 0, 0.4, 0)
restartCountdownLabel.Position = UDim2.new(0, 0, 0.6, 0)
restartCountdownLabel.BackgroundTransparency = 1
restartCountdownLabel.Text = "Restarting in 10..."
restartCountdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
restartCountdownLabel.Font = Enum.Font.Gotham
restartCountdownLabel.TextSize = 20
restartCountdownLabel.Parent = gameOverOverlay

local victoryOverlay = Instance.new("Frame")
victoryOverlay.Name = "VictoryOverlay"
victoryOverlay.Size = UDim2.new(1, 0, 0, 100)
victoryOverlay.Position = UDim2.new(0, 0, 0.35, 0)
victoryOverlay.BackgroundColor3 = Color3.fromRGB(20, 60, 40)
victoryOverlay.BackgroundTransparency = 0.2
victoryOverlay.BorderSizePixel = 0
victoryOverlay.Visible = false
victoryOverlay.ZIndex = 100
victoryOverlay.Parent = screenGui

local victoryLabel = Instance.new("TextLabel")
victoryLabel.Size = UDim2.new(1, 0, 1, 0)
victoryLabel.BackgroundTransparency = 1
victoryLabel.Text = "VICTORY!"
victoryLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
victoryLabel.Font = Enum.Font.GothamBold
victoryLabel.TextSize = 48
victoryLabel.Parent = victoryOverlay

--============================================================================
-- NOTIFICATION SYSTEM (for wave rewards, etc.)
--============================================================================

local notificationFrame = Instance.new("Frame")
notificationFrame.Name = "NotificationFrame"
notificationFrame.Size = UDim2.new(0, 400, 0, 100)
notificationFrame.Position = UDim2.new(0.5, -200, 0, 60)
notificationFrame.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
notificationFrame.BackgroundTransparency = 0.1
notificationFrame.BorderSizePixel = 0
notificationFrame.Visible = false
notificationFrame.ZIndex = 200
notificationFrame.Parent = screenGui

local notificationCorner = Instance.new("UICorner")
notificationCorner.CornerRadius = UDim.new(0, 10)
notificationCorner.Parent = notificationFrame

local notificationStroke = Instance.new("UIStroke")
notificationStroke.Color = Color3.fromRGB(100, 255, 100)
notificationStroke.Thickness = 2
notificationStroke.Parent = notificationFrame

local notificationTitle = Instance.new("TextLabel")
notificationTitle.Name = "Title"
notificationTitle.Size = UDim2.new(1, 0, 0, 30)
notificationTitle.Position = UDim2.new(0, 0, 0, 8)
notificationTitle.BackgroundTransparency = 1
notificationTitle.Text = "NEW WORD UNLOCKED!"
notificationTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
notificationTitle.Font = Enum.Font.GothamBold
notificationTitle.TextSize = 18
notificationTitle.ZIndex = 201
notificationTitle.Parent = notificationFrame

local notificationWord = Instance.new("TextLabel")
notificationWord.Name = "Word"
notificationWord.Size = UDim2.new(1, 0, 0, 35)
notificationWord.Position = UDim2.new(0, 0, 0, 35)
notificationWord.BackgroundTransparency = 1
notificationWord.Text = "2FIRE"
notificationWord.TextColor3 = Color3.fromRGB(100, 255, 100)
notificationWord.Font = Enum.Font.Code
notificationWord.TextSize = 28
notificationWord.ZIndex = 201
notificationWord.Parent = notificationFrame

local notificationHint = Instance.new("TextLabel")
notificationHint.Name = "Hint"
notificationHint.Size = UDim2.new(1, -20, 0, 20)
notificationHint.Position = UDim2.new(0, 10, 0, 72)
notificationHint.BackgroundTransparency = 1
notificationHint.Text = "Type HELP 2FIRE to learn more"
notificationHint.TextColor3 = Color3.fromRGB(180, 180, 180)
notificationHint.Font = Enum.Font.Gotham
notificationHint.TextSize = 12
notificationHint.ZIndex = 201
notificationHint.Parent = notificationFrame

local function showNotification(title, word, hint, duration)
	notificationTitle.Text = title or "NEW WORD UNLOCKED!"
	notificationWord.Text = word or ""
	notificationHint.Text = hint or ""
	notificationFrame.Visible = true

	-- Animate in
	notificationFrame.Position = UDim2.new(0.5, -200, 0, -100)
	local tweenIn = game:GetService("TweenService"):Create(
		notificationFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -200, 0, 60) }
	)
	tweenIn:Play()

	-- Auto-hide after duration
	task.delay(duration or 5, function()
		local tweenOut = game:GetService("TweenService"):Create(
			notificationFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -200, 0, -100) }
		)
		tweenOut:Play()
		tweenOut.Completed:Wait()
		notificationFrame.Visible = false
	end)
end

--============================================================================
-- HELP POPUP
--============================================================================

local helpPopup = Instance.new("Frame")
helpPopup.Name = "HelpPopup"
helpPopup.Size = UDim2.new(0, 550, 0, 450)
helpPopup.Position = UDim2.new(0.5, -275, 0.5, -225)
helpPopup.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
helpPopup.BorderSizePixel = 0
helpPopup.Visible = false
helpPopup.ZIndex = 300
helpPopup.Parent = screenGui

local helpCorner = Instance.new("UICorner")
helpCorner.CornerRadius = UDim.new(0, 10)
helpCorner.Parent = helpPopup

local helpStroke = Instance.new("UIStroke")
helpStroke.Color = Color3.fromRGB(100, 150, 255)
helpStroke.Thickness = 2
helpStroke.Parent = helpPopup

-- Header
local helpHeader = Instance.new("Frame")
helpHeader.Name = "Header"
helpHeader.Size = UDim2.new(1, 0, 0, 40)
helpHeader.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
helpHeader.BorderSizePixel = 0
helpHeader.Parent = helpPopup

local helpHeaderCorner = Instance.new("UICorner")
helpHeaderCorner.CornerRadius = UDim.new(0, 10)
helpHeaderCorner.Parent = helpHeader

DragModule.makeDraggable(helpPopup, helpHeader)

local helpTitle = Instance.new("TextLabel")
helpTitle.Name = "Title"
helpTitle.Size = UDim2.new(0, 150, 1, 0)
helpTitle.Position = UDim2.new(0, 15, 0, 0)
helpTitle.BackgroundTransparency = 1
helpTitle.Text = "PYTHON HELP"
helpTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
helpTitle.TextXAlignment = Enum.TextXAlignment.Left
helpTitle.Font = Enum.Font.GothamBold
helpTitle.TextSize = 16
helpTitle.ZIndex = 301
helpTitle.Parent = helpHeader

-- Search box
local searchBox = Instance.new("TextBox")
searchBox.Name = "SearchBox"
searchBox.Size = UDim2.new(0, 200, 0, 26)
searchBox.Position = UDim2.new(0, 170, 0, 7)
searchBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
searchBox.Text = ""
searchBox.PlaceholderText = "Search words..."
searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
searchBox.TextColor3 = Color3.fromRGB(220, 220, 240)
searchBox.Font = Enum.Font.Code
searchBox.TextSize = 13
searchBox.ClearTextOnFocus = false
searchBox.ZIndex = 301
searchBox.Parent = helpHeader

local searchBoxCorner = Instance.new("UICorner")
searchBoxCorner.CornerRadius = UDim.new(0, 4)
searchBoxCorner.Parent = searchBox

local searchBoxPadding = Instance.new("UIPadding")
searchBoxPadding.PaddingLeft = UDim.new(0, 8)
searchBoxPadding.Parent = searchBox

-- Back button (hidden initially)
local backBtn = Instance.new("TextButton")
backBtn.Name = "BackBtn"
backBtn.Size = UDim2.new(0, 60, 0, 26)
backBtn.Position = UDim2.new(0, 380, 0, 7)
backBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
backBtn.Text = "< BACK"
backBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
backBtn.Font = Enum.Font.GothamBold
backBtn.TextSize = 10
backBtn.Visible = false
backBtn.ZIndex = 301
backBtn.Parent = helpHeader

local backBtnCorner = Instance.new("UICorner")
backBtnCorner.CornerRadius = UDim.new(0, 4)
backBtnCorner.Parent = backBtn

local helpCloseBtn = Instance.new("TextButton")
helpCloseBtn.Name = "CloseBtn"
helpCloseBtn.Size = UDim2.new(0, 30, 0, 30)
helpCloseBtn.Position = UDim2.new(1, -35, 0, 5)
helpCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
helpCloseBtn.Text = "X"
helpCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
helpCloseBtn.Font = Enum.Font.GothamBold
helpCloseBtn.TextSize = 14
helpCloseBtn.ZIndex = 301
helpCloseBtn.Parent = helpHeader

local helpCloseBtnCorner = Instance.new("UICorner")
helpCloseBtnCorner.CornerRadius = UDim.new(0, 6)
helpCloseBtnCorner.Parent = helpCloseBtn

helpCloseBtn.MouseButton1Click:Connect(function()
	helpPopup.Visible = false
end)

-- Content area
local helpContent = Instance.new("ScrollingFrame")
helpContent.Name = "Content"
helpContent.Size = UDim2.new(1, -20, 1, -50)
helpContent.Position = UDim2.new(0, 10, 0, 45)
helpContent.BackgroundTransparency = 1
helpContent.ScrollBarThickness = 6
helpContent.CanvasSize = UDim2.new(0, 0, 0, 0)
helpContent.ZIndex = 301
helpContent.Parent = helpPopup

local helpLayout = Instance.new("UIListLayout")
helpLayout.Padding = UDim.new(0, 4)
helpLayout.SortOrder = Enum.SortOrder.LayoutOrder
helpLayout.Parent = helpContent

-- Forward declare for mutual reference
local showWordHelp
local showFilteredWords

-- Function to show help for a specific word
showWordHelp = function(word)
	-- Clear content
	for _, child in ipairs(helpContent:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local info = HelpDatabase.getWordHelp(word)
	if not info then
		local notFound = Instance.new("TextLabel")
		notFound.Size = UDim2.new(1, 0, 0, 40)
		notFound.BackgroundTransparency = 1
		notFound.Text = "Word '" .. word .. "' not found"
		notFound.TextColor3 = Color3.fromRGB(255, 150, 150)
		notFound.Font = Enum.Font.Gotham
		notFound.TextSize = 14
		notFound.ZIndex = 302
		notFound.Parent = helpContent
		helpContent.CanvasSize = UDim2.new(0, 0, 0, 50)
		return
	end

	helpTitle.Text = "HELP: " .. word
	backBtn.Visible = true
	searchBox.Visible = false

	-- Word name
	local wordLabel = Instance.new("TextLabel")
	wordLabel.Size = UDim2.new(1, 0, 0, 35)
	wordLabel.BackgroundTransparency = 1
	wordLabel.Text = word
	wordLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	wordLabel.Font = Enum.Font.Code
	wordLabel.TextSize = 24
	wordLabel.TextXAlignment = Enum.TextXAlignment.Left
	wordLabel.ZIndex = 302
	wordLabel.Parent = helpContent

	-- Stack effect
	local stackLabel = Instance.new("TextLabel")
	stackLabel.Size = UDim2.new(1, 0, 0, 25)
	stackLabel.BackgroundTransparency = 1
	stackLabel.Text = info.stack
	stackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	stackLabel.Font = Enum.Font.Code
	stackLabel.TextSize = 14
	stackLabel.TextXAlignment = Enum.TextXAlignment.Left
	stackLabel.ZIndex = 302
	stackLabel.Parent = helpContent

	-- Category
	local catLabel = Instance.new("TextLabel")
	catLabel.Size = UDim2.new(1, 0, 0, 20)
	catLabel.BackgroundTransparency = 1
	catLabel.Text = "Category: " .. (info.category or "General")
	catLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
	catLabel.Font = Enum.Font.Gotham
	catLabel.TextSize = 11
	catLabel.TextXAlignment = Enum.TextXAlignment.Left
	catLabel.ZIndex = 302
	catLabel.Parent = helpContent

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, 0, 0, 50)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = info.desc
	descLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 14
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.ZIndex = 302
	descLabel.Parent = helpContent

	-- Example header
	local exHeader = Instance.new("TextLabel")
	exHeader.Size = UDim2.new(1, 0, 0, 25)
	exHeader.BackgroundTransparency = 1
	exHeader.Text = "Example:"
	exHeader.TextColor3 = Color3.fromRGB(150, 200, 255)
	exHeader.Font = Enum.Font.GothamBold
	exHeader.TextSize = 12
	exHeader.TextXAlignment = Enum.TextXAlignment.Left
	exHeader.ZIndex = 302
	exHeader.Parent = helpContent

	-- Example code
	local exCode = Instance.new("TextLabel")
	exCode.Size = UDim2.new(1, 0, 0, 60)
	exCode.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	exCode.Text = "  " .. info.example
	exCode.TextColor3 = Color3.fromRGB(200, 200, 220)
	exCode.Font = Enum.Font.Code
	exCode.TextSize = 13
	exCode.TextXAlignment = Enum.TextXAlignment.Left
	exCode.TextYAlignment = Enum.TextYAlignment.Top
	exCode.TextWrapped = true
	exCode.ZIndex = 302
	exCode.Parent = helpContent

	local exCodeCorner = Instance.new("UICorner")
	exCodeCorner.CornerRadius = UDim.new(0, 4)
	exCodeCorner.Parent = exCode

	helpContent.CanvasSize = UDim2.new(0, 0, 0, 250)
end

-- Helper to create a word row
local function createWordRow(wordInfo, parent, layoutOrder)
	local wordBtn = Instance.new("TextButton")
	wordBtn.Size = UDim2.new(1, 0, 0, 28)
	wordBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	wordBtn.Text = ""
	wordBtn.ZIndex = 302
	wordBtn.LayoutOrder = layoutOrder
	wordBtn.Parent = parent

	local wordBtnCorner = Instance.new("UICorner")
	wordBtnCorner.CornerRadius = UDim.new(0, 4)
	wordBtnCorner.Parent = wordBtn

	local wordName = Instance.new("TextLabel")
	wordName.Size = UDim2.new(0, 90, 1, 0)
	wordName.Position = UDim2.new(0, 8, 0, 0)
	wordName.BackgroundTransparency = 1
	wordName.Text = wordInfo.word
	wordName.TextColor3 = Color3.fromRGB(100, 255, 100)
	wordName.Font = Enum.Font.Code
	wordName.TextSize = 12
	wordName.TextXAlignment = Enum.TextXAlignment.Left
	wordName.ZIndex = 303
	wordName.Parent = wordBtn

	local wordStack = Instance.new("TextLabel")
	wordStack.Size = UDim2.new(0, 130, 1, 0)
	wordStack.Position = UDim2.new(0, 100, 0, 0)
	wordStack.BackgroundTransparency = 1
	wordStack.Text = wordInfo.info.stack
	wordStack.TextColor3 = Color3.fromRGB(255, 200, 100)
	wordStack.Font = Enum.Font.Code
	wordStack.TextSize = 10
	wordStack.TextXAlignment = Enum.TextXAlignment.Left
	wordStack.ZIndex = 303
	wordStack.Parent = wordBtn

	local wordDesc = Instance.new("TextLabel")
	wordDesc.Size = UDim2.new(1, -240, 1, 0)
	wordDesc.Position = UDim2.new(0, 235, 0, 0)
	wordDesc.BackgroundTransparency = 1
	wordDesc.Text = wordInfo.info.desc
	wordDesc.TextColor3 = Color3.fromRGB(160, 160, 180)
	wordDesc.Font = Enum.Font.Gotham
	wordDesc.TextSize = 10
	wordDesc.TextXAlignment = Enum.TextXAlignment.Left
	wordDesc.TextTruncate = Enum.TextTruncate.AtEnd
	wordDesc.ZIndex = 303
	wordDesc.Parent = wordBtn

	wordBtn.MouseButton1Click:Connect(function()
		showWordHelp(wordInfo.word)
	end)

	return wordBtn
end

-- Function to show filtered words (for search)
showFilteredWords = function(filter)
	-- Clear content
	for _, child in ipairs(helpContent:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	helpTitle.Text = "PYTHON HELP"
	backBtn.Visible = false
	searchBox.Visible = true

	local filterUpper = filter and string.upper(filter) or ""
	local totalHeight = 0
	local hasResults = false
	local layoutOrder = 0

	for _, category in ipairs(HelpDatabase.categories) do
		local words = HelpDatabase.getWordsInCategory(category)
		local matchingWords = {}

		-- Filter words if search is active
		for _, wordInfo in ipairs(words) do
			if filterUpper == "" or string.find(string.upper(wordInfo.word), filterUpper, 1, true)
				or string.find(string.upper(wordInfo.info.desc), filterUpper, 1, true) then
				table.insert(matchingWords, wordInfo)
			end
		end

		if #matchingWords > 0 then
			hasResults = true

			-- Category header
			local catHeader = Instance.new("TextLabel")
			catHeader.Size = UDim2.new(1, 0, 0, 22)
			catHeader.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
			catHeader.Text = "  " .. category .. " (" .. #matchingWords .. ")"
			catHeader.TextColor3 = Color3.fromRGB(100, 200, 255)
			catHeader.Font = Enum.Font.GothamBold
			catHeader.TextSize = 11
			catHeader.TextXAlignment = Enum.TextXAlignment.Left
			catHeader.ZIndex = 302
			catHeader.LayoutOrder = layoutOrder
			catHeader.Parent = helpContent
			totalHeight = totalHeight + 26
			layoutOrder = layoutOrder + 1

			local catCorner = Instance.new("UICorner")
			catCorner.CornerRadius = UDim.new(0, 4)
			catCorner.Parent = catHeader

			-- Words in this category (always expanded)
			for _, wordInfo in ipairs(matchingWords) do
				createWordRow(wordInfo, helpContent, layoutOrder)
				totalHeight = totalHeight + 32
				layoutOrder = layoutOrder + 1
			end
		end
	end

	if not hasResults then
		local noResults = Instance.new("TextLabel")
		noResults.Size = UDim2.new(1, 0, 0, 40)
		noResults.BackgroundTransparency = 1
		noResults.Text = "No words found matching '" .. filter .. "'"
		noResults.TextColor3 = Color3.fromRGB(180, 150, 150)
		noResults.Font = Enum.Font.Gotham
		noResults.TextSize = 13
		noResults.ZIndex = 302
		noResults.LayoutOrder = 0
		noResults.Parent = helpContent
		totalHeight = 50
	end

	helpContent.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
end

-- Search box handler
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	showFilteredWords(searchBox.Text)
end)

-- Back button handler
backBtn.MouseButton1Click:Connect(function()
	searchBox.Text = ""
	showFilteredWords("")
end)

-- Show help function (called from ? button)
showHelp = function(targetWord)
	helpPopup.Visible = true
	searchBox.Text = ""
	if targetWord then
		showWordHelp(targetWord)
	else
		showFilteredWords("")
	end
end

--============================================================================
-- HP BILLBOARD
--============================================================================

local hpBillboard = nil

local function setupHpBillboard()
	if hpBillboard then hpBillboard:destroy() end
	if player.Character then
		hpBillboard = PlayerHpBillboard.create(player.Character)
	end
end

player.CharacterAdded:Connect(setupHpBillboard)
if player.Character then setupHpBillboard() end

--============================================================================
-- EVENT HANDLERS
--============================================================================

-- Main state update (unified for both player and golem interpreters)
stateUpdateEvent.OnClientEvent:Connect(function(state)
	-- Update interpreter display (works for both player and golem)
	program:update(state)
	bytecodePanel:update(state)  -- Update bytecode visualization
	editor:setPaused(state.paused)

	-- [FIX] Ensure we are actually targeting THIS golem/bot/player before overwriting the editor
	local isTargetingGolem = (currentInterpreterTarget.type == "golem")
	local isTargetingBot = (currentInterpreterTarget.type == "bot")
	local isTargetingPlayer = (currentInterpreterTarget.type == "player")
	local matchesGolemId = (state.golemId == currentInterpreterTarget.golemId)
	local matchesBotId = (state.botId == currentInterpreterTarget.botId)

	-- Load golem program
	if state.isGolem and isTargetingGolem and matchesGolemId and not golemProgramLoaded and state.source then
		editor:setTextFormatted(state.source)
		golemProgramLoaded = true
	end

	-- Load bot program
	if state.isBot and isTargetingBot and matchesBotId and not golemProgramLoaded and state.source then
		editor:setTextFormatted(state.source)
		golemProgramLoaded = true
	end

	-- Load player program (when targeting player and not golem/bot)
	if isTargetingPlayer and not state.isGolem and not state.isBot and not playerProgramLoaded and state.source then
		editor:setTextFormatted(state.source)
		playerProgramLoaded = true
	end

	if hpBillboard then
		hpBillboard:update(state.hp or 100, state.maxHp or 100)
	end

	-- Update TD HUD (only when wave data is present to avoid flickering)
	if state.waveNumber then
		waveLabel.Text = "WAVE " .. state.waveNumber

		local phase = state.phase or "LOBBY"
		currentPhase = phase
		phaseLabel.Text = phase

		if phase == "BUILD" then
			phaseLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
		elseif phase == "COMBAT" then
			phaseLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
		else
			phaseLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
		end

		-- Show/hide buttons based on phase (building disabled - pre-placed units)
		if phase == "LOBBY" then
			readyButton.Visible = true
			skipButton.Visible = false
			-- Reset ready button if we returned to lobby
			readyButton.Text = "READY"
			readyButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
		elseif phase == "BUILD" then
			readyButton.Visible = false
			skipButton.Visible = true
		else
			readyButton.Visible = false
			skipButton.Visible = false
		end
		-- Build buttons stay hidden (pre-placed units, no building phase)

		local coreHp = state.coreHp or 0
		local coreMax = state.coreMaxHp or 1000
		coreLabel.Text = "CORE: " .. math.floor(coreHp) .. "/" .. math.floor(coreMax)
		local corePercent = coreHp / coreMax
		if corePercent > 0.5 then
			coreLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		elseif corePercent > 0.25 then
			coreLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		else
			coreLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		end

		enemiesLabel.Text = "ENEMIES: " .. (state.enemiesRemaining or 0)
		scrapLabel.Text = "SCRAP: " .. (state.scrap or 0)
		currentScrap = state.scrap or 0 -- Track for build button

		-- Update bag display (physical scrap inventory)
		local bagAmount = state.scrapInventory or 0
		local bagMax = state.maxCapacity or 50
		bagLabel.Text = "BAG: " .. bagAmount .. "/" .. bagMax
		-- Color feedback: cyan normally, gold when full
		if bagAmount >= bagMax then
			bagLabel.TextColor3 = Color3.fromRGB(255, 200, 50) -- Gold when full
		elseif bagAmount > 0 then
			bagLabel.TextColor3 = Color3.fromRGB(0, 200, 255) -- Cyan with stuff
		else
			bagLabel.TextColor3 = Color3.fromRGB(100, 120, 140) -- Gray when empty
		end

		if state.buildTimeRemaining and state.buildTimeRemaining > 0 then
			timerLabel.Text = "BUILD TIME: " .. math.ceil(state.buildTimeRemaining) .. "s"
			timerLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
		else
			timerLabel.Text = ""
		end

		-- Game over states
		if phase == "GAMEOVER" then
			gameOverOverlay.Visible = true
			victoryOverlay.Visible = false
			-- Update restart countdown
			local restartTime = state.restartTimeRemaining or 0
			restartCountdownLabel.Text = "Restarting in " .. math.ceil(restartTime) .. "..."
		elseif phase == "VICTORY" then
			gameOverOverlay.Visible = false
			victoryOverlay.Visible = true
		else
			gameOverOverlay.Visible = false
			victoryOverlay.Visible = false
		end
	end

	-- Death handling
	if state.dead then
		deathOverlay.Visible = true
		respawnLabel.Visible = true

		if state.deathTimeRemaining then
			respawnLabel.Text = "Respawning in " .. math.ceil(state.deathTimeRemaining) .. "..."
		else
			respawnLabel.Text = "Respawning..."
		end

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		end
	else
		deathOverlay.Visible = false
		respawnLabel.Visible = false

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid.WalkSpeed == 0 then
				humanoid.WalkSpeed = Config.MANUAL_WALKING_SPEED
				humanoid.JumpPower = 50
			end
		end
	end
end)

-- Golem state updates
local previousTurretCount = 0 -- Track previous count to detect reaching cap
local golemStatesRaw = {} -- Store list for the panel
golemStateEvent.OnClientEvent:Connect(function(data)
	-- Convert golem list to lookup by ID
	golemStates = {}
	currentTurretCount = 0
	golemStatesRaw = {} -- Store list for the panel
	if data and data.golems then
		golemStatesRaw = data.golems
		for _, golem in ipairs(data.golems) do
			golemStates[golem.id] = golem
			currentTurretCount = currentTurretCount + 1
		end
	end

	-- Update the UnitListPanel (pass both golems and bots)
	unitList:update(golemStatesRaw, botStatesRaw)

	-- Update turret count in HUD
	turretsLabel.Text = "TURRETS: " .. currentTurretCount .. "/" .. MAX_TURRETS
	-- Color changes based on count
	if currentTurretCount >= MAX_TURRETS then
		turretsLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red when at cap
		-- Show warning when just reached cap
		if previousTurretCount < MAX_TURRETS then
			showNotification(
				"TURRET LIMIT REACHED",
				"Max " .. MAX_TURRETS .. " turrets!",
				"Sell a turret to build more (click turret + DELETE)",
				4
			)
		end
	elseif currentTurretCount >= MAX_TURRETS - 3 then
		turretsLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Yellow when close
	else
		turretsLabel.TextColor3 = Color3.fromRGB(100, 200, 255) -- Cyan normally
	end
	previousTurretCount = currentTurretCount

	-- Update range ring if in golem mind mode
	if currentInterpreterTarget.type == "golem" and golemMindRangeRing then
		local golemId = currentInterpreterTarget.golemId
		local golemData = golemStates[golemId]
		if golemData then
			local currentRange = golemData.dynamicRange or 40
			golemMindRangeRing.Size = Vector3.new(0.5, currentRange * 2, currentRange * 2)

			-- Update color based on range/power
			local powerMultiplier = 40 / currentRange
			if powerMultiplier >= 2 then
				golemMindRangeRing.Color = Color3.fromRGB(255, 100, 100) -- Red = High damage, short range
			elseif powerMultiplier >= 1 then
				golemMindRangeRing.Color = Color3.fromRGB(255, 200, 100) -- Orange = Normal
			else
				golemMindRangeRing.Color = Color3.fromRGB(100, 200, 255) -- Blue = Long range
			end
		end
	end
end)

-- Bot state updates
botStateEvent.OnClientEvent:Connect(function(data)
	botStates = {}
	botStatesRaw = {}
	currentBotCount = 0
	if data and data.bots then
		for _, bot in ipairs(data.bots) do
			botStates[bot.id] = bot
			table.insert(botStatesRaw, bot)
			currentBotCount = currentBotCount + 1
		end
	end
	-- Update the UnitListPanel with both datasets
	unitList:update(golemStatesRaw, botStatesRaw)
end)

-- Golem placement result feedback
golemPlaceAtEvent.OnClientEvent:Connect(function(success, result)
	if success then
		print("Golem placed successfully! ID:", result)
	else
		print("Cannot place golem:", result)
	end
end)

-- Bot placement result feedback
botBuildEvent.OnClientEvent:Connect(function(success, result)
	if success then
		print("Bot built successfully! ID:", result)
	else
		print("Cannot build bot:", result)
		showNotification("BUILD FAILED", tostring(result), "", 3)
	end
end)

-- Golem sell result feedback (handler connected later after exitGolemMind is defined)

attackHitEvent.OnClientEvent:Connect(function(data)
	Effects.attackHit(data)
end)

playerHurtEvent.OnClientEvent:Connect(function(data)
	Effects.playerHurt(data, workspace.CurrentCamera, screenGui)
	if hpBillboard and data.newHp and data.maxHp then
		hpBillboard:update(data.newHp, data.maxHp)
	end
end)

beepEvent.OnClientEvent:Connect(function()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9114074529"
	sound.Volume = 0.5
	sound.Parent = workspace
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end)

playAnimationEvent.OnClientEvent:Connect(function(animName, character)
	if animName == "AxeSwing" then
		Effects.playAxeSwing(character)
	end
end)

-- Player move with woosh effect
playerTeleportEvent.OnClientEvent:Connect(function(x, z)
	local char = player.Character
	if not char then
		playerMoveCompleteEvent:FireServer()
		return
	end
	local humanoid = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		playerMoveCompleteEvent:FireServer()
		return
	end

	local startPos = hrp.Position
	local endPos = Vector3.new(x, startPos.Y, z)

	-- Woosh trail as we move
	spawn(function()
		while humanoid.MoveDirection.Magnitude > 0 or (hrp.Position - endPos).Magnitude > 2 do
			local part = Instance.new("Part")
			part.Size = Vector3.new(0.3, 1.5, 0.3)
			part.Position = hrp.Position - Vector3.new(0, 1, 0)
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(100, 180, 255)
			part.Transparency = 0.5
			part.Parent = workspace

			spawn(function()
				for j = 1, 5 do
					part.Transparency = 0.5 + (j * 0.1)
					part.Size = part.Size * 0.8
					wait(0.03)
				end
				part:Destroy()
			end)

			wait(0.05)
			-- Stop if we reached destination or stopped moving
			if (hrp.Position - endPos).Magnitude < 2 then break end
		end
	end)

	-- Walk to destination, signal server when done
	humanoid:MoveTo(endPos)
	humanoid.MoveToFinished:Once(function()
		playerMoveCompleteEvent:FireServer()
	end)
end)

--============================================================================
-- GOLEM MIND MODE HELPERS
--============================================================================

local function enterGolemMind(golemId)
	local golemData = golemStates[golemId]
	if not golemData then
		print("Golem not found:", golemId)
		return false
	end

	-- Exit bot mind first if we're in it
	if currentInterpreterTarget.type == "bot" then
		-- Don't restore player program, just unregister from bot
		botUnregisterViewerEvent:FireServer(currentInterpreterTarget.botId)
	-- Exit other golem mind first if switching golems
	elseif currentInterpreterTarget.type == "golem" and currentInterpreterTarget.golemId ~= golemId then
		-- Don't restore player program, just unregister from old golem
		golemUnregisterViewerEvent:FireServer(currentInterpreterTarget.golemId)
	end

	-- Only save player program if coming FROM player mode
	if currentInterpreterTarget.type == "player" then
		savedPlayerProgram = editor:getText()
	end
	golemProgramLoaded = false

	currentInterpreterTarget = {
		type = "golem",
		golemId = golemId,
		spotId = golemData.spotId
	}

	print("Entered golem mind mode: Golem #" .. (golemData.spotId or "?") .. " (READ-ONLY)")

	-- Register as viewer
	golemRegisterViewerEvent:FireServer(golemId)

	-- Update UI (turret = read-only mode)
	editor:setMode("golem", golemData.spotId)
	program:setTheme("golem")
	bytecodePanel:setTheme("golem")
	updateIDEVisibility() -- Show IDE when in golem mind

	-- Create range indicator ring
	-- Find the golem character in workspace
	local golemCharacter = nil
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("GolemId") == golemId then
			golemCharacter = model
			break
		end
	end

	if golemCharacter then
		local hrp = golemCharacter:FindFirstChild("HumanoidRootPart") or golemCharacter.PrimaryPart
		if hrp then
			-- Destroy old ring if exists
			if golemMindRangeRing then
				golemMindRangeRing:Destroy()
			end

			local currentRange = golemData.dynamicRange or 40
			local ring = Instance.new("Part")
			ring.Name = "GolemMindRangeRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.5, currentRange * 2, currentRange * 2)
			ring.CFrame = CFrame.new(hrp.Position.X, 0.3, hrp.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
			ring.Anchored = true
			ring.CanCollide = false
			ring.Material = Enum.Material.Neon
			ring.Color = Color3.fromRGB(100, 200, 255)
			ring.Transparency = 0.7
			ring.Parent = workspace

			golemMindRangeRing = ring
		end
	end

	return true
end

-- Link the wrapper for the UI callback
enterGolemMindWrapper = enterGolemMind

local function exitGolemMind()
	if currentInterpreterTarget.type == "player" then return end

	local golemId = currentInterpreterTarget.golemId

	currentInterpreterTarget = {
		type = "player",
		golemId = nil,
		spotId = nil,
	}

	print("Exited golem mind mode")

	-- Unregister as viewer
	golemUnregisterViewerEvent:FireServer(golemId)

	editor:setGolemMode(false, nil)
	program:setTheme("player")
	bytecodePanel:setTheme("player")
	updateIDEVisibility() -- Hide IDE when back to player

	-- Destroy range indicator ring
	if golemMindRangeRing then
		golemMindRangeRing:Destroy()
		golemMindRangeRing = nil
	end

	-- Restore player program
	if savedPlayerProgram then
		editor:setText(savedPlayerProgram)
		savedPlayerProgram = nil
	end
	golemProgramLoaded = false
end

-- Wire up exit golem button
editor.onExitGolem = function()
	exitGolemMind()
end

-- Wire up sell golem button
editor.onSellGolem = function()
	if currentInterpreterTarget.type == "golem" and currentInterpreterTarget.golemId then
		golemSellEvent:FireServer(currentInterpreterTarget.golemId)
	end
end

-- Wire up move button (enters placement mode for relocation)
local isMovingGolem = false
local movingGolemId = nil

editor.onMoveGolem = function()
	if currentInterpreterTarget.type == "golem" and currentInterpreterTarget.golemId then
		isMovingGolem = true
		movingGolemId = currentInterpreterTarget.golemId
		print("Click on the map to move the turret...")
		-- Could add visual indicator here
	end
end

-- Handle move result
golemMoveEvent.OnClientEvent:Connect(function(success, msg)
	isMovingGolem = false
	movingGolemId = nil
	if success then
		print("Turret moved successfully!")
	else
		print("Cannot move turret:", msg)
	end
end)

-- Handle mouse clicks for moving turrets
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isMovingGolem and movingGolemId then
		-- Raycast to find where player clicked on the ground
		local mouse = player:GetMouse()
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {player.Character}

		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
		if result then
			local hitPos = result.Position
			golemMoveEvent:FireServer(movingGolemId, hitPos.X, hitPos.Z)
		end
	end
end)

-- Golem sell result feedback (defined here after exitGolemMind exists)
golemSellEvent.OnClientEvent:Connect(function(success, result)
	if success then
		print("Golem sold for", result, "scrap!")
		-- Exit golem mind after selling
		if currentInterpreterTarget.type == "golem" then
			exitGolemMind()
		end
	else
		print("Cannot sell golem:", result)
	end
end)

--============================================================================
-- BOT MIND MODE HELPERS
--============================================================================

local function enterBotMind(botId)
	local botData = botStates[botId]
	if not botData then
		print("Bot not found:", botId)
		return false
	end

	-- Exit golem mind first if we're in it
	if currentInterpreterTarget.type == "golem" then
		exitGolemMind()
	-- Exit other bot mind first if switching bots
	elseif currentInterpreterTarget.type == "bot" and currentInterpreterTarget.botId ~= botId then
		-- Don't restore player program, just unregister from old bot
		botUnregisterViewerEvent:FireServer(currentInterpreterTarget.botId)
	end

	-- Only save player program if coming FROM player mode
	if currentInterpreterTarget.type == "player" then
		savedPlayerProgram = editor:getText()
	end
	golemProgramLoaded = false -- Reuse this flag for bot program loading

	currentInterpreterTarget = {
		type = "bot",
		golemId = nil,
		botId = botId,
		spotId = botData.spotId,
	}

	print("Entered bot mind mode: Bot #" .. (botData.spotId or "?"))

	-- Register as viewer
	botRegisterViewerEvent:FireServer(botId)

	-- Update UI - use bot mode
	editor:setMode("bot", botData.spotId)
	program:setTheme("bot")
	bytecodePanel:setTheme("bot")
	updateIDEVisibility() -- Show IDE when in bot mind

	return true
end

-- Link the wrapper for the UI callback
enterBotMindWrapper = enterBotMind

local function exitBotMind()
	if currentInterpreterTarget.type ~= "bot" then return end

	local botId = currentInterpreterTarget.botId

	currentInterpreterTarget = {
		type = "player",
		golemId = nil,
		botId = nil,
		spotId = nil,
	}

	print("Exited bot mind mode")

	-- Unregister as viewer
	botUnregisterViewerEvent:FireServer(botId)

	-- Update UI back to player mode
	editor:setMode("player", nil)
	program:setTheme("player")
	bytecodePanel:setTheme("player")
	updateIDEVisibility() -- Hide IDE when back to player

	-- Restore player program
	if savedPlayerProgram then
		editor:setText(savedPlayerProgram)
		savedPlayerProgram = nil
	end
	golemProgramLoaded = false
end

-- Wire up exit bot button (reuses onExitGolem for simplicity)
local originalExitGolem = editor.onExitGolem
editor.onExitGolem = function()
	if currentInterpreterTarget.type == "bot" then
		exitBotMind()
	elseif currentInterpreterTarget.type == "golem" then
		if originalExitGolem then originalExitGolem() else exitGolemMind() end
	end
end

-- Wire up sell bot button (reuses onSellGolem)
local originalSellGolem = editor.onSellGolem
editor.onSellGolem = function()
	if currentInterpreterTarget.type == "bot" and currentInterpreterTarget.botId then
		botSellEvent:FireServer(currentInterpreterTarget.botId)
	elseif currentInterpreterTarget.type == "golem" and currentInterpreterTarget.golemId then
		golemSellEvent:FireServer(currentInterpreterTarget.golemId)
	end
end

-- Bot sell result feedback
botSellEvent.OnClientEvent:Connect(function(success, result)
	if success then
		print("Bot sold for", result, "scrap!")
		-- Exit bot mind after selling
		if currentInterpreterTarget.type == "bot" then
			exitBotMind()
		end
	else
		print("Cannot sell bot:", result)
	end
end)

--============================================================================
-- PLACEMENT MODE (Ghost turret preview with Range Ring)
--============================================================================

-- Track placement validity for click handler
local isPlacementValid = false

local function createGhostTurret()
	local model = Instance.new("Model")
	model.Name = "GhostTurret"

	-- 1. Range Indicator (Cylinder) - Shows what the turret can shoot
	local range = 40 -- Match GolemStats.range
	local ring = Instance.new("Part")
	ring.Name = "RangeRing"
	ring.Shape = Enum.PartType.Cylinder
	-- Cylinders are rotated 90 deg on Z by default. Size is (Height, Dia, Dia)
	ring.Size = Vector3.new(0.2, range * 2, range * 2)
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.ForceField
	ring.Color = Color3.fromRGB(0, 255, 255)
	ring.Transparency = 0.8
	ring.Parent = model

	-- 2. The Turret Hologram (Neon material for hologram look)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(3, 4, 4)
	base.Orientation = Vector3.new(0, 0, 90)
	base.Anchored = true
	base.CanCollide = false
	base.Material = Enum.Material.Neon -- Neon looks more like a hologram
	base.Color = Color3.fromRGB(100, 255, 100)
	base.Transparency = 0.6
	base.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.5, 2.5, 3)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.Neon
	head.Color = Color3.fromRGB(100, 255, 100)
	head.Transparency = 0.6
	head.Parent = model

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(3, 0.8, 0.8)
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.Material = Enum.Material.Neon
	barrel.Color = Color3.fromRGB(100, 255, 100)
	barrel.Transparency = 0.6
	barrel.Parent = model

	model.PrimaryPart = base
	return model
end

local function updateGhostPosition(x, z)
	if not ghostTurret then return false end

	-- Smart Validation: Check Map Boundaries
	-- Using map size from arena (approximately 300x300 with 15 stud margins)
	local inBounds = (x > 15 and x < 285 and z > 15 and z < 285)

	-- Check Distance to other golems (can't stack turrets)
	local tooClose = false
	for _, otherModel in ipairs(workspace:GetChildren()) do
		if otherModel:GetAttribute("GolemId") and otherModel.PrimaryPart then
			local dist = (Vector3.new(x, 0, z) - Vector3.new(otherModel.PrimaryPart.Position.X, 0, otherModel.PrimaryPart.Position.Z))
				.Magnitude
			if dist < 8 then
				tooClose = true
				break
			end
		end
	end

	-- Check Core area (can't build right on top of core)
	local distToCore = (Vector3.new(x, 0, z) - Vector3.new(150, 0, 150)).Magnitude
	local tooCloseToCore = distToCore < 20

	-- Check if player has enough scrap
	local hasScrap = currentScrap >= 100

	-- Final Validity - paths are fine, but not on core or stacked
	local isValid = inBounds and not tooClose and not tooCloseToCore and hasScrap

	-- Color Logic: Green if valid, Red if invalid
	local color = isValid and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)

	-- Update Parts
	local base = ghostTurret:FindFirstChild("Base")
	local head = ghostTurret:FindFirstChild("Head")
	local barrel = ghostTurret:FindFirstChild("Barrel")
	local ring = ghostTurret:FindFirstChild("RangeRing")

	if base then
		base.Position = Vector3.new(x, 1.5, z)
		base.Color = color
	end
	if head then
		head.Position = Vector3.new(x, 3.5, z)
		head.Color = color
	end
	if barrel then
		barrel.CFrame = CFrame.new(x, 3.5, z - 3.5) * CFrame.Angles(0, math.rad(90), 0)
		barrel.Color = color
	end
	if ring then
		ring.Position = Vector3.new(x, 0.5, z)
		ring.Color = color
	end

	return isValid
end

-- Define placement mode functions (referenced by forward declarations above)
enterPlacementMode = function()
	if placementMode then return end

	-- Check if at turret cap
	if currentTurretCount >= MAX_TURRETS then
		showNotification(
			"TURRET LIMIT REACHED",
			"Max " .. MAX_TURRETS .. " turrets!",
			"Sell a turret to build more (click turret + DELETE)",
			4
		)
		return
	end

	-- Check if player can afford before entering
	if currentScrap < 100 then
		print("Not enough scrap to build! Need 100, have " .. currentScrap)
		return
	end

	placementMode = true

	-- Create ghost turret with range ring
	ghostTurret = createGhostTurret()
	ghostTurret.Parent = workspace

	print("Entered placement mode - click to place, B or right-click to cancel")
end

exitPlacementMode = function()
	if not placementMode then return end
	placementMode = false

	-- Destroy ghost turret
	if ghostTurret then
		ghostTurret:Destroy()
		ghostTurret = nil
	end

	isPlacementValid = false
	print("Exited placement mode")
end

--============================================================================
-- BOT PLACEMENT MODE
--============================================================================

local BOT_COST = 75
local isBotPlacementValid = false

local function createGhostBot()
	local model = Instance.new("Model")
	model.Name = "GhostBot"

	-- Simple bot body (sphere on cylinder base)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3, 3, 3)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.Neon
	body.Color = Color3.fromRGB(0, 200, 200)
	body.Transparency = 0.5
	body.Parent = model

	-- Range indicator (pickup range = 8)
	local ring = Instance.new("Part")
	ring.Name = "RangeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 16, 16) -- 8 stud radius
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.ForceField
	ring.Color = Color3.fromRGB(0, 200, 200)
	ring.Transparency = 0.85
	ring.Parent = model

	model.PrimaryPart = body
	return model
end

local function updateGhostBotPosition(x, z)
	if not ghostBot then return false end

	-- Validation
	local inBounds = (x > 15 and x < 285 and z > 15 and z < 285)

	-- Check distance to core (can't build right on core)
	local distToCore = (Vector3.new(x, 0, z) - Vector3.new(150, 0, 150)).Magnitude
	local tooCloseToCore = distToCore < 20

	-- Check if player has enough scrap
	local hasScrap = currentScrap >= BOT_COST

	local isValid = inBounds and not tooCloseToCore and hasScrap

	-- Color
	local color = isValid and Color3.fromRGB(0, 255, 200) or Color3.fromRGB(255, 50, 50)

	local body = ghostBot:FindFirstChild("Body")
	local ring = ghostBot:FindFirstChild("RangeRing")

	if body then
		body.Position = Vector3.new(x, 2, z)
		body.Color = color
	end
	if ring then
		ring.Position = Vector3.new(x, 0.3, z)
		ring.Color = color
	end

	return isValid
end

enterBotPlacementMode = function()
	if botPlacementMode then return end

	-- Check bot cap
	if currentBotCount >= MAX_BOTS then
		showNotification("BOT LIMIT REACHED", "Max " .. MAX_BOTS .. " bots!", "Sell a bot to build more", 4)
		return
	end

	-- Check scrap
	if currentScrap < BOT_COST then
		print("Not enough scrap for bot! Need " .. BOT_COST .. ", have " .. currentScrap)
		return
	end

	botPlacementMode = true
	ghostBot = createGhostBot()
	ghostBot.Parent = workspace

	print("Entered bot placement mode - click to place, N or right-click to cancel")
end

exitBotPlacementMode = function()
	if not botPlacementMode then return end
	botPlacementMode = false

	if ghostBot then
		ghostBot:Destroy()
		ghostBot = nil
	end

	isBotPlacementValid = false
	print("Exited bot placement mode")
end

-- Enter build mode event from server (BUILD word)
enterBuildModeEvent.OnClientEvent:Connect(function()
	enterPlacementMode()
end)

--============================================================================
-- INPUT HANDLING
--============================================================================

local mouse = player:GetMouse()

-- Update ghost turret/bot position every frame
game:GetService("RunService").RenderStepped:Connect(function()
	local mouseTarget = mouse.Hit
	if not mouseTarget then return end

	local x = math.floor(mouseTarget.Position.X + 0.5)
	local z = math.floor(mouseTarget.Position.Z + 0.5)

	-- Update turret ghost
	if placementMode and ghostTurret then
		isPlacementValid = updateGhostPosition(x, z)
	end

	-- Update bot ghost
	if botPlacementMode and ghostBot then
		isBotPlacementValid = updateGhostBotPosition(x, z)
	end
end)

-- Right-click to cancel placement mode (standard RTS behavior)
mouse.Button2Down:Connect(function()
	if placementMode then
		exitPlacementMode()
	end
	if botPlacementMode then
		exitBotPlacementMode()
	end
end)

-- Left-click: Enter golem mind, place golem, place bot, or attack
mouse.Button1Down:Connect(function()
	-- If in turret placement mode, place the golem
	if placementMode then
		if isPlacementValid then
			local hitPos = mouse.Hit.Position
			local x = math.floor(hitPos.X + 0.5)
			local z = math.floor(hitPos.Z + 0.5)

			-- Try to place golem at this position
			golemPlaceAtEvent:FireServer(x, z)

			-- SOUND: Play a satisfying "Plunk" sound
			local sfx = Instance.new("Sound", workspace)
			sfx.SoundId = "rbxassetid://9125699809" -- Mechanical click
			sfx.Volume = 0.7
			sfx.PlayOnRemove = true
			sfx:Destroy()

			-- SHIFT: Don't exit mode if holding SHIFT (Mass placement)
			if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				exitPlacementMode()
			end
		else
			-- SOUND: Error buzzer for invalid placement
			local sfx = Instance.new("Sound", workspace)
			sfx.SoundId = "rbxassetid://71764947817417" -- Error buzz
			sfx.Volume = 0.5
			sfx.PlayOnRemove = true
			sfx:Destroy()
		end
		return -- Consume click
	end

	-- If in bot placement mode, place the bot
	if botPlacementMode then
		if isBotPlacementValid then
			local hitPos = mouse.Hit.Position
			local x = math.floor(hitPos.X + 0.5)
			local z = math.floor(hitPos.Z + 0.5)

			-- Try to place bot at this position
			botBuildEvent:FireServer(x, z)

			-- SOUND: Play a satisfying sound
			local sfx = Instance.new("Sound", workspace)
			sfx.SoundId = "rbxassetid://9125699809"
			sfx.Volume = 0.7
			sfx.PlayOnRemove = true
			sfx:Destroy()

			-- SHIFT: Don't exit mode if holding SHIFT
			if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				exitBotPlacementMode()
			end
		else
			-- SOUND: Error buzzer
			local sfx = Instance.new("Sound", workspace)
			sfx.SoundId = "rbxassetid://71764947817417"
			sfx.Volume = 0.5
			sfx.PlayOnRemove = true
			sfx:Destroy()
		end
		return -- Consume click
	end

	local guiObjects = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
	for _, obj in ipairs(guiObjects) do
		-- Ignore clicks on any part of the IDE panels (editor, program panel)
		if obj:IsDescendantOf(editor.frame) or obj:IsDescendantOf(program.frame) then
			return
		end
		if obj.Active or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("TextBox") then
			return
		end
	end

	local target = mouse.Target
	if target then
		local model = target:FindFirstAncestorOfClass("Model")
		if model then
			-- Check if clicking on existing golem (enter mind mode)
			local golemId = model:GetAttribute("GolemId")
			if golemId and golemStates[golemId] then
				-- Check distance (within 15 studs)
				local character = player.Character
				if character then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					local golemHrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if hrp and golemHrp then
						enterGolemMind(golemId)
						return
					end
				end
			end

			-- Check if clicking on existing bot (enter bot mind mode)
			local botId = model:GetAttribute("BotId")
			if botId and botStates[botId] then
				local character = player.Character
				if character then
					local hrp = character:FindFirstChild("HumanoidRootPart")
					local botHrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if hrp and botHrp then
						enterBotMind(botId)
						return
					end
				end
			end
		end
	end

	-- If in golem mind mode and clicking on something else, exit
	if currentInterpreterTarget.type == "golem" then
		exitGolemMind()
		return
	end

	-- If in bot mind mode and clicking on something else, exit
	if currentInterpreterTarget.type == "bot" then
		exitBotMind()
		return
	end

	-- Otherwise, attack
	manualAttackEvent:FireServer()
end)

-- Keyboard shortcuts
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or
		UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

	-- Ctrl shortcuts work even when typing in editor
	if ctrl then
		-- Ctrl+Q: Unfocus editor and exit golem/bot mind
		if input.KeyCode == Enum.KeyCode.Q then
			if UserInputService:GetFocusedTextBox() then
				UserInputService:GetFocusedTextBox():ReleaseFocus()
			end
			if currentInterpreterTarget.type == "golem" then
				exitGolemMind()
			elseif currentInterpreterTarget.type == "bot" then
				exitBotMind()
			end
			return
			-- Ctrl+1: Run program
		elseif input.KeyCode == Enum.KeyCode.One then
			local source = editor:getText()
			runProgramEvent:FireServer(source, currentInterpreterTarget)
			return
			-- Ctrl+2: Pause program
		elseif input.KeyCode == Enum.KeyCode.Two then
			pauseProgramEvent:FireServer(currentInterpreterTarget)
			return
			-- Ctrl+3: Step program
		elseif input.KeyCode == Enum.KeyCode.Three then
			local source = editor:getText()
			stepProgramEvent:FireServer(source, currentInterpreterTarget)
			return
		end
	end

	-- Other shortcuts only work when NOT typing in a TextBox
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.B then
		-- B key: Toggle turret placement mode
		if botPlacementMode then exitBotPlacementMode() end
		if placementMode then
			exitPlacementMode()
		else
			enterPlacementMode()
		end
		return
	elseif input.KeyCode == Enum.KeyCode.N then
		-- N key: Toggle bot placement mode
		if placementMode then exitPlacementMode() end
		if botPlacementMode then
			exitBotPlacementMode()
		else
			enterBotPlacementMode()
		end
		return
	elseif input.KeyCode == Enum.KeyCode.Escape then
		-- Exit placement mode first if active
		if placementMode then
			exitPlacementMode()
			return
		end
		if botPlacementMode then
			exitBotPlacementMode()
			return
		end
		-- Then exit golem/bot mind mode if active
		if currentInterpreterTarget.type == "golem" then
			exitGolemMind()
		elseif currentInterpreterTarget.type == "bot" then
			exitBotMind()
		end
		return
	end
end)

--============================================================================
-- AMBIENT SOUND
--============================================================================

local function setupAmbientSound()
	local SoundService = game:GetService("SoundService")

	local ambientGroup = Instance.new("SoundGroup")
	ambientGroup.Name = "AmbientGroup"
	ambientGroup.Volume = 1
	ambientGroup.Parent = SoundService

	local tracks = SoundConfig.Ambient and SoundConfig.Ambient.Tracks
	if tracks and #tracks > 0 then
		local volume = SoundConfig.Ambient.Volume or 0.3

		local ambientSound = Instance.new("Sound")
		ambientSound.Name = "AmbientSound"
		ambientSound.Volume = volume
		ambientSound.Looped = false
		ambientSound.SoundGroup = ambientGroup
		ambientSound.Parent = SoundService

		local function playRandomTrack()
			local trackId = tracks[math.random(1, #tracks)]
			ambientSound.SoundId = trackId
			if not ambientSound.IsLoaded then
				ambientSound.Loaded:Wait()
			end
			ambientSound:Play()
		end

		ambientSound.Ended:Connect(function()
			task.wait(1)
			playRandomTrack()
		end)

		playRandomTrack()
	end
end

local GridNavigator = require(script.Parent.GridNavigator)
GridNavigator.enable()
setupAmbientSound()

-- Request current state from server (golems, bots) now that client is ready
requestStateEvent:FireServer()

print("PythonTD: Iron Defense client initialized")
