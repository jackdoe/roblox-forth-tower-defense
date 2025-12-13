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
	-- 3. SELECTION INSPECTOR (Bottom Left Panel)
	--=========================================================================
	local inspector = Instance.new("Frame")
	inspector.Name = "Inspector"
	inspector.Size = UDim2.new(0, 180, 0, 210)  -- Taller to fit ammo buttons
	inspector.Position = UDim2.new(0, 15, 1, -225)
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
		btn.Font = Enum.Font.Gotham  -- Regular font, no bold
		btn.TextSize = 10
		btn.Parent = actionContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		-- No stroke - cleaner look

		btn.MouseButton1Click:Connect(function()
			if callback then callback() end
		end)

		return btn
	end

	-- CODE button removed - clicking unit auto-enters mind mode
	-- MOVE button removed - not needed

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
	-- 3b. AMMO TYPE SELECTOR (for turrets)
	--=========================================================================
	local ammoContainer = Instance.new("Frame")
	ammoContainer.Name = "AmmoSelector"
	ammoContainer.Size = UDim2.new(1, -20, 0, 50)
	ammoContainer.Position = UDim2.new(0, 10, 0, 95)
	ammoContainer.BackgroundTransparency = 1
	ammoContainer.Visible = false  -- Only visible for turrets
	ammoContainer.Parent = inspector

	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Size = UDim2.new(1, 0, 0, 14)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = "AMMO TYPE"
	ammoLabel.TextColor3 = COLORS.subtext
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Left
	ammoLabel.Font = Enum.Font.Gotham
	ammoLabel.TextSize = 9
	ammoLabel.Parent = ammoContainer

	local ammoButtonFrame = Instance.new("Frame")
	ammoButtonFrame.Size = UDim2.new(1, 0, 0, 32)
	ammoButtonFrame.Position = UDim2.new(0, 0, 0, 16)
	ammoButtonFrame.BackgroundTransparency = 1
	ammoButtonFrame.Parent = ammoContainer

	local ammoLayout = Instance.new("UIListLayout")
	ammoLayout.FillDirection = Enum.FillDirection.Horizontal
	ammoLayout.Padding = UDim.new(0, 4)
	ammoLayout.Parent = ammoButtonFrame

	-- Ammo type definitions
	local AMMO_TYPES = {
		{id = 1, name = "●", fullName = "BULLET", color = Color3.fromRGB(255, 220, 100)},
		{id = 2, name = "◆", fullName = "ROCKET", color = Color3.fromRGB(255, 100, 80)},
		{id = 4, name = "❄", fullName = "ICE", color = Color3.fromRGB(100, 200, 255)},
		{id = 5, name = "✱", fullName = "GRENADE", color = Color3.fromRGB(100, 255, 100)},
	}

	local ammoButtons = {}
	local selectedAmmoType = 1  -- Default to BULLET

	for _, ammoInfo in ipairs(AMMO_TYPES) do
		local ammoBtn = Instance.new("TextButton")
		ammoBtn.Name = "Ammo_" .. ammoInfo.id
		ammoBtn.Size = UDim2.new(0, 36, 0, 32)
		ammoBtn.BackgroundColor3 = COLORS.bg
		ammoBtn.Text = ammoInfo.name
		ammoBtn.TextColor3 = ammoInfo.color
		ammoBtn.Font = Enum.Font.GothamBold
		ammoBtn.TextSize = 16
		ammoBtn.Parent = ammoButtonFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 4)
		btnCorner.Parent = ammoBtn

		-- Border to show selection
		local btnBorder = Instance.new("UIStroke")
		btnBorder.Name = "Border"
		btnBorder.Color = ammoInfo.color
		btnBorder.Thickness = 0  -- Hidden by default
		btnBorder.Parent = ammoBtn

		ammoBtn.MouseButton1Click:Connect(function()
			if hud.selection and hud.selection.type == "golem" then
				-- Check if this ammo type is unlocked
				local unlocked = hud.selection.unlockedAmmo or {1}
				local isUnlocked = false
				for _, aType in ipairs(unlocked) do
					if aType == ammoInfo.id then
						isUnlocked = true
						break
					end
				end

				if isUnlocked then
					selectedAmmoType = ammoInfo.id
					-- Update visuals
					for id, btn in pairs(ammoButtons) do
						local border = btn:FindFirstChild("Border")
						if border then
							border.Thickness = (id == selectedAmmoType) and 2 or 0
						end
					end
					-- Call callback to change turret program
					if callbacks.onAmmoChange then
						callbacks.onAmmoChange(hud.selection.id, ammoInfo.id, ammoInfo.fullName)
					end
				end
			end
		end)

		ammoButtons[ammoInfo.id] = ammoBtn
	end

	-- Function to update ammo button availability based on unlocked ammo
	local function updateAmmoButtons(unlockedAmmo)
		unlockedAmmo = unlockedAmmo or {1}
		for _, ammoInfo in ipairs(AMMO_TYPES) do
			local btn = ammoButtons[ammoInfo.id]
			if btn then
				local isUnlocked = false
				for _, aType in ipairs(unlockedAmmo) do
					if aType == ammoInfo.id then
						isUnlocked = true
						break
					end
				end
				-- Gray out locked ammo types
				if isUnlocked then
					btn.TextTransparency = 0
					btn.BackgroundColor3 = COLORS.bg
				else
					btn.TextTransparency = 0.7
					btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
				end
				-- Show selection border
				local border = btn:FindFirstChild("Border")
				if border then
					border.Thickness = (ammoInfo.id == selectedAmmoType and isUnlocked) and 2 or 0
				end
			end
		end
	end

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
	-- 5b. NEXT WAVE INFO (Below Scrap)
	--=========================================================================
	local nextWaveDisplay = Instance.new("Frame")
	nextWaveDisplay.Name = "NextWaveDisplay"
	nextWaveDisplay.Size = UDim2.new(0, 160, 0, 40)
	nextWaveDisplay.Position = UDim2.new(0, 15, 0, 98)
	nextWaveDisplay.BackgroundColor3 = COLORS.panel
	nextWaveDisplay.Parent = parent

	local nextWaveCorner = Instance.new("UICorner")
	nextWaveCorner.CornerRadius = UDim.new(0, 8)
	nextWaveCorner.Parent = nextWaveDisplay

	local nextWaveTitle = Instance.new("TextLabel")
	nextWaveTitle.Name = "Title"
	nextWaveTitle.Size = UDim2.new(1, -10, 0, 14)
	nextWaveTitle.Position = UDim2.new(0, 5, 0, 4)
	nextWaveTitle.BackgroundTransparency = 1
	nextWaveTitle.Text = "NEXT WAVE:"
	nextWaveTitle.TextColor3 = COLORS.subtext
	nextWaveTitle.Font = Enum.Font.Gotham
	nextWaveTitle.TextSize = 9
	nextWaveTitle.TextXAlignment = Enum.TextXAlignment.Left
	nextWaveTitle.Parent = nextWaveDisplay

	-- Container for enemy type icons
	local nextWaveIcons = Instance.new("Frame")
	nextWaveIcons.Name = "Icons"
	nextWaveIcons.Size = UDim2.new(1, -10, 0, 18)
	nextWaveIcons.Position = UDim2.new(0, 5, 0, 18)
	nextWaveIcons.BackgroundTransparency = 1
	nextWaveIcons.Parent = nextWaveDisplay

	local nextWaveLayout = Instance.new("UIListLayout")
	nextWaveLayout.FillDirection = Enum.FillDirection.Horizontal
	nextWaveLayout.Padding = UDim.new(0, 4)
	nextWaveLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	nextWaveLayout.Parent = nextWaveIcons

	--=========================================================================
	-- 6. PHASE INDICATOR (Top Left, below Next Wave)
	--=========================================================================
	local phaseDisplay = Instance.new("Frame")
	phaseDisplay.Name = "PhaseDisplay"
	phaseDisplay.Size = UDim2.new(0, 160, 0, 35)
	phaseDisplay.Position = UDim2.new(0, 15, 0, 143)
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
	waveActionBtn.Position = UDim2.new(0, 15, 0, 183)
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
	-- 8. BOT PARTY FRAME (Quick bot selection - right side)
	--=========================================================================
	local partyFrame = Instance.new("Frame")
	partyFrame.Name = "PartyFrame"
	partyFrame.Size = UDim2.new(0, 60, 0, 220)  -- 4 bot slots stacked vertically
	partyFrame.Position = UDim2.new(1, -75, 0.5, -110)  -- Right side, centered
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

	local currentWaveNum = 1

	-- Update wave number
	function hud.updateWave(waveNum, previewList)
		currentWaveNum = waveNum or 1
	end

	function hud.updateNextWave(waveNum, preview)
		nextWaveTitle.Text = "WAVE " .. (waveNum or "?") .. ":"

		-- Clear old icons
		for _, child in ipairs(nextWaveIcons:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		-- Add icons for each enemy type
		if preview then
			for typeName, count in pairs(preview) do
				local icon = ENEMY_ICONS[typeName] or "●"
				local color = ENEMY_COLORS[typeName] or COLORS.subtext

				local iconFrame = Instance.new("Frame")
				iconFrame.Name = typeName
				iconFrame.Size = UDim2.new(0, 36, 0, 18)
				iconFrame.BackgroundTransparency = 1
				iconFrame.Parent = nextWaveIcons

				local iconLabel = Instance.new("TextLabel")
				iconLabel.Size = UDim2.new(0, 14, 1, 0)
				iconLabel.BackgroundTransparency = 1
				iconLabel.Text = icon
				iconLabel.TextColor3 = color
				iconLabel.Font = Enum.Font.GothamBold
				iconLabel.TextSize = 12
				iconLabel.Parent = iconFrame

				local countLabel = Instance.new("TextLabel")
				countLabel.Size = UDim2.new(0, 20, 1, 0)
				countLabel.Position = UDim2.new(0, 14, 0, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "x" .. count
				countLabel.TextColor3 = COLORS.text
				countLabel.Font = Enum.Font.Gotham
				countLabel.TextSize = 10
				countLabel.TextXAlignment = Enum.TextXAlignment.Left
				countLabel.Parent = iconFrame
			end
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
		hud.selection = objData -- {id, type, spotId, ammo, maxAmmo, dynamicRange, status, tier, tierName, upgradeCost, unlockedAmmo}

		if not objData then
			inspector.Visible = false
			return
		end

		inspector.Visible = true

		-- Update title and buttons based on type
		if objData.type == "golem" then
			local tier = objData.tier or 1
			local ramAmount = objData.maxBytecode or 64
			inspectTitle.Text = "TURRET #" .. (objData.spotId or "?") .. " [" .. ramAmount .. " RAM]"
			inspectTitle.TextColor3 = tier == 3 and Color3.fromRGB(255, 220, 50) or   -- Hazard Yellow for Dreadnought
			                          tier == 2 and Color3.fromRGB(255, 150, 0) or    -- Industrial Orange for Arachnid
			                          COLORS.accent

			-- Show UPGRADE button with cost if not at max tier
			-- Upgrades now give more RAM (bytecode limit)
			if objData.upgradeCost then
				upgradeBtn.Visible = true
				upgradeBtn.Text = "UPGRADE (" .. objData.upgradeCost .. ") → " .. (ramAmount * 2) .. " RAM"
			else
				upgradeBtn.Visible = false  -- At max tier
			end

			-- Ammo selector removed - turrets are now fully programmable
			ammoContainer.Visible = false

		elseif objData.type == "bot" then
			inspectTitle.Text = "BOT #" .. (objData.spotId or "?")
			inspectTitle.TextColor3 = COLORS.warning
			upgradeBtn.Visible = false  -- Bots can't be upgraded
			ammoContainer.Visible = false  -- Bots don't have ammo types
		else
			inspectTitle.Text = "UNIT"
			inspectTitle.TextColor3 = COLORS.text
			upgradeBtn.Visible = false
			ammoContainer.Visible = false
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
	hud.actionBar = actionBar

	return hud
end

return HUD
