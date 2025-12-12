-- PlayerHpBillboard.luau
-- Billboard GUI showing player HP above their character

local PlayerHpBillboard = {}

function PlayerHpBillboard.create(character)
	local billboard = {}

	local head = character:WaitForChild("Head", 5)
	if not head then return nil end

	local gui = Instance.new("BillboardGui")
	gui.Name = "PlayerHpBillboard"
	gui.Size = UDim2.new(0, 80, 0, 20)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.Adornee = head
	gui.AlwaysOnTop = false
	gui.MaxDistance = 50
	gui.Parent = head

	-- HP text
	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.Size = UDim2.new(1, 0, 0, 10)
	hpLabel.Position = UDim2.new(0, 0, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Text = "100/100"
	hpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	hpLabel.TextStrokeTransparency = 0.5
	hpLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.TextSize = 9
	hpLabel.Parent = gui

	-- HP bar background
	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(1, 0, 0, 6)
	hpBg.Position = UDim2.new(0, 0, 0, 11)
	hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = gui

	local hpBgCorner = Instance.new("UICorner")
	hpBgCorner.CornerRadius = UDim.new(0, 3)
	hpBgCorner.Parent = hpBg

	-- Health bar fill
	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = hpBg

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 3)
	healthCorner.Parent = healthBar

	billboard.gui = gui
	billboard.healthBar = healthBar
	billboard.hpLabel = hpLabel

	function billboard:update(hp, maxHp)
		local hpPct = math.clamp(hp / maxHp, 0, 1)
		healthBar.Size = UDim2.new(hpPct, 0, 1, 0)
		hpLabel.Text = math.floor(hp) .. "/" .. math.floor(maxHp)

		if hpPct > 0.5 then
			healthBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		elseif hpPct > 0.25 then
			healthBar.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
		else
			healthBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
		end
	end

	function billboard:destroy()
		gui:Destroy()
	end

	return billboard
end

return PlayerHpBillboard
