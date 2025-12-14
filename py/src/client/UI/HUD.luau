local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UITheme = require(script.Parent.UITheme)

local HUD = {}
local COLORS = UITheme.COLORS
local ENEMY_ICONS = UITheme.ENEMY_ICONS
local ENEMY_COLORS = UITheme.ENEMY_COLORS
local ENEMY_SIZES = UITheme.ENEMY_SIZES

function HUD.create(parent, callbacks)
	local hud = {
		callbacks = callbacks or {},
		selection = nil, -- Currently selected unit data
	}

	--=========================================================================
	-- 1. ACTION BAR (Dirac Style - Glass + Price Tags)
	--=========================================================================
	local actionBar = Instance.new("Frame")
	actionBar.Name = "ActionBar"
	actionBar.Size = UDim2.new(0, 394, 0, 70)  -- 7 buttons (0-6) + padding
	actionBar.AnchorPoint = Vector2.new(0.5, 1)
	actionBar.Position = UDim2.new(0.5, 0, 1, -8)
	actionBar.BackgroundColor3 = COLORS.bg
	actionBar.BackgroundTransparency = 0.15
	actionBar.BorderSizePixel = 0
	actionBar.Parent = parent

	local actionBarCorner = Instance.new("UICorner")
	actionBarCorner.CornerRadius = UDim.new(0, 8)
	actionBarCorner.Parent = actionBar

	-- Glass edge
	local actionBarStroke = Instance.new("UIStroke")
	actionBarStroke.Color = COLORS.glass
	actionBarStroke.Transparency = 0.8
	actionBarStroke.Thickness = 1
	actionBarStroke.Parent = actionBar

	-- Action Buttons Container
	local actionContainer = Instance.new("Frame")
	actionContainer.Name = "ActionContainer"
	actionContainer.Size = UDim2.new(1, -12, 0, 48)
	actionContainer.Position = UDim2.new(0, 6, 0, 4)
	actionContainer.BackgroundTransparency = 1
	actionContainer.Parent = actionBar

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 4)
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Parent = actionContainer

	-- Helper to create Action Buttons with integrated price tags
	local function createActionSlot(hotkey, icon, tooltip, color, cost)
		local btn = Instance.new("TextButton")
		btn.Name = "Action" .. hotkey
		btn.Size = UDim2.new(0, 50, 0, 46)
		btn.BackgroundColor3 = COLORS.bg
		btn.BackgroundTransparency = 0.3
		btn.Text = ""
		btn.AutoButtonColor = false  -- We handle hover ourselves
		btn.Parent = actionContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = btn

		-- Icon
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "Icon"
		iconLabel.Size = UDim2.new(1, 0, 0, 22)
		iconLabel.Position = UDim2.new(0, 0, 0, 2)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = icon
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.TextSize = 18
		iconLabel.TextColor3 = color
		iconLabel.Parent = btn

		-- Hotkey badge (top-left corner)
		local hotkeyBadge = Instance.new("Frame")
		hotkeyBadge.Name = "HotkeyBadge"
		hotkeyBadge.Size = UDim2.new(0, 14, 0, 14)
		hotkeyBadge.Position = UDim2.new(0, 2, 0, 2)
		hotkeyBadge.BackgroundColor3 = color
		hotkeyBadge.BackgroundTransparency = 0.7
		hotkeyBadge.Parent = btn

		local hbCorner = Instance.new("UICorner")
		hbCorner.CornerRadius = UDim.new(0, 3)
		hbCorner.Parent = hotkeyBadge

		local hotkeyLabel = Instance.new("TextLabel")
		hotkeyLabel.Name = "Hotkey"
		hotkeyLabel.Size = UDim2.new(1, 0, 1, 0)
		hotkeyLabel.BackgroundTransparency = 1
		hotkeyLabel.Text = hotkey
		hotkeyLabel.TextColor3 = COLORS.text
		hotkeyLabel.Font = Enum.Font.Code
		hotkeyLabel.TextSize = 10
		hotkeyLabel.Parent = hotkeyBadge

		-- Price tag (bottom, only for items with cost)
		if cost then
			local priceTag = Instance.new("Frame")
			priceTag.Name = "PriceTag"
			priceTag.Size = UDim2.new(1, -4, 0, 14)
			priceTag.Position = UDim2.new(0, 2, 1, -16)
			priceTag.BackgroundColor3 = COLORS.bg
			priceTag.BackgroundTransparency = 0.5
			priceTag.Parent = btn

			local ptCorner = Instance.new("UICorner")
			ptCorner.CornerRadius = UDim.new(0, 3)
			ptCorner.Parent = priceTag

			local priceLabel = Instance.new("TextLabel")
			priceLabel.Name = "Price"
			priceLabel.Size = UDim2.new(1, 0, 1, 0)
			priceLabel.BackgroundTransparency = 1
			priceLabel.Text = tostring(cost)
			priceLabel.Font = Enum.Font.Code
			priceLabel.TextSize = 10
			priceLabel.TextColor3 = COLORS.success  -- Green = affordable
			priceLabel.Parent = priceTag

			btn:SetAttribute("BaseCost", cost)
			btn:SetAttribute("BaseColor", color:ToHex())
		end

		-- Hover effect
		btn.MouseEnter:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.15), {
				Thickness = 3,
				Transparency = 0
			}):Play()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.1
			}):Play()
		end)

		btn.MouseLeave:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.15), {
				Thickness = 2,
				Transparency = 0.3
			}):Play()
			TweenService:Create(btn, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.3
			}):Play()
		end)

		-- Click depression effect
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.05), {
				Size = UDim2.new(0, 48, 0, 44)
			}):Play()
		end)

		btn.MouseButton1Up:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 50, 0, 46)
			}):Play()
		end)

		return btn, stroke
	end

	local AMMO_COLORS = UITheme.AMMO_COLORS

	-- Actions: 0=Passive, 1=Bullet, 2=Rocket, 3=Laser, 4=Grenade, 5=Bot, 6=Turret
	local passiveBtn, passiveStroke = createActionSlot("0", "○", "Passive", AMMO_COLORS.passive, nil)
	local bulletBtn, bulletStroke = createActionSlot("1", "•", "Bullet", AMMO_COLORS.bullet, nil)
	local rocketBtn, rocketStroke = createActionSlot("2", "◆", "Rocket", AMMO_COLORS.rocket, nil)
	local laserBtn, laserStroke = createActionSlot("3", "━", "Laser", AMMO_COLORS.laser, nil)
	local grenadeBtn, grenadeStroke = createActionSlot("4", "●", "Grenade", AMMO_COLORS.grenade, nil)
	local botBtn, botStroke = createActionSlot("5", "⚙", "Bot", COLORS.warning, 75)
	local turretBtn, turretStroke = createActionSlot("6", "◎", "Turret", COLORS.accent, 100)

	-- Button callbacks (0=passive, 1-4: load weapon programs, 5-6: build)
	passiveBtn.MouseButton1Click:Connect(function()
		if callbacks.onLoadWeapon then callbacks.onLoadWeapon(0) end
	end)

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

	local passiveOverlay = createCooldownOverlay(passiveBtn)
	local bulletOverlay = createCooldownOverlay(bulletBtn)
	local rocketOverlay = createCooldownOverlay(rocketBtn)
	local laserOverlay = createCooldownOverlay(laserBtn)
	local grenadeOverlay = createCooldownOverlay(grenadeBtn)

	-- Track current weapon and reload state
	-- Index 0=passive, 1=bullet, 2=rocket, 3=laser, 4=grenade
	local currentWeapon = 1
	local isReloading = false
	-- Use index 0 for passive, so we store buttons/overlays with [0] key
	local weaponButtons = {[0] = passiveBtn, [1] = bulletBtn, [2] = rocketBtn, [3] = laserBtn, [4] = grenadeBtn}
	local weaponOverlays = {[0] = passiveOverlay, [1] = bulletOverlay, [2] = rocketOverlay, [3] = laserOverlay, [4] = grenadeOverlay}

	-- Highlight active weapon
	local function highlightWeapon(weaponIndex)
		for i, btn in pairs(weaponButtons) do
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
		for _, overlay in pairs(weaponOverlays) do
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
		for _, overlay in pairs(weaponOverlays) do
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
				for _, ov in pairs(weaponOverlays) do
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
	-- 5b. WAVE INFO (Below Scrap) - Shows wave number and enemies remaining
	--=========================================================================
	local waveDisplay = Instance.new("Frame")
	waveDisplay.Name = "WaveDisplay"
	waveDisplay.Size = UDim2.new(0, 160, 0, 40)
	waveDisplay.Position = UDim2.new(0, 15, 0, 98)
	waveDisplay.BackgroundColor3 = COLORS.panel
	waveDisplay.Parent = parent

	local waveCorner = Instance.new("UICorner")
	waveCorner.CornerRadius = UDim.new(0, 8)
	waveCorner.Parent = waveDisplay

	local waveTitle = Instance.new("TextLabel")
	waveTitle.Name = "Title"
	waveTitle.Size = UDim2.new(1, -10, 0, 18)
	waveTitle.Position = UDim2.new(0, 5, 0, 4)
	waveTitle.BackgroundTransparency = 1
	waveTitle.Text = "WAVE 1"
	waveTitle.TextColor3 = COLORS.accent
	waveTitle.Font = Enum.Font.GothamBold
	waveTitle.TextSize = 14
	waveTitle.TextXAlignment = Enum.TextXAlignment.Left
	waveTitle.Parent = waveDisplay

	local enemyCount = Instance.new("TextLabel")
	enemyCount.Name = "EnemyCount"
	enemyCount.Size = UDim2.new(1, -10, 0, 14)
	enemyCount.Position = UDim2.new(0, 5, 0, 22)
	enemyCount.BackgroundTransparency = 1
	enemyCount.Text = "0 / 0"
	enemyCount.TextColor3 = COLORS.danger
	enemyCount.Font = Enum.Font.Gotham
	enemyCount.TextSize = 12
	enemyCount.TextXAlignment = Enum.TextXAlignment.Left
	enemyCount.Parent = waveDisplay

	--=========================================================================
	-- 6. READY BUTTON (Only visible in LOBBY)
	--=========================================================================
	local waveActionBtn = Instance.new("TextButton")
	waveActionBtn.Name = "WaveActionBtn"
	waveActionBtn.Size = UDim2.new(0, 160, 0, 35)
	waveActionBtn.Position = UDim2.new(0, 15, 0, 143)
	waveActionBtn.BackgroundColor3 = COLORS.accent
	waveActionBtn.Text = "START"
	waveActionBtn.TextColor3 = COLORS.bg
	waveActionBtn.Font = Enum.Font.GothamBold
	waveActionBtn.TextSize = 14
	waveActionBtn.AutoButtonColor = true
	waveActionBtn.Parent = parent

	local waveActionCorner = Instance.new("UICorner")
	waveActionCorner.CornerRadius = UDim.new(0, 8)
	waveActionCorner.Parent = waveActionBtn

	local currentPhase = "LOBBY"

	waveActionBtn.MouseButton1Click:Connect(function()
		if currentPhase == "LOBBY" then
			if callbacks.onReady then callbacks.onReady() end
		end
	end)

	--=========================================================================
	-- 8. BOT PARTY FRAME (Quick bot selection - right side)
	--=========================================================================
	local partyFrame = Instance.new("Frame")
	partyFrame.Name = "PartyFrame"
	partyFrame.Size = UDim2.new(0, 60, 0, 220)
	partyFrame.Position = UDim2.new(0, 15, 0, 190)
	partyFrame.BackgroundColor3 = COLORS.panel
	partyFrame.BackgroundTransparency = 0.3
	partyFrame.Parent = parent

	local partyCorner = Instance.new("UICorner")
	partyCorner.CornerRadius = UDim.new(0, 8)
	partyCorner.Parent = partyFrame

	local partyStroke = Instance.new("UIStroke")
	partyStroke.Color = COLORS.glass
	partyStroke.Transparency = 0.8
	partyStroke.Thickness = 1
	partyStroke.Parent = partyFrame

	local partyLabel = Instance.new("TextLabel")
	partyLabel.Size = UDim2.new(1, 0, 0, 16)
	partyLabel.Position = UDim2.new(0, 0, 0, 2)
	partyLabel.BackgroundTransparency = 1
	partyLabel.Text = "BOTS"
	partyLabel.TextColor3 = COLORS.subtext
	partyLabel.Font = Enum.Font.GothamBold
	partyLabel.TextSize = 9
	partyLabel.Parent = partyFrame

	local botSlots = {}
	local BOT_COLORS = UITheme.BOT_COLORS

	for i = 1, 4 do
		local slot = Instance.new("TextButton")
		slot.Name = "BotSlot" .. i
		slot.Size = UDim2.new(0, 50, 0, 46)
		slot.Position = UDim2.new(0, 5, 0, 18 + (i - 1) * 50)
		slot.BackgroundColor3 = COLORS.bg
		slot.BackgroundTransparency = 0.5
		slot.Text = ""
		slot.AutoButtonColor = true
		slot.Parent = partyFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slot

		-- Bot number label
		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "Number"
		numLabel.Size = UDim2.new(1, 0, 0, 14)
		numLabel.Position = UDim2.new(0, 0, 0, 2)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = "B" .. i
		numLabel.TextColor3 = BOT_COLORS[i]
		numLabel.Font = Enum.Font.GothamBold
		numLabel.TextSize = 11
		numLabel.Parent = slot

		-- Status icon (shows cargo or status)
		local statusIcon = Instance.new("TextLabel")
		statusIcon.Name = "Status"
		statusIcon.Size = UDim2.new(1, 0, 0, 16)
		statusIcon.Position = UDim2.new(0, 0, 0, 16)
		statusIcon.BackgroundTransparency = 1
		statusIcon.Text = "—"
		statusIcon.TextColor3 = COLORS.subtext
		statusIcon.Font = Enum.Font.Gotham
		statusIcon.TextSize = 10
		statusIcon.Parent = slot

		-- Cargo indicator (small bar at bottom)
		local cargoBar = Instance.new("Frame")
		cargoBar.Name = "CargoBar"
		cargoBar.Size = UDim2.new(0.8, 0, 0, 4)
		cargoBar.Position = UDim2.new(0.1, 0, 1, -8)
		cargoBar.BackgroundColor3 = COLORS.bg
		cargoBar.Parent = slot

		local cargoBarCorner = Instance.new("UICorner")
		cargoBarCorner.CornerRadius = UDim.new(0, 2)
		cargoBarCorner.Parent = cargoBar

		local cargoFill = Instance.new("Frame")
		cargoFill.Name = "Fill"
		cargoFill.Size = UDim2.new(0, 0, 1, 0)
		cargoFill.BackgroundColor3 = COLORS.warning
		cargoFill.Parent = cargoBar

		local cargoFillCorner = Instance.new("UICorner")
		cargoFillCorner.CornerRadius = UDim.new(0, 2)
		cargoFillCorner.Parent = cargoFill

		-- Click handler
		slot.MouseButton1Click:Connect(function()
			if callbacks.onBotSelect then
				callbacks.onBotSelect(i)
			end
		end)

		botSlots[i] = {
			frame = slot,
			number = numLabel,
			status = statusIcon,
			cargoBar = cargoBar,
			cargoFill = cargoFill,
			exists = false,
		}
	end

	-- Update a single bot slot
	-- botData: { exists, status, cargo, maxCargo }
	function hud.updateBotSlot(slotNum, botData)
		local slot = botSlots[slotNum]
		if not slot then return end

		if botData and botData.exists then
			slot.exists = true
			slot.frame.BackgroundTransparency = 0.2
			slot.number.TextColor3 = BOT_COLORS[slotNum]

			-- Update status
			local statusText = botData.status or "IDLE"
			if statusText == "COLLECTING" then
				slot.status.Text = "📦"
			elseif statusText == "MOVING" then
				slot.status.Text = "→"
			elseif statusText == "STUNNED" then
				slot.status.Text = "⚡"
			elseif statusText == "WAITING" then
				slot.status.Text = "⏳"
			else
				slot.status.Text = "●"
			end
			slot.status.TextColor3 = COLORS.text

			-- Update cargo bar
			local cargo = botData.cargo or 0
			local maxCargo = botData.maxCargo or 50
			local ratio = math.clamp(cargo / maxCargo, 0, 1)
			slot.cargoFill.Size = UDim2.new(ratio, 0, 1, 0)
			slot.cargoBar.Visible = true
		else
			slot.exists = false
			slot.frame.BackgroundTransparency = 0.7
			slot.number.TextColor3 = COLORS.subtext
			slot.status.Text = "—"
			slot.status.TextColor3 = COLORS.subtext
			slot.cargoBar.Visible = false
		end
	end

	-- Update all bot slots from botStates table
	function hud.updateBotParty(botStates)
		for i = 1, 4 do
			local botData = nil
			-- Find bot with spotId == i
			for _, bot in pairs(botStates or {}) do
				if bot.spotId == i then
					botData = {
						exists = true,
						status = bot.status,
						cargo = bot.scrapInventory or 0,
						maxCargo = 50,
					}
					break
				end
			end
			hud.updateBotSlot(i, botData)
		end
	end

	-- Expose party frame
	hud.partyFrame = partyFrame

	--=========================================================================
	-- PUBLIC FUNCTIONS
	--=========================================================================

	function hud.updateWave(waveNum, remaining, total)
		waveTitle.Text = "WAVE " .. (waveNum or 0)
		if total and total > 0 then
			enemyCount.Text = (remaining or 0) .. " / " .. total .. " remaining"
		else
			enemyCount.Text = ""
		end
	end

	function hud.updateEconomy(scrap, turretCost, botCost)
		scrapText.Text = "SCRAP: " .. (scrap or 0)
		local currentScrap = scrap or 0

		-- Update price tags on buttons
		local turretPrice = turretBtn:FindFirstChild("PriceTag")
		local botPrice = botBtn:FindFirstChild("PriceTag")

		if turretPrice then
			local label = turretPrice:FindFirstChild("Price")
			if label then
				label.Text = tostring(turretCost or 100)
			end
		end

		if botPrice then
			local label = botPrice:FindFirstChild("Price")
			if label then
				label.Text = tostring(botCost or 75)
			end
		end

		-- Update button affordability visuals
		local canAffordTurret = currentScrap >= (turretCost or 100)
		local canAffordBot = currentScrap >= (botCost or 75)

		-- Turret button affordability
		if canAffordTurret then
			turretStroke.Color = COLORS.accent
			turretStroke.Transparency = 0.3
			if turretPrice then
				local label = turretPrice:FindFirstChild("Price")
				if label then label.TextColor3 = COLORS.success end
			end
		else
			turretStroke.Color = COLORS.subtext
			turretStroke.Transparency = 0.6
			if turretPrice then
				local label = turretPrice:FindFirstChild("Price")
				if label then label.TextColor3 = COLORS.danger end
			end
		end

		-- Bot button affordability
		if canAffordBot then
			botStroke.Color = COLORS.warning
			botStroke.Transparency = 0.3
			if botPrice then
				local label = botPrice:FindFirstChild("Price")
				if label then label.TextColor3 = COLORS.success end
			end
		else
			botStroke.Color = COLORS.subtext
			botStroke.Transparency = 0.6
			if botPrice then
				local label = botPrice:FindFirstChild("Price")
				if label then label.TextColor3 = COLORS.danger end
			end
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

	function hud.updatePhase(phaseName)
		currentPhase = phaseName or "LOBBY"

		if phaseName == "COMBAT" then
			waveActionBtn.Visible = false
		elseif phaseName == "LOBBY" then
			waveActionBtn.Visible = true
		else
			waveActionBtn.Visible = false
		end
	end

	function hud.select(objData)
		hud.selection = objData
	end

	function hud.deselect()
		hud.selection = nil
	end

	hud.actionBar = actionBar

	return hud
end

return HUD
