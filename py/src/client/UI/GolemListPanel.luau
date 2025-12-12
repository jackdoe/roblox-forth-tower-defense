local Players = game:GetService("Players")

local GolemListPanel = {}

function GolemListPanel.create(parent, callbacks)
	local panel = {}
	callbacks = callbacks or {}

	local modelCache = {}

	-- // CONFIGURATION //
	local ROWS = 5
	local ITEM_HEIGHT = 45
	local PADDING = 6

	-- Dimensions
	local LIST_WIDTH = 200
	local LIST_HEIGHT = (ITEM_HEIGHT * ROWS) + (PADDING * (ROWS - 1))

	-- Main Container
	local frame = Instance.new("Frame")
	frame.Name = "GolemListPanel"
	frame.Size = UDim2.new(0, LIST_WIDTH, 0, LIST_HEIGHT)
	frame.Position = UDim2.new(0, 10, 0.5, -(LIST_HEIGHT / 2))
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = parent

	-- Header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 20)
	header.Position = UDim2.new(0, 0, 0, -24)
	header.BackgroundTransparency = 1
	header.Text = "TURRET NETWORK"
	header.TextColor3 = Color3.fromRGB(150, 200, 255)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 12
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = frame

	-- Container
	local container = Instance.new("ScrollingFrame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 0
	container.ScrollingEnabled = false
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.Parent = frame

	-- // GRID LAYOUT //
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellSize = UDim2.new(0.5, -3, 0, ITEM_HEIGHT)
	layout.CellPadding = UDim2.new(0, PADDING, 0, PADDING)
	layout.Parent = container

	local rows = {}

	-- Helper: Find golem position
	local function getGolemPosition(golemId)
		if modelCache[golemId] and modelCache[golemId].Parent then
			local hrp = modelCache[golemId]:FindFirstChild("HumanoidRootPart") or modelCache[golemId].PrimaryPart
			if hrp then return hrp.Position end
		end
		for _, model in ipairs(workspace:GetChildren()) do
			if model:GetAttribute("GolemId") == golemId then
				modelCache[golemId] = model
				local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
				if hrp then return hrp.Position end
			end
		end
		return nil
	end

	-- Helper: Count enemies
	local function countEnemiesNear(pos, range)
		if not pos then return 0 end
		local count = 0
		for _, child in ipairs(workspace:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart")
				and not child:GetAttribute("GolemId")
				and child ~= Players.LocalPlayer.Character then
				local ePos = child.HumanoidRootPart.Position
				if (ePos - pos).Magnitude <= range then
					count = count + 1
				end
			end
		end
		return count
	end

	local function createRow(golem)
		-- Button container
		local btn = Instance.new("ImageButton")
		btn.Name = golem.id
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		btn.BackgroundTransparency = 0.2
		btn.AutoButtonColor = true
		btn.ImageTransparency = 1
		btn.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 60, 80)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		-- ID (Top Left)
		local idLabel = Instance.new("TextLabel")
		idLabel.Size = UDim2.new(0, 30, 0, 16)
		idLabel.Position = UDim2.new(0, 6, 0, 4)
		idLabel.BackgroundTransparency = 1
		idLabel.Text = "#" .. (golem.spotId or "?")
		idLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
		idLabel.Font = Enum.Font.GothamBold
		idLabel.TextSize = 14
		idLabel.TextXAlignment = Enum.TextXAlignment.Left
		idLabel.Parent = btn

		-- Range / Power (Top Right) -- WIDENED to fit "2.0x @ 20"
		local rangeLabel = Instance.new("TextLabel")
		rangeLabel.Size = UDim2.new(0, 80, 0, 16)
		rangeLabel.Position = UDim2.new(1, -86, 0, 4)
		rangeLabel.BackgroundTransparency = 1
		rangeLabel.Text = "1.0x @ 40"
		rangeLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		rangeLabel.Font = Enum.Font.Code
		rangeLabel.TextSize = 10
		rangeLabel.TextXAlignment = Enum.TextXAlignment.Right
		rangeLabel.Parent = btn

		-- Ammo Bar
		local ammoBg = Instance.new("Frame")
		ammoBg.Size = UDim2.new(1, -12, 0, 4)
		ammoBg.Position = UDim2.new(0, 6, 0, 24)
		ammoBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		ammoBg.BorderSizePixel = 0
		ammoBg.Parent = btn

		local ammoFill = Instance.new("Frame")
		ammoFill.Size = UDim2.new(1, 0, 1, 0)
		ammoFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
		ammoFill.BorderSizePixel = 0
		ammoFill.Parent = ammoBg

		-- Status / Targets (Bottom)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.new(1, -12, 0, 14)
		statusLabel.Position = UDim2.new(0, 6, 0, 30)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = "Targets: 0"
		statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		statusLabel.Font = Enum.Font.Code
		statusLabel.TextSize = 10
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if callbacks.onSelect then
				callbacks.onSelect(golem.id)
			end
		end)

		return {
			btn = btn,
			idLabel = idLabel,
			rangeLabel = rangeLabel,
			ammoFill = ammoFill,
			statusLabel = statusLabel,
			stroke = stroke
		}
	end

	function panel:update(golemsData)
		if not golemsData or #golemsData == 0 then
			frame.Visible = false
			return
		end

		frame.Visible = true

		table.sort(golemsData, function(a, b)
			return (a.spotId or 0) < (b.spotId or 0)
		end)

		local seenIds = {}

		for _, golem in ipairs(golemsData) do
			seenIds[golem.id] = true

			local row = rows[golem.id]
			if not row then
				row = createRow(golem)
				rows[golem.id] = row
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

			-- Update Range & Power
			local rng = golem.dynamicRange or 40
			local powerMult = 40 / rng

			-- Format string: "2.0x @ 20"
			row.rangeLabel.Text = string.format("%.1fx @ %d", powerMult, rng)

			-- Color logic: Red = Strong, Yellow = Normal, Blue = Weak/Long Range
			if powerMult >= 2.0 then
				row.rangeLabel.TextColor3 = Color3.fromRGB(255, 80, 80) -- Strong Red
			elseif powerMult >= 1.0 then
				row.rangeLabel.TextColor3 = Color3.fromRGB(255, 220, 100) -- Normal Yellow
			else
				row.rangeLabel.TextColor3 = Color3.fromRGB(150, 200, 255) -- Weak/Long Blue
			end

			-- Update Targets
			local pos = getGolemPosition(golem.id)
			if pos then
				local count = countEnemiesNear(pos, rng)
				row.statusLabel.Text = "Targets: " .. count

				if count > 0 then
					row.statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
					row.stroke.Color = Color3.fromRGB(100, 100, 80) -- Highlight border if active
				else
					row.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
					row.stroke.Color = Color3.fromRGB(60, 60, 80)
				end
			end

			row.btn.LayoutOrder = golem.spotId
		end

		-- Cleanup
		for id, row in pairs(rows) do
			if not seenIds[id] then
				row.btn:Destroy()
				rows[id] = nil
			end
		end
	end

	return panel
end

return GolemListPanel
