-- HUD.luau
-- The unified "Commander's Console" interface for Iron Defense
-- Replaces UnitListPanel and TDPanel with a modern RTS-style HUD

local Players = game:GetService("Players")
local HUD = {}

-- Visual Assets (colors)
local COLORS = {
	bg = Color3.fromRGB(20, 24, 30),
	panel = Color3.fromRGB(30, 35, 45),
	accent = Color3.fromRGB(0, 255, 200),
	danger = Color3.fromRGB(255, 80, 80),
	success = Color3.fromRGB(80, 255, 100),
	warning = Color3.fromRGB(255, 200, 50),
	text = Color3.fromRGB(240, 240, 240),
	subtext = Color3.fromRGB(150, 160, 180),
}

-- Enemy type icons (emoji-style)
local ENEMY_ICONS = {
	Zombie = "Z",
	Runner = "R",
	Tank = "T",
	Boss = "B",
}

local ENEMY_COLORS = {
	Zombie = Color3.fromRGB(100, 180, 100),
	Runner = Color3.fromRGB(255, 200, 100),
	Tank = Color3.fromRGB(150, 150, 200),
	Boss = Color3.fromRGB(255, 80, 80),
}

function HUD.create(parent, callbacks)
	local hud = {
		callbacks = callbacks or {},
		selection = nil, -- Currently selected unit data
	}

	--=========================================================================
	-- 1. TOP BAR (Wave Info + Minimalist Enemy Queue)
	--=========================================================================
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0, 300, 0, 36)  -- More compact
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 10)
	topBar.BackgroundColor3 = COLORS.panel
	topBar.BorderSizePixel = 0
	topBar.Parent = parent

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 6)
	topCorner.Parent = topBar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(50, 55, 65)
	topStroke.Thickness = 1
	topStroke.Parent = topBar

	-- Wave number display (compact)
	local waveTitle = Instance.new("TextLabel")
	waveTitle.Name = "WaveTitle"
	waveTitle.Size = UDim2.new(0, 50, 1, 0)
	waveTitle.BackgroundTransparency = 1
	waveTitle.Text = "W1"
	waveTitle.Font = Enum.Font.GothamBold
	waveTitle.TextSize = 18
	waveTitle.TextColor3 = COLORS.accent
	waveTitle.Parent = topBar

	-- Enemy queue container (dots representing enemies)
	local queueFrame = Instance.new("Frame")
	queueFrame.Name = "QueueFrame"
	queueFrame.Size = UDim2.new(1, -60, 0, 24)
	queueFrame.Position = UDim2.new(0, 55, 0.5, -12)
	queueFrame.BackgroundColor3 = COLORS.bg
	queueFrame.BackgroundTransparency = 0.5
	queueFrame.ClipsDescendants = true
	queueFrame.Parent = topBar

	local queueCorner = Instance.new("UICorner")
	queueCorner.CornerRadius = UDim.new(0, 4)
	queueCorner.Parent = queueFrame

	-- Queue layout (horizontal dots)
	local queueLayout = Instance.new("UIListLayout")
	queueLayout.FillDirection = Enum.FillDirection.Horizontal
	queueLayout.Padding = UDim.new(0, 2)
	queueLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	queueLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	queueLayout.Parent = queueFrame

	local queuePadding = Instance.new("UIPadding")
	queuePadding.PaddingLeft = UDim.new(0, 4)
	queuePadding.Parent = queueFrame

	-- Enemy size mapping (height of dot indicates threat level)
	local ENEMY_SIZES = {
		Zombie = 8,   -- Small
		Runner = 10,  -- Medium
		Tank = 16,    -- Large
		Boss = 20,    -- Huge
	}

	--=========================================================================
	-- 2. ACTION BAR (Hotkeys 1-6: Weapons + Building)
	--=========================================================================
	local actionBar = Instance.new("Frame")
	actionBar.Name = "ActionBar"
	actionBar.Size = UDim2.new(0, 340, 0, 60)
	actionBar.AnchorPoint = Vector2.new(0.5, 1)
	actionBar.Position = UDim2.new(0.5, 0, 1, -10)
	actionBar.BackgroundColor3 = COLORS.panel
	actionBar.BorderSizePixel = 0
	actionBar.Parent = parent

	local actionBarCorner = Instance.new("UICorner")
	actionBarCorner.CornerRadius = UDim.new(0, 10)
	actionBarCorner.Parent = actionBar

	local actionBarStroke = Instance.new("UIStroke")
	actionBarStroke.Color = Color3.fromRGB(50, 55, 65)
	actionBarStroke.Thickness = 1
	actionBarStroke.Parent = actionBar

	-- Action Buttons Container
	local actionContainer = Instance.new("Frame")
	actionContainer.Name = "ActionContainer"
	actionContainer.Size = UDim2.new(1, -16, 1, -12)
	actionContainer.Position = UDim2.new(0, 8, 0, 6)
	actionContainer.BackgroundTransparency = 1
	actionContainer.Parent = actionBar

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 4)
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Parent = actionContainer

	-- Helper to create Action Buttons
	local function createActionSlot(hotkey, icon, tooltip, color)
		local btn = Instance.new("TextButton")
		btn.Name = "Action" .. hotkey
		btn.Size = UDim2.new(0, 48, 0, 44)
		btn.BackgroundColor3 = COLORS.bg
		btn.Text = ""
		btn.AutoButtonColor = true
		btn.Parent = actionContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2
		stroke.Parent = btn

		-- Icon/emoji
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Size = UDim2.new(1, 0, 0.65, 0)
		iconLabel.Position = UDim2.new(0, 0, 0, 0)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = icon
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 16
		iconLabel.TextColor3 = color
		iconLabel.Parent = btn

		-- Hotkey number
		local hotkeyLabel = Instance.new("TextLabel")
		hotkeyLabel.Name = "Hotkey"
		hotkeyLabel.Size = UDim2.new(1, 0, 0.35, 0)
		hotkeyLabel.Position = UDim2.new(0, 0, 0.65, 0)
		hotkeyLabel.BackgroundTransparency = 1
		hotkeyLabel.Text = hotkey
		hotkeyLabel.TextColor3 = COLORS.subtext
		hotkeyLabel.Font = Enum.Font.Code
		hotkeyLabel.TextSize = 10
		hotkeyLabel.Parent = btn

		return btn, stroke
	end

	-- Ammo type colors
	local AMMO_COLORS = {
		bullet = Color3.fromRGB(255, 255, 150),  -- Yellow
		rocket = Color3.fromRGB(255, 100, 50),   -- Orange
		laser = Color3.fromRGB(255, 50, 50),     -- Red
		grenade = Color3.fromRGB(100, 255, 100), -- Green
	}

	-- Actions: 1=Bullet, 2=Rocket, 3=Laser, 4=Grenade, 5=Bot, 6=Turret
	local bulletBtn, bulletStroke = createActionSlot("1", "•", "Bullet", AMMO_COLORS.bullet)
	local rocketBtn, rocketStroke = createActionSlot("2", "◆", "Rocket", AMMO_COLORS.rocket)
	local laserBtn, laserStroke = createActionSlot("3", "—", "Laser", AMMO_COLORS.laser)
	local grenadeBtn, grenadeStroke = createActionSlot("4", "●", "Grenade", AMMO_COLORS.grenade)
	local botBtn, botStroke = createActionSlot("5", "🤖", "Bot", COLORS.warning)
	local turretBtn, turretStroke = createActionSlot("6", "🗼", "Turret", COLORS.accent)

	-- Cost labels (shown below action bar)
	local costDisplay = Instance.new("Frame")
	costDisplay.Name = "CostDisplay"
	costDisplay.Size = UDim2.new(0, 200, 0, 18)
	costDisplay.AnchorPoint = Vector2.new(0.5, 0)
	costDisplay.Position = UDim2.new(0.5, 0, 1, 2)
	costDisplay.BackgroundTransparency = 1
	costDisplay.Parent = actionBar

	local botCostLabel = Instance.new("TextLabel")
	botCostLabel.Name = "BotCost"
	botCostLabel.Size = UDim2.new(0.5, 0, 1, 0)
	botCostLabel.Position = UDim2.new(0, 0, 0, 0)
	botCostLabel.BackgroundTransparency = 1
	botCostLabel.Text = "Bot: 75"
	botCostLabel.TextColor3 = COLORS.warning
	botCostLabel.Font = Enum.Font.Gotham
	botCostLabel.TextSize = 10
	botCostLabel.Parent = costDisplay

	local turretCostLabel = Instance.new("TextLabel")
	turretCostLabel.Name = "TurretCost"
	turretCostLabel.Size = UDim2.new(0.5, 0, 1, 0)
	turretCostLabel.Position = UDim2.new(0.5, 0, 0, 0)
	turretCostLabel.BackgroundTransparency = 1
	turretCostLabel.Text = "Turret: 100"
	turretCostLabel.TextColor3 = COLORS.accent
	turretCostLabel.Font = Enum.Font.Gotham
	turretCostLabel.TextSize = 10
	turretCostLabel.Parent = costDisplay

	-- Button callbacks (1-4: load weapon programs, 5-6: build)
	bulletBtn.MouseButton1Click:Connect(function()
		if callbacks.onLoadWeapon then callbacks.onLoadWeapon(1) end
	end)

	rocketBtn.MouseButton1Click:Connect(function()
		if callbacks.onLoadWeapon then callbacks.onLoadWeapon(2) end
	end)

	laserBtn.MouseButton1Click:Connect(function()
		if callbacks.onLoadWeapon then callbacks.onLoadWeapon(3) end
	end)

	grenadeBtn.MouseButton1Click:Connect(function()
		if callbacks.onLoadWeapon then callbacks.onLoadWeapon(4) end
	end)

	botBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuildBot then callbacks.onBuildBot() end
	end)

	turretBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuildTurret then callbacks.onBuildTurret() end
	end)

	--=========================================================================
	-- 2b. GLOBAL COOLDOWN OVERLAY (WoW-style sweep)
	--=========================================================================
	local TweenService = game:GetService("TweenService")

	-- Create cooldown overlay for each weapon button
	local function createCooldownOverlay(btn)
		local overlay = Instance.new("Frame")
		overlay.Name = "CooldownOverlay"
		overlay.Size = UDim2.new(1, 0, 0, 0)  -- Start at 0 height
		overlay.Position = UDim2.new(0, 0, 1, 0)  -- Start at bottom
		overlay.AnchorPoint = Vector2.new(0, 1)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.5
		overlay.ZIndex = 10
		overlay.Parent = btn

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 6)
		overlayCorner.Parent = overlay

		return overlay
	end

	local bulletOverlay = createCooldownOverlay(bulletBtn)
	local rocketOverlay = createCooldownOverlay(rocketBtn)
	local laserOverlay = createCooldownOverlay(laserBtn)
	local grenadeOverlay = createCooldownOverlay(grenadeBtn)

	-- Track current weapon and reload state
	local currentWeapon = 1  -- 1=bullet, 2=rocket, 3=laser, 4=ice
	local isReloading = false
	local weaponButtons = {bulletBtn, rocketBtn, laserBtn, grenadeBtn}
	local weaponOverlays = {bulletOverlay, rocketOverlay, laserOverlay, grenadeOverlay}

	-- Highlight active weapon
	local function highlightWeapon(weaponIndex)
		for i, btn in ipairs(weaponButtons) do
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = (i == weaponIndex) and 3 or 2
			end
			-- Add/remove active indicator
			local activeIndicator = btn:FindFirstChild("ActiveIndicator")
			if i == weaponIndex then
				if not activeIndicator then
					activeIndicator = Instance.new("Frame")
					activeIndicator.Name = "ActiveIndicator"
					activeIndicator.Size = UDim2.new(0.6, 0, 0, 3)
					activeIndicator.Position = UDim2.new(0.2, 0, 1, -5)
					activeIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					activeIndicator.Parent = btn
					local indCorner = Instance.new("UICorner")
					indCorner.CornerRadius = UDim.new(0, 2)
					indCorner.Parent = activeIndicator
				end
				activeIndicator.Visible = true
			elseif activeIndicator then
				activeIndicator.Visible = false
			end
		end
	end

	-- Start with bullet highlighted
	highlightWeapon(1)

	-- Trigger global cooldown animation (sweep from bottom to top then disappear)
	local function triggerGlobalCooldown(duration)
		for _, overlay in ipairs(weaponOverlays) do
			-- Reset to full coverage
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.Position = UDim2.new(0, 0, 1, 0)

			-- Animate sweep (shrink from top)
			local tween = TweenService:Create(overlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(1, 0, 0, 0)
			})
			tween:Play()
		end
	end

	-- Reload animation (longer cooldown when switching weapons)
	local function triggerReloadCooldown(duration, weaponIndex)
		isReloading = true

		-- Darken all weapon buttons during reload
		for i, overlay in ipairs(weaponOverlays) do
			overlay.Size = UDim2.new(1, 0, 1, 0)
			overlay.BackgroundTransparency = 0.7
		end

		-- Animate sweep on the new weapon
		local targetOverlay = weaponOverlays[weaponIndex]
		if targetOverlay then
			local tween = TweenService:Create(targetOverlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				Size = UDim2.new(1, 0, 0, 0)
			})
			tween:Play()
			tween.Completed:Connect(function()
				isReloading = false
				-- Reset all overlays
				for _, ov in ipairs(weaponOverlays) do
					ov.Size = UDim2.new(1, 0, 0, 0)
					ov.BackgroundTransparency = 0.5
				end
			end)
		end
	end

	-- Expose functions for external use
	hud.triggerGlobalCooldown = triggerGlobalCooldown
	hud.triggerReloadCooldown = triggerReloadCooldown
	hud.highlightWeapon = highlightWeapon
	hud.isReloading = function() return isReloading end
	hud.getCurrentWeapon = function() return currentWeapon end
	hud.setCurrentWeapon = function(w) currentWeapon = w end

	--=========================================================================
	-- 2c. CARGO INDICATOR (Shows when carrying scrap)
	--=========================================================================
	local cargoIndicator = Instance.new("Frame")
	cargoIndicator.Name = "CargoIndicator"
	cargoIndicator.Size = UDim2.new(0, 100, 0, 30)
	cargoIndicator.Position = UDim2.new(0.5, 0, 1, -80)
	cargoIndicator.AnchorPoint = Vector2.new(0.5, 1)
	cargoIndicator.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
	cargoIndicator.Visible = false
	cargoIndicator.Parent = parent

	local cargoCorner = Instance.new("UICorner")
	cargoCorner.CornerRadius = UDim.new(0, 6)
	cargoCorner.Parent = cargoIndicator

	local cargoStroke = Instance.new("UIStroke")
	cargoStroke.Color = COLORS.warning
	cargoStroke.Thickness = 2
	cargoStroke.Parent = cargoIndicator

	local cargoIcon = Instance.new("TextLabel")
	cargoIcon.Size = UDim2.new(0, 30, 1, 0)
	cargoIcon.BackgroundTransparency = 1
	cargoIcon.Text = "📦"
	cargoIcon.TextSize = 18
	cargoIcon.Parent = cargoIndicator

	local cargoText = Instance.new("TextLabel")
	cargoText.Name = "CargoText"
	cargoText.Size = UDim2.new(1, -35, 1, 0)
	cargoText.Position = UDim2.new(0, 30, 0, 0)
	cargoText.BackgroundTransparency = 1
	cargoText.Text = "0 / 50"
	cargoText.TextColor3 = COLORS.warning
	cargoText.Font = Enum.Font.GothamBold
	cargoText.TextSize = 14
	cargoText.TextXAlignment = Enum.TextXAlignment.Left
	cargoText.Parent = cargoIndicator

	hud.updateCargo = function(amount, maxAmount)
		if amount and amount > 0 then
			cargoIndicator.Visible = true
			cargoText.Text = amount .. " / " .. (maxAmount or 50)
		else
			cargoIndicator.Visible = false
		end
	end

	-- Combat status indicator removed (was too cluttered)

	--=========================================================================
	-- 3. SELECTION INSPECTOR (Right Side Panel)
	--=========================================================================
	local inspector = Instance.new("Frame")
	inspector.Name = "Inspector"
	inspector.Size = UDim2.new(0, 180, 0, 140)
	inspector.Position = UDim2.new(0, 15, 1, -155)
	inspector.BackgroundColor3 = COLORS.panel
	inspector.BorderSizePixel = 0
	inspector.Visible = false -- Hidden until selection
	inspector.Parent = parent

	local inspectorCorner = Instance.new("UICorner")
	inspectorCorner.CornerRadius = UDim.new(0, 10)
	inspectorCorner.Parent = inspector

	local inspectorStroke = Instance.new("UIStroke")
	inspectorStroke.Color = Color3.fromRGB(50, 55, 65)
	inspectorStroke.Thickness = 1
	inspectorStroke.Parent = inspector

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -30, 0, 6)
	closeBtn.BackgroundColor3 = COLORS.bg
	closeBtn.Text = "X"
	closeBtn.TextColor3 = COLORS.subtext
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 12
	closeBtn.Parent = inspector

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 4)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		hud.select(nil)
	end)

	-- Title
	local inspectTitle = Instance.new("TextLabel")
	inspectTitle.Name = "Title"
	inspectTitle.Size = UDim2.new(1, -35, 0, 24)
	inspectTitle.Position = UDim2.new(0, 10, 0, 5)
	inspectTitle.BackgroundTransparency = 1
	inspectTitle.Text = "TURRET #1"
	inspectTitle.Font = Enum.Font.GothamBlack
	inspectTitle.TextSize = 14
	inspectTitle.TextColor3 = COLORS.accent
	inspectTitle.TextXAlignment = Enum.TextXAlignment.Left
	inspectTitle.Parent = inspector

	-- Stats Container
	local statContainer = Instance.new("Frame")
	statContainer.Name = "Stats"
	statContainer.Size = UDim2.new(1, -20, 0, 60)
	statContainer.Position = UDim2.new(0, 10, 0, 30)
	statContainer.BackgroundTransparency = 1
	statContainer.Parent = inspector

	local statLayout = Instance.new("UIListLayout")
	statLayout.Padding = UDim.new(0, 4)
	statLayout.Parent = statContainer

	local function createStatRow(name, initialVal)
		local row = Instance.new("Frame")
		row.Name = name
		row.Size = UDim2.new(1, 0, 0, 16)
		row.BackgroundTransparency = 1
		row.Parent = statContainer

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.45, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = COLORS.subtext
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextSize = 10
		nameLabel.Parent = row

		local valLabel = Instance.new("TextLabel")
		valLabel.Name = "Value"
		valLabel.Size = UDim2.new(0.55, 0, 1, 0)
		valLabel.Position = UDim2.new(0.45, 0, 0, 0)
		valLabel.BackgroundTransparency = 1
		valLabel.Text = initialVal
		valLabel.TextColor3 = COLORS.text
		valLabel.TextXAlignment = Enum.TextXAlignment.Right
		valLabel.Font = Enum.Font.GothamBold
		valLabel.TextSize = 10
		valLabel.Parent = row

		return valLabel
	end

	local statAmmo = createStatRow("AMMO", "300/300")
	local statRange = createStatRow("RANGE", "40 studs")
	local statStatus = createStatRow("STATUS", "IDLE")

	-- Action Buttons Container
	local actionContainer = Instance.new("Frame")
	actionContainer.Name = "Actions"
	actionContainer.Size = UDim2.new(1, -20, 0, 40)
	actionContainer.Position = UDim2.new(0, 10, 1, -48)
	actionContainer.BackgroundTransparency = 1
	actionContainer.Parent = inspector

	local actionLayout = Instance.new("UIGridLayout")
	actionLayout.CellSize = UDim2.new(0.48, 0, 0, 28)
	actionLayout.CellPadding = UDim2.new(0.04, 0, 0, 6)
	actionLayout.Parent = actionContainer

	local function createActionBtn(text, color, callback)
		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = COLORS.bg
		btn.Text = text
		btn.TextColor3 = color
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 10
		btn.Parent = actionContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 1
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if callback then callback() end
		end)

		return btn
	end

	-- CODE button removed - clicking unit auto-enters mind mode

	local moveBtn = createActionBtn("MOVE", COLORS.warning, function()
		if hud.selection and callbacks.onMove then
			callbacks.onMove(hud.selection.id, hud.selection.type)
		end
	end)

	local sellBtn = createActionBtn("SELL", COLORS.danger, function()
		if hud.selection and callbacks.onSell then
			callbacks.onSell(hud.selection.id, hud.selection.type)
		end
	end)

	local upgradeBtn = createActionBtn("UPGRADE", COLORS.success, function()
		if hud.selection and callbacks.onUpgrade then
			callbacks.onUpgrade(hud.selection.id, hud.selection.type)
		end
	end)

	--=========================================================================
	-- 4. CORE HP DISPLAY (Top Left)
	--=========================================================================
	local coreDisplay = Instance.new("Frame")
	coreDisplay.Name = "CoreDisplay"
	coreDisplay.Size = UDim2.new(0, 160, 0, 50)
	coreDisplay.Position = UDim2.new(0, 15, 0, 10)
	coreDisplay.BackgroundColor3 = COLORS.panel
	coreDisplay.Parent = parent

	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(0, 8)
	coreCorner.Parent = coreDisplay

	local coreLabel = Instance.new("TextLabel")
	coreLabel.Name = "Label"
	coreLabel.Size = UDim2.new(1, -10, 0, 20)
	coreLabel.Position = UDim2.new(0, 5, 0, 5)
	coreLabel.BackgroundTransparency = 1
	coreLabel.Text = "CORE HP"
	coreLabel.TextColor3 = COLORS.subtext
	coreLabel.Font = Enum.Font.GothamBold
	coreLabel.TextSize = 10
	coreLabel.TextXAlignment = Enum.TextXAlignment.Left
	coreLabel.Parent = coreDisplay

	local coreHP = Instance.new("TextLabel")
	coreHP.Name = "HP"
	coreHP.Size = UDim2.new(1, -10, 0, 25)
	coreHP.Position = UDim2.new(0, 5, 0, 22)
	coreHP.BackgroundTransparency = 1
	coreHP.Text = "1000 / 1000"
	coreHP.TextColor3 = COLORS.success
	coreHP.Font = Enum.Font.GothamBlack
	coreHP.TextSize = 16
	coreHP.TextXAlignment = Enum.TextXAlignment.Left
	coreHP.Parent = coreDisplay

	--=========================================================================
	-- 5. SCRAP DISPLAY (Top Left, below Core)
	--=========================================================================
	local scrapDisplay = Instance.new("Frame")
	scrapDisplay.Name = "ScrapDisplay"
	scrapDisplay.Size = UDim2.new(0, 160, 0, 28)
	scrapDisplay.Position = UDim2.new(0, 15, 0, 65)
	scrapDisplay.BackgroundColor3 = COLORS.panel
	scrapDisplay.Parent = parent

	local scrapCorner = Instance.new("UICorner")
	scrapCorner.CornerRadius = UDim.new(0, 8)
	scrapCorner.Parent = scrapDisplay

	local scrapText = Instance.new("TextLabel")
	scrapText.Name = "ScrapText"
	scrapText.Size = UDim2.new(1, -10, 1, 0)
	scrapText.Position = UDim2.new(0, 5, 0, 0)
	scrapText.BackgroundTransparency = 1
	scrapText.Text = "SCRAP: 600"
	scrapText.TextColor3 = COLORS.warning
	scrapText.Font = Enum.Font.GothamBold
	scrapText.TextSize = 14
	scrapText.TextXAlignment = Enum.TextXAlignment.Left
	scrapText.Parent = scrapDisplay

	--=========================================================================
	-- 6. PHASE INDICATOR (Top Left, below Scrap)
	--=========================================================================
	local phaseDisplay = Instance.new("Frame")
	phaseDisplay.Name = "PhaseDisplay"
	phaseDisplay.Size = UDim2.new(0, 160, 0, 35)
	phaseDisplay.Position = UDim2.new(0, 15, 0, 98)
	phaseDisplay.BackgroundColor3 = COLORS.panel
	phaseDisplay.Parent = parent

	local phaseCorner = Instance.new("UICorner")
	phaseCorner.CornerRadius = UDim.new(0, 8)
	phaseCorner.Parent = phaseDisplay

	local phaseText = Instance.new("TextLabel")
	phaseText.Name = "Text"
	phaseText.Size = UDim2.new(1, -10, 1, 0)
	phaseText.Position = UDim2.new(0, 5, 0, 0)
	phaseText.BackgroundTransparency = 1
	phaseText.Text = "BUILD PHASE"
	phaseText.TextColor3 = COLORS.accent
	phaseText.Font = Enum.Font.GothamBold
	phaseText.TextSize = 14
	phaseText.TextXAlignment = Enum.TextXAlignment.Left
	phaseText.Parent = phaseDisplay

	--=========================================================================
	-- 7. WAVE ACTION BUTTON (Ready/Skip)
	--=========================================================================
	local waveActionBtn = Instance.new("TextButton")
	waveActionBtn.Name = "WaveActionBtn"
	waveActionBtn.Size = UDim2.new(0, 160, 0, 35)
	waveActionBtn.Position = UDim2.new(0, 15, 0, 138)
	waveActionBtn.BackgroundColor3 = COLORS.accent
	waveActionBtn.Text = "READY"
	waveActionBtn.TextColor3 = COLORS.bg
	waveActionBtn.Font = Enum.Font.GothamBold
	waveActionBtn.TextSize = 14
	waveActionBtn.AutoButtonColor = true
	waveActionBtn.Parent = parent

	local waveActionCorner = Instance.new("UICorner")
	waveActionCorner.CornerRadius = UDim.new(0, 8)
	waveActionCorner.Parent = waveActionBtn

	-- Track current phase for button behavior
	local currentPhase = "LOBBY"

	waveActionBtn.MouseButton1Click:Connect(function()
		if currentPhase == "LOBBY" then
			if callbacks.onReady then callbacks.onReady() end
		elseif currentPhase == "BUILD" then
			if callbacks.onSkipBuild then callbacks.onSkipBuild() end
		end
	end)

	--=========================================================================
	-- PUBLIC FUNCTIONS
	--=========================================================================

	function hud.updateWave(waveNum, previewList)
		waveTitle.Text = "W" .. (waveNum or 1)

		-- Clear old queue
		for _, child in ipairs(queueFrame:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		-- Populate queue with minimalist dots (each dot = 1 enemy, size = threat)
		if previewList and #previewList > 0 then
			-- Show up to 40 enemies as dots
			local maxDots = math.min(40, #previewList)
			for i = 1, maxDots do
				local typeName = previewList[i]
				local size = ENEMY_SIZES[typeName] or 8
				local color = ENEMY_COLORS[typeName] or COLORS.subtext

				local dot = Instance.new("Frame")
				dot.Name = "Enemy" .. i
				dot.Size = UDim2.new(0, 4, 0, size)  -- Width=4, height=threat
				dot.BackgroundColor3 = color
				dot.BorderSizePixel = 0
				dot.LayoutOrder = i
				dot.Parent = queueFrame

				local dotCorner = Instance.new("UICorner")
				dotCorner.CornerRadius = UDim.new(0, 2)
				dotCorner.Parent = dot
			end

			-- If more enemies, show indicator
			if #previewList > maxDots then
				local more = Instance.new("TextLabel")
				more.Name = "More"
				more.Size = UDim2.new(0, 20, 0, 16)
				more.BackgroundTransparency = 1
				more.Text = "+" .. (#previewList - maxDots)
				more.TextColor3 = COLORS.subtext
				more.Font = Enum.Font.Code
				more.TextSize = 9
				more.LayoutOrder = maxDots + 1
				more.Parent = queueFrame
			end
		end
	end

	function hud.updateEconomy(scrap, turretCost, botCost)
		scrapText.Text = "SCRAP: " .. (scrap or 0)

		turretCostLabel.Text = "Turret: " .. (turretCost or 100)
		botCostLabel.Text = "Bot: " .. (botCost or 75)

		-- Update button affordability visuals
		if scrap >= turretCost then
			turretStroke.Color = COLORS.accent
		else
			turretStroke.Color = COLORS.subtext
		end

		if scrap >= botCost then
			botStroke.Color = COLORS.warning
		else
			botStroke.Color = COLORS.subtext
		end
	end

	function hud.updateCore(hp, maxHp)
		coreHP.Text = (hp or 0) .. " / " .. (maxHp or 1000)

		-- Color based on health ratio
		local ratio = (hp or 0) / (maxHp or 1000)
		if ratio > 0.6 then
			coreHP.TextColor3 = COLORS.success
		elseif ratio > 0.3 then
			coreHP.TextColor3 = COLORS.warning
		else
			coreHP.TextColor3 = COLORS.danger
		end
	end

	function hud.updatePhase(phaseName, timer)
		-- Update tracked phase for button behavior
		currentPhase = phaseName or "LOBBY"

		if phaseName == "BUILD" then
			if timer then
				phaseText.Text = "BUILD: " .. timer .. "s"
			else
				phaseText.Text = "BUILD PHASE"
			end
			phaseText.TextColor3 = COLORS.accent
			-- Show SKIP button during build
			waveActionBtn.Text = "SKIP BUILD"
			waveActionBtn.BackgroundColor3 = COLORS.warning
			waveActionBtn.Visible = true
		elseif phaseName == "COMBAT" then
			phaseText.Text = "COMBAT!"
			phaseText.TextColor3 = COLORS.danger
			-- Hide button during combat
			waveActionBtn.Visible = false
		elseif phaseName == "LOBBY" then
			phaseText.Text = "WAITING..."
			phaseText.TextColor3 = COLORS.subtext
			-- Show READY button in lobby
			waveActionBtn.Text = "READY"
			waveActionBtn.BackgroundColor3 = COLORS.accent
			waveActionBtn.Visible = true
		else
			phaseText.Text = phaseName or "---"
			phaseText.TextColor3 = COLORS.text
			waveActionBtn.Visible = false
		end
	end

	function hud.select(objData)
		hud.selection = objData -- {id, type, spotId, ammo, maxAmmo, dynamicRange, status}

		if not objData then
			inspector.Visible = false
			return
		end

		inspector.Visible = true

		-- Update title and buttons based on type
		if objData.type == "golem" then
			inspectTitle.Text = "TURRET #" .. (objData.spotId or "?")
			inspectTitle.TextColor3 = COLORS.accent
			moveBtn.Visible = true
			upgradeBtn.Visible = true
		elseif objData.type == "bot" then
			inspectTitle.Text = "BOT #" .. (objData.spotId or "?")
			inspectTitle.TextColor3 = COLORS.warning
			moveBtn.Visible = false
			upgradeBtn.Visible = false  -- Bots can't be upgraded
		else
			inspectTitle.Text = "UNIT"
			inspectTitle.TextColor3 = COLORS.text
			upgradeBtn.Visible = false
		end

		-- Update stats
		statAmmo.Text = (objData.ammo or 0) .. "/" .. (objData.maxAmmo or 300)
		statRange.Text = (objData.dynamicRange or 40) .. " studs"
		statStatus.Text = objData.status or "IDLE"
	end

	function hud.deselect()
		hud.select(nil)
	end

	-- Expose elements for external updates
	hud.inspector = inspector
	hud.topBar = topBar
	hud.bottomBar = bottomBar

	return hud
end

return HUD
