-- UnitListPanel.luau
-- Grid panel for Turrets (2x4) and Bots (2x2)
-- Compact design with no headers

local Players = game:GetService("Players")

local UnitListPanel = {}

function UnitListPanel.create(parent, callbacks)
	local panel = {}
	callbacks = callbacks or {}

	local modelCache = {}

	-- // CONFIGURATION //
	local ITEM_WIDTH = 90
	local ITEM_HEIGHT = 50
	local PADDING = 4
	local COLUMNS = 2

	-- Calculate panel height based on grid: 4 rows turrets + 2 rows bots
	local TURRET_ROWS = 4
	local BOT_ROWS = 2
	local PANEL_HEIGHT = (TURRET_ROWS + BOT_ROWS) * ITEM_HEIGHT + PADDING * 7

	-- Main Container - positioned to the RIGHT of the wave panel (x=220, bottom aligned)
	local frame = Instance.new("Frame")
	frame.Name = "UnitListPanel"
	frame.Size = UDim2.new(0, ITEM_WIDTH * COLUMNS + PADDING * 3, 0, PANEL_HEIGHT)
	frame.Position = UDim2.new(0, 220, 1, -PANEL_HEIGHT - 10)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.5
	frame.Visible = false
	frame.Parent = parent

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = frame

	-- Turrets Grid (2x4)
	local TURRET_GRID_HEIGHT = ITEM_HEIGHT * TURRET_ROWS + PADDING * (TURRET_ROWS - 1)
	local turretGrid = Instance.new("Frame")
	turretGrid.Name = "TurretGrid"
	turretGrid.Size = UDim2.new(1, -PADDING * 2, 0, TURRET_GRID_HEIGHT)
	turretGrid.Position = UDim2.new(0, PADDING, 0, PADDING)
	turretGrid.BackgroundTransparency = 1
	turretGrid.Parent = frame

	local turretGridLayout = Instance.new("UIGridLayout")
	turretGridLayout.CellSize = UDim2.new(0, ITEM_WIDTH, 0, ITEM_HEIGHT)
	turretGridLayout.CellPadding = UDim2.new(0, PADDING, 0, PADDING)
	turretGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	turretGridLayout.Parent = turretGrid

	-- Bots Grid (2x2) - positioned below turret grid
	local BOT_GRID_HEIGHT = ITEM_HEIGHT * BOT_ROWS + PADDING * (BOT_ROWS - 1)
	local botGrid = Instance.new("Frame")
	botGrid.Name = "BotGrid"
	botGrid.Size = UDim2.new(1, -PADDING * 2, 0, BOT_GRID_HEIGHT)
	botGrid.Position = UDim2.new(0, PADDING, 0, TURRET_GRID_HEIGHT + PADDING * 2)
	botGrid.BackgroundTransparency = 1
	botGrid.Parent = frame

	local botGridLayout = Instance.new("UIGridLayout")
	botGridLayout.CellSize = UDim2.new(0, ITEM_WIDTH, 0, ITEM_HEIGHT)
	botGridLayout.CellPadding = UDim2.new(0, PADDING, 0, PADDING)
	botGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	botGridLayout.Parent = botGrid

	-- Track rows
	local golemRows = {}
	local botRows = {}

	-- Helper: Find model position
	local function getModelPosition(id, isBot)
		local attrName = isBot and "BotId" or "GolemId"
		if modelCache[id] and modelCache[id].Parent then
			local hrp = modelCache[id]:FindFirstChild("HumanoidRootPart") or modelCache[id].PrimaryPart
			if hrp then return hrp.Position end
		end
		for _, model in ipairs(workspace:GetChildren()) do
			if model:GetAttribute(attrName) == id then
				modelCache[id] = model
				local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
				if hrp then return hrp.Position end
			end
		end
		return nil
	end

	-- Create compact golem cell
	local function createGolemCell(golem, order)
		local btn = Instance.new("ImageButton")
		btn.Name = "Golem_" .. golem.id
		btn.BackgroundColor3 = Color3.fromRGB(40, 35, 25)
		btn.BackgroundTransparency = 0.2
		btn.AutoButtonColor = true
		btn.ImageTransparency = 1
		btn.LayoutOrder = order
		btn.Parent = turretGrid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(80, 60, 40)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		-- ID Label (Top Left)
		local idLabel = Instance.new("TextLabel")
		idLabel.Size = UDim2.new(0, 24, 0, 16)
		idLabel.Position = UDim2.new(0, 4, 0, 2)
		idLabel.BackgroundTransparency = 1
		idLabel.Text = "#" .. (golem.spotId or "?")
		idLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		idLabel.Font = Enum.Font.GothamBold
		idLabel.TextSize = 12
		idLabel.TextXAlignment = Enum.TextXAlignment.Left
		idLabel.Parent = btn

		-- Power indicator (Top Right)
		local powerLabel = Instance.new("TextLabel")
		powerLabel.Size = UDim2.new(0, 40, 0, 14)
		powerLabel.Position = UDim2.new(1, -44, 0, 2)
		powerLabel.BackgroundTransparency = 1
		powerLabel.Text = "1.0x"
		powerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		powerLabel.Font = Enum.Font.Code
		powerLabel.TextSize = 10
		powerLabel.TextXAlignment = Enum.TextXAlignment.Right
		powerLabel.Parent = btn

		-- Ammo Bar (Middle)
		local ammoBg = Instance.new("Frame")
		ammoBg.Size = UDim2.new(1, -8, 0, 6)
		ammoBg.Position = UDim2.new(0, 4, 0, 20)
		ammoBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		ammoBg.BorderSizePixel = 0
		ammoBg.Parent = btn

		local ammoBgCorner = Instance.new("UICorner")
		ammoBgCorner.CornerRadius = UDim.new(0, 2)
		ammoBgCorner.Parent = ammoBg

		local ammoFill = Instance.new("Frame")
		ammoFill.Size = UDim2.new(1, 0, 1, 0)
		ammoFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
		ammoFill.BorderSizePixel = 0
		ammoFill.Parent = ammoBg

		local ammoFillCorner = Instance.new("UICorner")
		ammoFillCorner.CornerRadius = UDim.new(0, 2)
		ammoFillCorner.Parent = ammoFill

		-- Status (Bottom)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(1, -8, 0, 16)
		statusLabel.Position = UDim2.new(0, 4, 1, -18)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = "---"
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		statusLabel.Font = Enum.Font.Code
		statusLabel.TextSize = 9
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if callbacks.onSelectGolem then
				callbacks.onSelectGolem(golem.id)
			end
		end)

		return {
			btn = btn,
			idLabel = idLabel,
			powerLabel = powerLabel,
			ammoFill = ammoFill,
			statusLabel = statusLabel,
			stroke = stroke
		}
	end

	-- Create compact bot cell
	local function createBotCell(bot, order)
		local btn = Instance.new("ImageButton")
		btn.Name = "Bot_" .. bot.id
		btn.BackgroundColor3 = Color3.fromRGB(25, 40, 45)
		btn.BackgroundTransparency = 0.2
		btn.AutoButtonColor = true
		btn.ImageTransparency = 1
		btn.LayoutOrder = order
		btn.Parent = botGrid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(40, 80, 100)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		-- ID Label (Top Left)
		local idLabel = Instance.new("TextLabel")
		idLabel.Size = UDim2.new(0, 24, 0, 16)
		idLabel.Position = UDim2.new(0, 4, 0, 2)
		idLabel.BackgroundTransparency = 1
		idLabel.Text = "B" .. (bot.spotId or "?")
		idLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
		idLabel.Font = Enum.Font.GothamBold
		idLabel.TextSize = 12
		idLabel.TextXAlignment = Enum.TextXAlignment.Left
		idLabel.Parent = btn

		-- Cargo amount (Top Right)
		local cargoLabel = Instance.new("TextLabel")
		cargoLabel.Size = UDim2.new(0, 40, 0, 14)
		cargoLabel.Position = UDim2.new(1, -44, 0, 2)
		cargoLabel.BackgroundTransparency = 1
		cargoLabel.Text = "0"
		cargoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		cargoLabel.Font = Enum.Font.Code
		cargoLabel.TextSize = 10
		cargoLabel.TextXAlignment = Enum.TextXAlignment.Right
		cargoLabel.Parent = btn

		-- Cargo Bar (Middle)
		local cargoBg = Instance.new("Frame")
		cargoBg.Size = UDim2.new(1, -8, 0, 6)
		cargoBg.Position = UDim2.new(0, 4, 0, 20)
		cargoBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		cargoBg.BorderSizePixel = 0
		cargoBg.Parent = btn

		local cargoBgCorner = Instance.new("UICorner")
		cargoBgCorner.CornerRadius = UDim.new(0, 2)
		cargoBgCorner.Parent = cargoBg

		local cargoFill = Instance.new("Frame")
		cargoFill.Size = UDim2.new(0, 0, 1, 0)
		cargoFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		cargoFill.BorderSizePixel = 0
		cargoFill.Parent = cargoBg

		local cargoFillCorner = Instance.new("UICorner")
		cargoFillCorner.CornerRadius = UDim.new(0, 2)
		cargoFillCorner.Parent = cargoFill

		-- Status (Bottom) - shows IDLE/MOVING
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(1, -8, 0, 16)
		statusLabel.Position = UDim2.new(0, 4, 1, -18)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = "IDLE"
		statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		statusLabel.Font = Enum.Font.Code
		statusLabel.TextSize = 9
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if callbacks.onSelectBot then
				callbacks.onSelectBot(bot.id)
			end
		end)

		return {
			btn = btn,
			idLabel = idLabel,
			cargoLabel = cargoLabel,
			cargoFill = cargoFill,
			statusLabel = statusLabel,
			stroke = stroke
		}
	end

	-- Main update function
	function panel:update(golemsData, botsData)
		golemsData = golemsData or {}
		botsData = botsData or {}

		-- Show/hide panel based on content
		if #golemsData == 0 and #botsData == 0 then
			frame.Visible = false
			return
		end
		frame.Visible = true

		-- Sort golems by spotId
		table.sort(golemsData, function(a, b)
			return (a.spotId or 0) < (b.spotId or 0)
		end)

		-- Sort bots by spotId
		table.sort(botsData, function(a, b)
			return (a.spotId or 0) < (b.spotId or 0)
		end)

		local seenGolemIds = {}
		local seenBotIds = {}

		-- === UPDATE TURRETS ===
		for i, golem in ipairs(golemsData) do
			seenGolemIds[golem.id] = true

			local row = golemRows[golem.id]
			if not row then
				row = createGolemCell(golem, i)
				golemRows[golem.id] = row
			else
				row.btn.LayoutOrder = i
			end

			-- Update ID
			row.idLabel.Text = "#" .. (golem.spotId or "?")

			-- Update Ammo Bar
			local max = math.max(1, golem.maxAmmo or 300)
			local ratio = math.clamp((golem.ammo or 0) / max, 0, 1)
			row.ammoFill.Size = UDim2.new(ratio, 0, 1, 0)

			if ratio <= 0 then
				row.ammoFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			elseif ratio < 0.3 then
				row.ammoFill.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
			else
				row.ammoFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
			end

			-- Update Power
			local rng = golem.dynamicRange or 40
			local powerMult = 40 / rng
			row.powerLabel.Text = string.format("%.1fx", powerMult)

			if powerMult >= 2.0 then
				row.powerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			elseif powerMult >= 1.0 then
				row.powerLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
			else
				row.powerLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
			end

			-- Update Status based on ammo
			local ammoPercent = math.floor(ratio * 100)
			if ratio <= 0 then
				row.statusLabel.Text = "EMPTY"
				row.statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			elseif ratio < 0.3 then
				row.statusLabel.Text = "LOW " .. ammoPercent .. "%"
				row.statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
			else
				row.statusLabel.Text = ammoPercent .. "%"
				row.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
		end

		-- === UPDATE BOTS ===
		for i, bot in ipairs(botsData) do
			seenBotIds[bot.id] = true

			local row = botRows[bot.id]
			if not row then
				row = createBotCell(bot, i)
				botRows[bot.id] = row
			else
				row.btn.LayoutOrder = i
			end

			-- Update ID
			row.idLabel.Text = "B" .. (bot.spotId or "?")

			-- Update Cargo
			local scrap = bot.scrapInventory or 0
			local maxCargo = bot.maxCapacity or 50
			row.cargoLabel.Text = tostring(scrap)

			local cargoRatio = scrap / maxCargo
			row.cargoFill.Size = UDim2.new(cargoRatio, 0, 1, 0)

			-- Color cargo based on amount
			if cargoRatio >= 1 then
				row.cargoFill.BackgroundColor3 = Color3.fromRGB(255, 220, 50)
				row.cargoLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
			elseif cargoRatio > 0 then
				row.cargoFill.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
				row.cargoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			else
				row.cargoFill.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				row.cargoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			end

			-- Update Status (IDLE/MOVING/FULL)
			local status = bot.status or "IDLE"
			if cargoRatio >= 1 then
				row.statusLabel.Text = "FULL"
				row.statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			elseif status == "MOVING" then
				row.statusLabel.Text = "MOVING"
				row.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			elseif status == "ERR" then
				row.statusLabel.Text = "ERROR"
				row.statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			else
				row.statusLabel.Text = "IDLE"
				row.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
		end

		-- Cleanup removed golems
		for id, row in pairs(golemRows) do
			if not seenGolemIds[id] then
				row.btn:Destroy()
				golemRows[id] = nil
			end
		end

		-- Cleanup removed bots
		for id, row in pairs(botRows) do
			if not seenBotIds[id] then
				row.btn:Destroy()
				botRows[id] = nil
			end
		end
	end

	return panel
end

return UnitListPanel
