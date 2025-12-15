local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UITheme = require(script.Parent.UITheme)

local HUD = {}
local COLORS = UITheme.COLORS

function HUD.create(parent, callbacks)
	local hud = {
		callbacks = callbacks or {},
		selection = nil,
	}

	local buildBar = Instance.new("Frame")
	buildBar.Name = "BuildBar"
	buildBar.Size = UDim2.new(0, 320, 0, 32)
	buildBar.Position = UDim2.new(0.5, -160, 0, 8)
	buildBar.BackgroundColor3 = Color3.fromHex("#1a1a1a")
	buildBar.BackgroundTransparency = 0.3
	buildBar.Parent = parent
	Instance.new("UICorner", buildBar).CornerRadius = UDim.new(0, 6)

	local buildLayout = Instance.new("UIListLayout")
	buildLayout.FillDirection = Enum.FillDirection.Horizontal
	buildLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buildLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buildLayout.Padding = UDim.new(0, 8)
	buildLayout.Parent = buildBar

	local botBtn = Instance.new("TextButton")
	botBtn.Name = "BotBtn"
	botBtn.Size = UDim2.new(0, 145, 0, 24)
	botBtn.BackgroundColor3 = Color3.fromHex("#333333")
	botBtn.Text = "+ROBOT (B): 75"
	botBtn.TextColor3 = Color3.fromRGB(215, 135, 70)
	botBtn.Font = Enum.Font.RobotoMono
	botBtn.TextSize = 11
	botBtn.Parent = buildBar
	Instance.new("UICorner", botBtn).CornerRadius = UDim.new(0, 4)

	local turretBtn = Instance.new("TextButton")
	turretBtn.Name = "TurretBtn"
	turretBtn.Size = UDim2.new(0, 145, 0, 24)
	turretBtn.BackgroundColor3 = Color3.fromHex("#333333")
	turretBtn.Text = "+TURRET (T): 100"
	turretBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
	turretBtn.Font = Enum.Font.RobotoMono
	turretBtn.TextSize = 11
	turretBtn.Parent = buildBar
	Instance.new("UICorner", turretBtn).CornerRadius = UDim.new(0, 4)

	botBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuildBot then callbacks.onBuildBot() end
	end)

	turretBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuildTurret then callbacks.onBuildTurret() end
	end)

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
	scrapText.Text = "SCRAP: 0"
	scrapText.TextColor3 = COLORS.warning
	scrapText.Font = Enum.Font.GothamBold
	scrapText.TextSize = 14
	scrapText.TextXAlignment = Enum.TextXAlignment.Left
	scrapText.Parent = scrapDisplay

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
		botBtn.Text = string.format("+ROBOT (B): %d", botCost or 75)
		turretBtn.Text = string.format("+TURRET (T): %d", turretCost or 100)
	end

	function hud.updateCore(hp, maxHp)
		coreHP.Text = (hp or 0) .. " / " .. (maxHp or 1000)

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

	function hud.updateBotSlot(slotNum, botData)
	end

	function hud.updateBotParty(botStates)
	end

	function hud.updateCargo(amount, maxAmount)
	end

	function hud.triggerGlobalCooldown(duration)
	end

	function hud.triggerReloadCooldown(duration, weaponIndex)
	end

	function hud.highlightWeapon(weaponIndex)
	end

	function hud.isReloading()
		return false
	end

	function hud.getCurrentWeapon()
		return 1
	end

	function hud.setCurrentWeapon(w)
	end

	return hud
end

return HUD
