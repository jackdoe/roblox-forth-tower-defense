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
-- Client modules
local EditorPanel = require(script.Parent.UI.EditorPanel)
local ProgramPanel = require(script.Parent.UI.ProgramPanel)
local BytecodePanel = require(script.Parent.UI.BytecodePanel)
local HUD = require(script.Parent.UI.HUD)
local HelpPopup = require(script.Parent.UI.HelpPopup)
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
local playerFireEvent = PythonTD:WaitForChild("PlayerFire")

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
local showBytecodePanel -- Forward declaration for step button callback

-- Create help popup
local helpPopup = HelpPopup.create(screenGui, DragModule)
local function showHelp(targetWord)
	helpPopup.show(targetWord)
end

-- Helper to show/hide IDE based on target type
-- Now player IDE is always visible to show weapon programs
local function updateIDEVisibility()
	local isPlayer = (currentInterpreterTarget.type == "player")
	if editor and editor.frame then
		-- Always show IDE (player sees weapon programs, turrets/bots see their code)
		editor.frame.Visible = true
	end
	if program and program.frame then
		-- Show program panel (debugger) for all modes including player
		program.frame.Visible = true
	end
	if bytecodePanel then
		-- Show bytecode panel if enabled (for all modes)
		bytecodePanel:setVisible(bytecodeVisible)
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
local exitBotMindWrapper  -- Forward declaration for exitBotMind
local enterPlacementMode
local enterBotPlacementMode

-- Forward declaration for hud (needed for callbacks)
local hud

-- Create the new unified HUD
hud = HUD.create(screenGui, {
	onBuildTurret = function()
		if enterPlacementMode then
			enterPlacementMode()
		end
	end,
	onBuildBot = function()
		if enterBotPlacementMode then
			enterBotPlacementMode()
		end
	end,
	onEditCode = function(id, unitType)
		if unitType == "golem" and enterGolemMindWrapper then
			enterGolemMindWrapper(id)
		elseif unitType == "bot" and enterBotMindWrapper then
			enterBotMindWrapper(id)
		end
	end,
	onMove = function(id, unitType)
		if unitType == "golem" then
			-- Trigger move logic for turret
			isMovingGolem = true
			movingGolemId = id
			hud.deselect()
			print("Click on the map to move the turret...")
		end
	end,
	onSell = function(id, unitType)
		if unitType == "golem" then
			golemSellEvent:FireServer(id)
		elseif unitType == "bot" then
			botSellEvent:FireServer(id)
		end
		hud.deselect()
	end,
	onUpgrade = function(id, unitType)
		-- TODO: Implement upgrade system
		print("Upgrade not yet implemented for", unitType, id)
	end,
	onReady = function()
		playerReadyEvent:FireServer()
	end,
	onSkipBuild = function()
		skipBuildEvent:FireServer()
	end,
	-- Action bar callbacks (1-4: load weapon programs, 5-6: build)
	onLoadWeapon = function(weaponIndex)
		-- Handled below after weapon system is set up
		if loadWeaponProgram then
			loadWeaponProgram(weaponIndex)
		end
	end,
})

-- Move state for turrets (used by HUD onMove callback)
local isMovingGolem = false
local movingGolemId = nil

--============================================================================
-- STATE TRACKING
--============================================================================

local currentScrap = 0       -- Track locally for UI updates
local currentTurretCount = 0 -- Track turret count for cap display
local MAX_TURRETS = 10
local currentBotCount = 0 -- Track bot count for cap display
local MAX_BOTS = 5

-- Track current phase for visibility logic
local currentPhase = "LOBBY"

--============================================================================
-- WEAPON PROGRAM SYSTEM
--============================================================================

