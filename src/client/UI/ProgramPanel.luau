-- ProgramPanel.luau
-- Shows executing program with current token highlighted in yellow

local DragModule = require(script.Parent.DragModule)

local ProgramPanel = {}

-- Theme definitions
local THEMES = {
	player = {
		frameBg = Color3.fromRGB(30, 30, 40),
		headerBg = Color3.fromRGB(40, 40, 55),
		codeBg = Color3.fromRGB(25, 25, 35),
	},
	golem = {
		frameBg = Color3.fromRGB(40, 35, 25),
		headerBg = Color3.fromRGB(55, 45, 30),
		codeBg = Color3.fromRGB(40, 35, 25),
	}
}

local function formatValue(value)
	if type(value) == "string" then return value end
	return tostring(value)
end

function ProgramPanel.create(parent)
	local panel = {}
	local outputCleared = false
	local errorCleared = false

	local MAX_SLOTS = 8
	local SLOT_HEIGHT = 14

	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "ProgramPanel"
	frame.Size = UDim2.new(0, 340, 0, 340)
	frame.Position = UDim2.new(1, -350, 1, -350)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	header.BorderSizePixel = 0
	header.Parent = frame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	DragModule.makeDraggable(frame, header)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "PROGRAM"
	title.TextColor3 = Color3.fromRGB(180, 180, 200)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Code
	title.TextSize = 12
	title.Parent = header

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(0, 80, 1, 0)
	statusLabel.Position = UDim2.new(1, -85, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "IDLE"
	statusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 12
	statusLabel.Parent = header

	-- ===== CODE DISPLAY SECTION =====
	local codeY = 34

	local codeFrame = Instance.new("Frame")
	codeFrame.Name = "CodeFrame"
	codeFrame.Size = UDim2.new(1, -20, 0, 90)
	codeFrame.Position = UDim2.new(0, 10, 0, codeY)
	codeFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	codeFrame.BorderSizePixel = 0
	codeFrame.Parent = frame

	local codeCorner = Instance.new("UICorner")
	codeCorner.CornerRadius = UDim.new(0, 6)
	codeCorner.Parent = codeFrame

	-- Context label (MAIN or word name)
	local contextLabel = Instance.new("TextLabel")
	contextLabel.Name = "ContextLabel"
	contextLabel.Size = UDim2.new(1, -8, 0, 16)
	contextLabel.Position = UDim2.new(0, 4, 0, 2)
	contextLabel.BackgroundTransparency = 1
	contextLabel.Text = "► MAIN"
	contextLabel.RichText = true
	contextLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	contextLabel.TextXAlignment = Enum.TextXAlignment.Left
	contextLabel.Font = Enum.Font.Code
	contextLabel.TextSize = 12
	contextLabel.Parent = codeFrame

	-- Code display
	local codeLabel = Instance.new("TextLabel")
	codeLabel.Name = "Code"
	codeLabel.Size = UDim2.new(1, -8, 0, 68)
	codeLabel.Position = UDim2.new(0, 4, 0, 20)
	codeLabel.BackgroundTransparency = 1
	codeLabel.Text = ""
	codeLabel.RichText = true
	codeLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	codeLabel.TextXAlignment = Enum.TextXAlignment.Left
	codeLabel.TextYAlignment = Enum.TextYAlignment.Top
	codeLabel.Font = Enum.Font.Code
	codeLabel.TextSize = 12
	codeLabel.TextWrapped = true
	codeLabel.Parent = codeFrame

	-- ===== DATA STACKS SECTION =====
	local columnsY = codeY + 96

	local columnsContainer = Instance.new("Frame")
	columnsContainer.Name = "ColumnsContainer"
	columnsContainer.Size = UDim2.new(1, -20, 0, MAX_SLOTS * SLOT_HEIGHT + 14)
	columnsContainer.Position = UDim2.new(0, 10, 0, columnsY)
	columnsContainer.BackgroundTransparency = 1
	columnsContainer.Parent = frame

	local function createColumn(name, posX, headerColor, labelColor)
		local colFrame = Instance.new("Frame")
		colFrame.Name = name
		colFrame.Size = UDim2.new(0.25, 0, 1, 0)
		colFrame.Position = UDim2.new(posX, 0, 0, 0)
		colFrame.BackgroundTransparency = 1
		colFrame.Parent = columnsContainer

		local colHeader = Instance.new("TextLabel")
		colHeader.Size = UDim2.new(1, 0, 0, 14)
		colHeader.BackgroundTransparency = 1
		colHeader.Text = name
		colHeader.TextColor3 = headerColor
		colHeader.TextXAlignment = Enum.TextXAlignment.Left
		colHeader.Font = Enum.Font.Code
		colHeader.TextSize = 10
		colHeader.Parent = colFrame

		local items = Instance.new("Frame")
		items.Name = "Items"
		items.Size = UDim2.new(1, 0, 1, -14)
		items.Position = UDim2.new(0, 0, 0, 14)
		items.BackgroundTransparency = 1
		items.Parent = colFrame

		local labels = {}
		for i = 1, MAX_SLOTS do
			local label = Instance.new("TextLabel")
			label.Name = "Slot" .. i
			label.Size = UDim2.new(1, 0, 0, SLOT_HEIGHT)
			label.Position = UDim2.new(0, 0, 1, -SLOT_HEIGHT * i)
			label.BackgroundTransparency = 1
			label.Text = ""
			label.TextColor3 = labelColor
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Font = Enum.Font.Code
			label.TextSize = 11
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.Parent = items
			labels[i] = label
		end

		return labels
	end

	local dataLabels = createColumn("DATA", 0, Color3.fromRGB(100, 180, 255), Color3.fromRGB(100, 180, 255))
	local rstackLabels = createColumn("R-STACK", 0.25, Color3.fromRGB(255, 180, 100), Color3.fromRGB(255, 180, 100))
	local localMemLabels = createColumn("LOCAL", 0.5, Color3.fromRGB(150, 200, 150), Color3.fromRGB(150, 200, 150))
	local sharedMemLabels = createColumn("SHARED", 0.75, Color3.fromRGB(200, 150, 200), Color3.fromRGB(200, 150, 200))

	-- ===== OUTPUT SECTION =====
	local outputY = columnsY + MAX_SLOTS * SLOT_HEIGHT + 20

	local outputHeader = Instance.new("TextLabel")
	outputHeader.Size = UDim2.new(1, -40, 0, 14)
	outputHeader.Position = UDim2.new(0, 10, 0, outputY)
	outputHeader.BackgroundTransparency = 1
	outputHeader.Text = "OUTPUT:"
	outputHeader.TextColor3 = Color3.fromRGB(120, 120, 140)
	outputHeader.TextXAlignment = Enum.TextXAlignment.Left
	outputHeader.Font = Enum.Font.Code
	outputHeader.TextSize = 10
	outputHeader.Parent = frame

	local outputClearBtn = Instance.new("TextButton")
	outputClearBtn.Size = UDim2.new(0, 20, 0, 14)
	outputClearBtn.Position = UDim2.new(1, -30, 0, outputY)
	outputClearBtn.BackgroundTransparency = 1
	outputClearBtn.Text = "X"
	outputClearBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	outputClearBtn.Font = Enum.Font.Code
	outputClearBtn.TextSize = 10
	outputClearBtn.Parent = frame

	local outputLabel = Instance.new("TextLabel")
	outputLabel.Size = UDim2.new(1, -20, 0, 16)
	outputLabel.Position = UDim2.new(0, 10, 0, outputY + 14)
	outputLabel.BackgroundTransparency = 1
	outputLabel.Text = ""
	outputLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
	outputLabel.TextXAlignment = Enum.TextXAlignment.Left
	outputLabel.Font = Enum.Font.Code
	outputLabel.TextSize = 11
	outputLabel.TextTruncate = Enum.TextTruncate.AtEnd
	outputLabel.Parent = frame

	-- ===== ERROR SECTION =====
	local errorY = outputY + 32

	local errorHeader = Instance.new("TextLabel")
	errorHeader.Size = UDim2.new(1, -40, 0, 14)
	errorHeader.Position = UDim2.new(0, 10, 0, errorY)
	errorHeader.BackgroundTransparency = 1
	errorHeader.Text = "ERROR:"
	errorHeader.TextColor3 = Color3.fromRGB(120, 120, 140)
	errorHeader.TextXAlignment = Enum.TextXAlignment.Left
	errorHeader.Font = Enum.Font.Code
	errorHeader.TextSize = 10
	errorHeader.Parent = frame

	local errorClearBtn = Instance.new("TextButton")
	errorClearBtn.Size = UDim2.new(0, 20, 0, 14)
	errorClearBtn.Position = UDim2.new(1, -30, 0, errorY)
	errorClearBtn.BackgroundTransparency = 1
	errorClearBtn.Text = "X"
	errorClearBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
	errorClearBtn.Font = Enum.Font.Code
	errorClearBtn.TextSize = 10
	errorClearBtn.Parent = frame

	local errorLabel = Instance.new("TextLabel")
	errorLabel.Size = UDim2.new(1, -20, 0, 16)
	errorLabel.Position = UDim2.new(0, 10, 0, errorY + 14)
	errorLabel.BackgroundTransparency = 1
	errorLabel.Text = ""
	errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	errorLabel.TextXAlignment = Enum.TextXAlignment.Left
	errorLabel.Font = Enum.Font.Code
	errorLabel.TextSize = 11
	errorLabel.TextTruncate = Enum.TextTruncate.AtEnd
	errorLabel.Parent = frame

	outputClearBtn.MouseButton1Click:Connect(function()
		outputCleared = true
		outputLabel.Text = ""
	end)

	errorClearBtn.MouseButton1Click:Connect(function()
		errorCleared = true
		errorLabel.Text = ""
	end)

	local lastOutput = ""
	local lastError = ""

	panel.frame = frame

	function panel:setTheme(themeName)
		local theme = THEMES[themeName] or THEMES.player
		frame.BackgroundColor3 = theme.frameBg
		header.BackgroundColor3 = theme.headerBg
		codeFrame.BackgroundColor3 = theme.codeBg
	end

	function panel:update(state)
		-- Status (show PAUSED if paused, otherwise actual status)
		local displayStatus = state.status or "IDLE"
		if state.paused and state.status ~= "ERROR" and state.status ~= "DONE" then
			displayStatus = "PAUSED"
		end
		statusLabel.Text = displayStatus
		if state.status == "ERROR" then
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif state.paused then
			statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		elseif state.status == "RUNNING" then
			statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		elseif state.status == "DONE" then
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end

		-- Execution context
		local ctx = state.execContext or "MAIN"
		local isInWord = ctx ~= "MAIN"

		if isInWord then
			contextLabel.Text = "► : " .. ctx .. " (2x)"
			contextLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			codeFrame.BackgroundColor3 = Color3.fromRGB(40, 35, 25)
		else
			contextLabel.Text = "► MAIN"
			contextLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
			codeFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		end

		-- Code display with current token highlighted in yellow
		local tokens = state.tokens
		local currentIdx = state.currentTokenIdx

		if tokens and #tokens > 0 then
			local parts = {}
			for i, token in ipairs(tokens) do
				local escaped = token:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
				if i == currentIdx then
					parts[#parts + 1] = '<font color="#FFFF00"><b>' .. escaped .. '</b></font>'
				else
					parts[#parts + 1] = escaped
				end
			end
			codeLabel.Text = table.concat(parts, " ")
		else
			codeLabel.Text = ""
		end

		-- DATA stack
		for i = 1, MAX_SLOTS do
			dataLabels[i].Text = ""
		end
		if state.stack and #state.stack > 0 then
			local stackSize = #state.stack
			local startIdx = math.max(1, stackSize - MAX_SLOTS + 1)
			for i = startIdx, stackSize do
				local displayPos = i - startIdx + 1
				dataLabels[displayPos].Text = formatValue(state.stack[i])
			end
			if stackSize > MAX_SLOTS then
				dataLabels[1].Text = "..."
			end
		end

		-- R-STACK (call stack depth indicator)
		for i = 1, MAX_SLOTS do
			rstackLabels[i].Text = ""
		end
		local depth = state.callStackDepth or 0
		if depth > 0 then
			rstackLabels[1].Text = "depth: " .. depth
		end

		-- LOCAL memory (M0-M9)
		for i = 1, MAX_SLOTS do
			local slotNum = i - 1
			local val = state.memorySlots and state.memorySlots[i] or 0
			if val ~= 0 then
				localMemLabels[i].Text = "M" .. slotNum .. "=" .. formatValue(val)
			else
				localMemLabels[i].Text = "M" .. slotNum .. "=-"
			end
		end

		-- SHARED memory (S0-S9)
		for i = 1, MAX_SLOTS do
			local slotNum = i - 1
			local val = state.sharedMemory and state.sharedMemory[i] or 0
			if val ~= 0 then
				sharedMemLabels[i].Text = "S" .. slotNum .. "=" .. formatValue(val)
			else
				sharedMemLabels[i].Text = "S" .. slotNum .. "=-"
			end
		end

		-- Output
		local currentOutput = state.output or ""
		if currentOutput ~= lastOutput then
			lastOutput = currentOutput
			outputCleared = false
		end
		if not outputCleared then
			outputLabel.Text = currentOutput
		end

		-- Error
		local currentError = state.error or ""
		if currentError ~= lastError then
			lastError = currentError
			errorCleared = false
		end
		if not errorCleared then
			errorLabel.Text = currentError
		end
	end

	return panel
end

return ProgramPanel