-- Weapon programs (loaded into player's Python VM)
local WEAPON_PROGRAMS = {
	[1] = {
		name = "BULLET",
		color = Color3.fromRGB(255, 255, 150),
		fireRate = 0.3,
		source = [[# BULLET - Fast single target
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]]
	},
	[2] = {
		name = "ROCKET",
		color = Color3.fromRGB(255, 100, 50),
		fireRate = 1.0,
		source = [[# ROCKET - Explosive splash damage
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), ROCKET)
]]
	},
	[3] = {
		name = "LASER",
		color = Color3.fromRGB(255, 50, 50),
		fireRate = 0.5,
		source = [[# LASER - Burning damage over time
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), LASER)
]]
	},
	[4] = {
		name = "GRENADE",
		color = Color3.fromRGB(100, 255, 100),
		fireRate = 1.5,
		source = [[# GRENADE - Thrown AOE explosive
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), GRENADE)
]]
	},
}

local currentWeapon = 1
local isReloading = false
local reloadEndTime = 0
local RELOAD_DURATION = 2.0  -- 2 seconds to switch weapons

-- Load a weapon program (always updates player's weapon, even when in bot/golem mind)
function loadWeaponProgram(weaponIndex)
	if weaponIndex < 1 or weaponIndex > 5 then return end
	if isReloading then return end
	if currentWeapon == weaponIndex then return end  -- Already loaded

	-- Start reload
	isReloading = true
	reloadEndTime = tick() + RELOAD_DURATION

	-- Get weapon data
	local weaponData = WEAPON_PROGRAMS[weaponIndex]
	if not weaponData then return end

	-- Update HUD (always shows player's current weapon)
	hud.setCurrentWeapon(weaponIndex)
	hud.highlightWeapon(weaponIndex)
	hud.triggerReloadCooldown(RELOAD_DURATION, weaponIndex)

	-- Only update editor if in player mode (not editing a bot/golem)
	if editor and editor:getMode() == "player" then
		editor:setTextFormatted(weaponData.source)
		editor:setWeaponName(weaponData.name)
	end

	-- Play reload sound (if we have one)
	-- TODO: Add reload sound

	-- Send to server to load the player's program (always, even when in bot/golem mind)
	runProgramEvent:FireServer(weaponData.source, { type = "player" })

	-- After reload completes, update state
	task.delay(RELOAD_DURATION, function()
		if hud.getCurrentWeapon() == weaponIndex then
			currentWeapon = weaponIndex
			isReloading = false
		end
	end)
end

-- Initialize with bullet program on startup
task.defer(function()
	-- Set editor to player mode first
	if editor then
		editor:setMode("player")
	end
	-- Then load default weapon
	loadWeaponProgram(1)
	isReloading = false  -- Don't count initial load as reload
end)

-- Bot placement state
local botPlacementMode = false
local ghostBot = nil

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

	-- Update new HUD (only when wave data is present to avoid flickering)
	if state.waveNumber then
		local phase = state.phase or "LOBBY"
		currentPhase = phase

		-- Update HUD elements
		hud.updateWave(state.waveNumber, state.wavePreview)
		hud.updateCore(state.coreHp or 0, state.coreMaxHp or 1000)

		local buildTimer = nil
		if state.buildTimeRemaining and state.buildTimeRemaining > 0 then
			buildTimer = math.ceil(state.buildTimeRemaining)
		end
		hud.updatePhase(phase, buildTimer)

		-- Track scrap for economy updates
		currentScrap = state.scrap or 0

		-- Update cargo indicator if player is carrying scrap
		if state.scrapInventory then
			hud.updateCargo(state.scrapInventory, state.maxCapacity or 50)
		end

		-- Game over states
		if phase == "GAMEOVER" then
			gameOverOverlay.Visible = true
			victoryOverlay.Visible = false
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
local nextTurretCost = 100 -- Dynamic cost from server
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

	-- Update next turret cost from server
	if data and data.nextTurretCost then
		nextTurretCost = data.nextTurretCost
	end

	-- Update HUD economy display
	hud.updateEconomy(currentScrap, nextTurretCost, 75) -- TODO: Get bot cost from server

	-- Show warning when reaching turret cap
	if currentTurretCount >= MAX_TURRETS and previousTurretCount < MAX_TURRETS then
		showNotification(
			"TURRET LIMIT REACHED",
			"Max " .. MAX_TURRETS .. " turrets!",
			"Sell a turret to build more (click turret)",
			4
		)
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

	-- Update inspector if a golem is selected
	if hud.selection and hud.selection.type == "golem" then
		local golemData = golemStates[hud.selection.id]
		if golemData then
			hud.select({
				id = golemData.id,
				type = "golem",
				spotId = golemData.spotId,
				ammo = golemData.ammo,
				maxAmmo = golemData.maxAmmo or 300,
				dynamicRange = golemData.dynamicRange or 40,
				status = golemData.paused and "PAUSED" or "ACTIVE",
			})
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

	-- Update inspector if a bot is selected
	if hud.selection and hud.selection.type == "bot" then
		local botData = botStates[hud.selection.id]
		if botData then
			hud.select({
				id = botData.id,
				type = "bot",
				spotId = botData.spotId,
				ammo = botData.ammo or 0,
				maxAmmo = botData.maxAmmo or 100,
				dynamicRange = 20, -- Bots have fixed range
				status = botData.paused and "PAUSED" or "ACTIVE",
			})
		end
	end
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

	-- Return to player mode with current weapon
	editor:setMode("player")
	program:setTheme("player")
	bytecodePanel:setTheme("player")
	updateIDEVisibility()

	-- Destroy range indicator ring
	if golemMindRangeRing then
		golemMindRangeRing:Destroy()
		golemMindRangeRing = nil
	end

	-- Restore current weapon program
	local weaponData = WEAPON_PROGRAMS[currentWeapon]
	if weaponData and editor then
		editor:setTextFormatted(weaponData.source)
		editor:setWeaponName(weaponData.name)
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

-- Handle mouse clicks for selecting units and moving turrets
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mouse = player:GetMouse()
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {player.Character}

		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)

		-- If in moving mode, move the turret
		if isMovingGolem and movingGolemId and result then
			local hitPos = result.Position
			golemMoveEvent:FireServer(movingGolemId, hitPos.X, hitPos.Z)
			return
		end

		-- Otherwise try to select a unit or attack an enemy by clicking
		if result and result.Instance then
			local hitPart = result.Instance
			local model = hitPart:FindFirstAncestorOfClass("Model")

			-- Check if clicked on an enemy - fire manual attack
			if model then
				local enemyId = model:GetAttribute("EnemyId")
				if enemyId then
					-- Fire manual attack - server will check range and damage
					manualAttackEvent:FireServer()
					return
				end
			end

			-- Check if clicked on a turret (golem) or bot using attributes
			if model then
				local golemId = model:GetAttribute("GolemId")
				local botId = model:GetAttribute("BotId")

				if golemId and golemStates[golemId] then
					local golemData = golemStates[golemId]
					hud.select({
						id = golemId,
						type = "golem",
						spotId = golemData.spotId,
						ammo = golemData.ammo,
						maxAmmo = golemData.maxAmmo or 300,
						dynamicRange = golemData.dynamicRange or 40,
						status = golemData.paused and "PAUSED" or "ACTIVE",
					})
					-- Auto-enter golem mind mode (shows IDE with read-only code)
					enterGolemMind(golemId)
					return
				elseif botId and botStates[botId] then
					local botData = botStates[botId]
					hud.select({
						id = botId,
						type = "bot",
						spotId = botData.spotId,
						ammo = botData.ammo or 0,
						maxAmmo = botData.maxAmmo or 100,
						dynamicRange = 20,
						status = botData.paused and "PAUSED" or "ACTIVE",
					})
					-- Auto-enter bot mind mode (shows IDE with editable code)
					if enterBotMindWrapper then
						enterBotMindWrapper(botId)
					end
					return
				end
			end

			-- If clicked on ground/nothing, deselect and exit mind mode
			hud.deselect()
			if currentInterpreterTarget.type == "golem" then
				exitGolemMind()
			elseif currentInterpreterTarget.type == "bot" and exitBotMindWrapper then
				exitBotMindWrapper()
			end
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

	-- Return to player mode with current weapon
	editor:setMode("player")
	program:setTheme("player")
	bytecodePanel:setTheme("player")
	updateIDEVisibility()

	-- Restore current weapon program
	local weaponData = WEAPON_PROGRAMS[currentWeapon]
	if weaponData and editor then
		editor:setTextFormatted(weaponData.source)
		editor:setWeaponName(weaponData.name)
	end
	golemProgramLoaded = false
end

-- Link the exit wrapper for forward declarations
exitBotMindWrapper = exitBotMind

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

-- Ground level from Config
local GROUND_Y = Config.PLATFORM_Y

local function createGhostTurret()
	local model = Instance.new("Model")
	model.Name = "GhostTurret"

	-- Simple cyan square block for turret placement
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 5, 5)
	base.Anchored = true
	base.CanCollide = false
	base.Material = Enum.Material.Neon
	base.Color = Color3.fromRGB(0, 255, 200) -- Cyan
	base.Transparency = 0.4
	base.Parent = model

	-- Range ring (flat cylinder)
	local range = 40
	local ring = Instance.new("Part")
	ring.Name = "RangeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, range * 2, range * 2)
	ring.Orientation = Vector3.new(0, 0, 90)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.ForceField
	ring.Color = Color3.fromRGB(0, 255, 255)
	ring.Transparency = 0.85
	ring.Parent = model

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

	-- Check if player has enough scrap (use dynamic cost)
	local hasScrap = currentScrap >= nextTurretCost

	-- Final Validity - paths are fine, but not on core or stacked
	local isValid = inBounds and not tooClose and not tooCloseToCore and hasScrap

	-- Color Logic: Green if valid, Red if invalid
	local color = isValid and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)

	-- Update Parts (use GROUND_Y for proper height)
	local base = ghostTurret:FindFirstChild("Base")
	local ring = ghostTurret:FindFirstChild("RangeRing")

	if base then
		base.Position = Vector3.new(x, GROUND_Y + 2.5, z)
		base.Color = color
	end
	if ring then
		ring.Position = Vector3.new(x, GROUND_Y + 0.2, z)
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

	-- Check if player can afford before entering (use dynamic cost)
	if currentScrap < nextTurretCost then
		print("Not enough scrap to build! Need " .. nextTurretCost .. ", have " .. currentScrap)
		return
	end

	placementMode = true

	-- Create ghost turret with range ring
	ghostTurret = createGhostTurret()
	ghostTurret.Parent = workspace

	-- Initial position update at mouse location
	local mouseTarget = player:GetMouse().Hit
	if mouseTarget then
		local x = math.floor(mouseTarget.Position.X + 0.5)
		local z = math.floor(mouseTarget.Position.Z + 0.5)
		updateGhostPosition(x, z)
	end

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

	-- Simple orange square block for bot placement
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 4, 4)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.Neon
	body.Color = Color3.fromRGB(255, 180, 50) -- Orange
	body.Transparency = 0.4
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
	ring.Color = Color3.fromRGB(255, 180, 50)
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

	-- Color: Orange if valid, Red if invalid
	local color = isValid and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(255, 50, 50)

	local body = ghostBot:FindFirstChild("Body")
	local ring = ghostBot:FindFirstChild("RangeRing")

	if body then
		body.Position = Vector3.new(x, GROUND_Y + 2, z)
		body.Color = color
	end
	if ring then
		ring.Position = Vector3.new(x, GROUND_Y + 0.2, z)
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

	-- Initial position update at mouse location
	local mouseTarget = player:GetMouse().Hit
	if mouseTarget then
		local x = math.floor(mouseTarget.Position.X + 0.5)
		local z = math.floor(mouseTarget.Position.Z + 0.5)
		updateGhostBotPosition(x, z)
	end

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

	-- Action bar hotkeys (1-6): 1-4 load weapon programs, 5-6 build
	if input.KeyCode == Enum.KeyCode.One then
		-- 1: Load Bullet program
		loadWeaponProgram(1)
		return
	elseif input.KeyCode == Enum.KeyCode.Two then
		-- 2: Load Rocket program
		loadWeaponProgram(2)
		return
	elseif input.KeyCode == Enum.KeyCode.Three then
		-- 3: Load Laser program
		loadWeaponProgram(3)
		return
	elseif input.KeyCode == Enum.KeyCode.Four then
		-- 4: Load Ice program
		loadWeaponProgram(4)
		return
	elseif input.KeyCode == Enum.KeyCode.Five then
		-- 5: Build Bot
		if placementMode then exitPlacementMode() end
		if botPlacementMode then
			exitBotPlacementMode()
		else
			enterBotPlacementMode()
		end
		return
	elseif input.KeyCode == Enum.KeyCode.Six then
		-- 6: Build Turret
		if botPlacementMode then exitBotPlacementMode() end
		if placementMode then
			exitPlacementMode()
		else
			enterPlacementMode()
		end
		return
	elseif input.KeyCode == Enum.KeyCode.Tab then
		-- Tab: Select nearest unit in front of player
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local playerPos = hrp.Position
				local lookDir = hrp.CFrame.LookVector

				-- Find nearest turret or bot in front of player
				local nearestId, nearestType, nearestDist = nil, nil, math.huge

				-- Check turrets
				for id, golem in pairs(golemStates) do
					-- Find the turret's character in workspace
					for _, obj in pairs(workspace:GetDescendants()) do
						if obj:GetAttribute("GolemId") == id then
							local objPos = obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Position
								or obj:IsA("BasePart") and obj.Position
							if objPos then
								local toObj = (objPos - playerPos)
								local dist = toObj.Magnitude
								-- Check if in front (dot product > 0)
								local dot = lookDir:Dot(toObj.Unit)
								if dot > 0 and dist < nearestDist then
									nearestDist = dist
									nearestId = id
									nearestType = "golem"
								end
							end
							break
						end
					end
				end

				-- Check bots
				for id, bot in pairs(botStates) do
					for _, obj in pairs(workspace:GetDescendants()) do
						if obj:GetAttribute("BotId") == id then
							local objPos = obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Position
								or obj:IsA("BasePart") and obj.Position
							if objPos then
								local toObj = (objPos - playerPos)
								local dist = toObj.Magnitude
								local dot = lookDir:Dot(toObj.Unit)
								if dot > 0 and dist < nearestDist then
									nearestDist = dist
									nearestId = id
									nearestType = "bot"
								end
							end
							break
						end
					end
				end

				-- Select the found unit
				if nearestId then
					if nearestType == "golem" then
						local golemData = golemStates[nearestId]
						hud.select({
							id = nearestId,
							type = "golem",
							spotId = golemData.spotId,
							ammo = golemData.ammo,
							maxAmmo = golemData.maxAmmo or 300,
							dynamicRange = golemData.dynamicRange or 40,
							status = golemData.paused and "PAUSED" or "ACTIVE",
						})
						enterGolemMind(nearestId)
					elseif nearestType == "bot" then
						local botData = botStates[nearestId]
						hud.select({
							id = nearestId,
							type = "bot",
							spotId = botData.spotId,
							ammo = botData.ammo or 0,
							maxAmmo = botData.maxAmmo or 100,
							dynamicRange = 20,
							status = botData.paused and "PAUSED" or "ACTIVE",
						})
						if enterBotMindWrapper then
							enterBotMindWrapper(nearestId)
						end
					end
				end
			end
		end
		return
	elseif input.KeyCode == Enum.KeyCode.B then
		-- B key: Toggle turret placement mode (legacy, same as 6)
		if botPlacementMode then exitBotPlacementMode() end
		if placementMode then
			exitPlacementMode()
		else
			enterPlacementMode()
		end
		return
	elseif input.KeyCode == Enum.KeyCode.N then
		-- N key: Toggle bot placement mode (legacy, same as 5)
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

--============================================================================
-- COMBAT STATUS UPDATE LOOP
--============================================================================
-- Combat status indicator was removed from HUD for cleaner UI

print("PythonTD: Iron Defense client initialized")
