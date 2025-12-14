local DragModule = require(script.Parent.DragModule)
local UITheme = require(script.Parent.UITheme)

local ProgramPanel = {}
local THEMES = UITheme.THEMES
local COLORS = UITheme.COLORS
local formatValue = UITheme.formatValue

function ProgramPanel.create(parent)
	local panel = {}
	local outputCleared = false
	local errorCleared = false
	local currentTheme = "player"

	local MAX_VARIABLES = 20
	local MIN_PANEL_HEIGHT = 350
	local VAR_LINE_HEIGHT = 18

	local frame = Instance.new("Frame")
	frame.Name = "ProgramPanel"
	frame.Size = UDim2.new(0, 380, 0, MIN_PANEL_HEIGHT)
	frame.Position = UDim2.new(1, -390, 1, -360)
	frame.BackgroundColor3 = THEMES.player.frameBg
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = THEMES.player.headerBg
	header.BorderSizePixel = 0
	header.Parent = frame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	DragModule.makeDraggable(frame, header)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.5, 0, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "PYTHON DEBUGGER"
	title.TextColor3 = COLORS.text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Code
	title.TextSize = 12
	title.Parent = header

	local bytecodeToggle = Instance.new("TextButton")
	bytecodeToggle.Name = "BytecodeToggle"
	bytecodeToggle.Size = UDim2.new(0, 24, 0, 18)
	bytecodeToggle.Position = UDim2.new(1, -115, 0, 5)
	bytecodeToggle.BackgroundColor3 = COLORS.panel
	bytecodeToggle.Text = "{}"
	bytecodeToggle.TextColor3 = COLORS.accent
	bytecodeToggle.Font = Enum.Font.Code
	bytecodeToggle.TextSize = 10
	bytecodeToggle.Parent = header

	local bytecodeToggleCorner = Instance.new("UICorner")
	bytecodeToggleCorner.CornerRadius = UDim.new(0, 4)
	bytecodeToggleCorner.Parent = bytecodeToggle

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(0, 80, 1, 0)
	statusLabel.Position = UDim2.new(1, -85, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "IDLE"
	statusLabel.TextColor3 = COLORS.success
	statusLabel.TextXAlignment = Enum.TextXAlignment.Right
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 12
	statusLabel.Parent = header

	-- Toggle callback (set by caller)
	panel.onBytecodeToggle = nil

	bytecodeToggle.MouseButton1Click:Connect(function()
		if panel.onBytecodeToggle then
			panel.onBytecodeToggle()
		end
	end)

	function panel:setBytecodeVisible(visible)
		if visible then
			bytecodeToggle.BackgroundColor3 = COLORS.accent
			bytecodeToggle.TextColor3 = COLORS.text
		else
			bytecodeToggle.BackgroundColor3 = COLORS.panel
			bytecodeToggle.TextColor3 = COLORS.accent
		end
	end

	-- ===== CODE DISPLAY SECTION =====
	local codeY = 34

	local codeHeader = Instance.new("TextLabel")
	codeHeader.Size = UDim2.new(1, -20, 0, 16)
	codeHeader.Position = UDim2.new(0, 10, 0, codeY)
	codeHeader.BackgroundTransparency = 1
	codeHeader.Text = "SOURCE CODE"
	codeHeader.TextColor3 = COLORS.subtext
	codeHeader.TextXAlignment = Enum.TextXAlignment.Left
	codeHeader.Font = Enum.Font.Code
	codeHeader.TextSize = 10
	codeHeader.Parent = frame

	local codeScroll = Instance.new("ScrollingFrame")
	codeScroll.Name = "CodeScroll"
	codeScroll.Size = UDim2.new(1, -20, 0, 100)
	codeScroll.Position = UDim2.new(0, 10, 0, codeY + 18)
	codeScroll.BackgroundColor3 = THEMES.player.codeBg
	codeScroll.BorderSizePixel = 0
	codeScroll.ScrollBarThickness = 4
	codeScroll.ScrollBarImageColor3 = COLORS.subtext
	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	codeScroll.Parent = frame

	local codeCorner = Instance.new("UICorner")
	codeCorner.CornerRadius = UDim.new(0, 6)
	codeCorner.Parent = codeScroll

	local codeLabel = Instance.new("TextLabel")
	codeLabel.Name = "Code"
	codeLabel.Size = UDim2.new(1, -8, 0, 0)
	codeLabel.Position = UDim2.new(0, 4, 0, 4)
	codeLabel.BackgroundTransparency = 1
	codeLabel.Text = ""
	codeLabel.RichText = true
	codeLabel.TextColor3 = COLORS.text
	codeLabel.TextXAlignment = Enum.TextXAlignment.Left
	codeLabel.TextYAlignment = Enum.TextYAlignment.Top
	codeLabel.Font = Enum.Font.Code
	codeLabel.TextSize = 12
	codeLabel.TextWrapped = false
	codeLabel.AutomaticSize = Enum.AutomaticSize.Y
	codeLabel.Parent = codeScroll

	-- ===== VARIABLES SECTION =====
	local varsY = codeY + 125
	local baseVarsHeight = 60  -- Minimum height for variables section

	local varsHeader = Instance.new("TextLabel")
	varsHeader.Size = UDim2.new(1, -20, 0, 16)
	varsHeader.Position = UDim2.new(0, 10, 0, varsY)
	varsHeader.BackgroundTransparency = 1
	varsHeader.Text = "VARIABLES"
	varsHeader.TextColor3 = COLORS.subtext
	varsHeader.TextXAlignment = Enum.TextXAlignment.Left
	varsHeader.Font = Enum.Font.Code
	varsHeader.TextSize = 10
	varsHeader.Parent = frame

	local varsFrame = Instance.new("Frame")
	varsFrame.Name = "VarsFrame"
	varsFrame.Size = UDim2.new(1, -20, 0, baseVarsHeight)
	varsFrame.Position = UDim2.new(0, 10, 0, varsY + 18)
	varsFrame.BackgroundColor3 = THEMES.player.codeBg
	varsFrame.BorderSizePixel = 0
	varsFrame.ClipsDescendants = true
	varsFrame.Parent = frame

	local varsCorner = Instance.new("UICorner")
	varsCorner.CornerRadius = UDim.new(0, 6)
	varsCorner.Parent = varsFrame

	local varsLayout = Instance.new("UIListLayout")
	varsLayout.Padding = UDim.new(0, 2)
	varsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	varsLayout.Parent = varsFrame

	local varsPadding = Instance.new("UIPadding")
	varsPadding.PaddingTop = UDim.new(0, 4)
	varsPadding.PaddingLeft = UDim.new(0, 4)
	varsPadding.PaddingRight = UDim.new(0, 4)
	varsPadding.PaddingBottom = UDim.new(0, 4)
	varsPadding.Parent = varsFrame

	local varLabels = {}
	for i = 1, MAX_VARIABLES do
		local label = Instance.new("TextLabel")
		label.Name = "Var" .. i
		label.Size = UDim2.new(1, 0, 0, VAR_LINE_HEIGHT)
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Text = ""
		label.RichText = true
		label.TextColor3 = COLORS.text
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.Code
		label.TextSize = 11
		label.Visible = false
		label.Parent = varsFrame
		varLabels[i] = label
	end

	local noVarsLabel = Instance.new("TextLabel")
	noVarsLabel.Name = "NoVars"
	noVarsLabel.Size = UDim2.new(1, 0, 0, VAR_LINE_HEIGHT)
	noVarsLabel.LayoutOrder = 0
	noVarsLabel.BackgroundTransparency = 1
	noVarsLabel.Text = "(no variables yet)"
	noVarsLabel.TextColor3 = COLORS.subtext
	noVarsLabel.TextXAlignment = Enum.TextXAlignment.Left
	noVarsLabel.Font = Enum.Font.Code
	noVarsLabel.TextSize = 11
	noVarsLabel.Parent = varsFrame

	-- Forward declarations for dynamic elements
	local outputHeaderEl, outputClearBtnEl, outputLabelEl
	local errorHeaderEl, errorClearBtnEl, errorLabelEl, errorScrollEl

	-- Function to resize panel based on variable count
	local function resizePanel(varCount)
		local varsHeight = math.max(baseVarsHeight, (varCount * (VAR_LINE_HEIGHT + 2)) + 12)
		varsFrame.Size = UDim2.new(1, -20, 0, varsHeight)

		local outputY = varsY + 18 + varsHeight + 8

		if outputHeaderEl then
			outputHeaderEl.Position = UDim2.new(0, 10, 0, outputY)
			outputClearBtnEl.Position = UDim2.new(1, -30, 0, outputY)
			outputLabelEl.Position = UDim2.new(0, 10, 0, outputY + 14)

			local errorY = outputY + 50
			errorHeaderEl.Position = UDim2.new(0, 10, 0, errorY)
			errorClearBtnEl.Position = UDim2.new(1, -30, 0, errorY)
			if errorScrollEl then
				errorScrollEl.Position = UDim2.new(0, 10, 0, errorY + 14)
			end

			local totalHeight = errorY + 70
			frame.Size = UDim2.new(0, 380, 0, totalHeight)
			frame.Position = UDim2.new(1, -390, 1, -totalHeight - 10)
		end
	end

	-- ===== OUTPUT SECTION =====
	local outputY = varsY + 18 + baseVarsHeight + 8

	-- Store full output history
	local outputHistory = {}
	local MAX_HISTORY = 50

	outputHeaderEl = Instance.new("TextLabel")
	outputHeaderEl.Size = UDim2.new(0, 60, 0, 14)
	outputHeaderEl.Position = UDim2.new(0, 10, 0, outputY)
	outputHeaderEl.BackgroundTransparency = 1
	outputHeaderEl.Text = "OUTPUT:"
	outputHeaderEl.TextColor3 = COLORS.subtext
	outputHeaderEl.TextXAlignment = Enum.TextXAlignment.Left
	outputHeaderEl.Font = Enum.Font.Code
	outputHeaderEl.TextSize = 10
	outputHeaderEl.Parent = frame

	local outputExpandBtn = Instance.new("TextButton")
	outputExpandBtn.Size = UDim2.new(0, 50, 0, 14)
	outputExpandBtn.Position = UDim2.new(1, -80, 0, outputY)
	outputExpandBtn.BackgroundColor3 = COLORS.panel
	outputExpandBtn.Text = "EXPAND"
	outputExpandBtn.TextColor3 = COLORS.text
	outputExpandBtn.Font = Enum.Font.Code
	outputExpandBtn.TextSize = 9
	outputExpandBtn.Parent = frame

	local expandCorner = Instance.new("UICorner")
	expandCorner.CornerRadius = UDim.new(0, 3)
	expandCorner.Parent = outputExpandBtn

	outputClearBtnEl = Instance.new("TextButton")
	outputClearBtnEl.Size = UDim2.new(0, 20, 0, 14)
	outputClearBtnEl.Position = UDim2.new(1, -30, 0, outputY)
	outputClearBtnEl.BackgroundTransparency = 1
	outputClearBtnEl.Text = "X"
	outputClearBtnEl.TextColor3 = COLORS.subtext
	outputClearBtnEl.Font = Enum.Font.Code
	outputClearBtnEl.TextSize = 10
	outputClearBtnEl.Parent = frame

	outputLabelEl = Instance.new("TextLabel")
	outputLabelEl.Size = UDim2.new(1, -20, 0, 18)
	outputLabelEl.Position = UDim2.new(0, 10, 0, outputY + 14)
	outputLabelEl.BackgroundColor3 = THEMES.player.codeBg
	outputLabelEl.Text = ""
	outputLabelEl.TextColor3 = COLORS.warning
	outputLabelEl.TextXAlignment = Enum.TextXAlignment.Left
	outputLabelEl.TextYAlignment = Enum.TextYAlignment.Center
	outputLabelEl.Font = Enum.Font.Code
	outputLabelEl.TextSize = 11
	outputLabelEl.TextTruncate = Enum.TextTruncate.AtEnd
	outputLabelEl.ClipsDescendants = true
	outputLabelEl.Parent = frame

	local outputCorner = Instance.new("UICorner")
	outputCorner.CornerRadius = UDim.new(0, 4)
	outputCorner.Parent = outputLabelEl

	local outputPadding = Instance.new("UIPadding")
	outputPadding.PaddingLeft = UDim.new(0, 4)
	outputPadding.Parent = outputLabelEl

	local outputModal = Instance.new("Frame")
	outputModal.Name = "OutputModal"
	outputModal.Size = UDim2.new(0, 400, 0, 350)
	outputModal.Position = UDim2.new(0.5, -200, 0.5, -175)
	outputModal.BackgroundColor3 = THEMES.player.frameBg
	outputModal.BorderSizePixel = 0
	outputModal.Visible = false
	outputModal.ZIndex = 100
	outputModal.Parent = parent

	local modalCorner = Instance.new("UICorner")
	modalCorner.CornerRadius = UDim.new(0, 8)
	modalCorner.Parent = outputModal

	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = COLORS.subtext
	modalStroke.Thickness = 1
	modalStroke.Parent = outputModal

	local modalHeader = Instance.new("Frame")
	modalHeader.Size = UDim2.new(1, 0, 0, 30)
	modalHeader.BackgroundColor3 = THEMES.player.headerBg
	modalHeader.BorderSizePixel = 0
	modalHeader.Parent = outputModal

	local modalHeaderCorner = Instance.new("UICorner")
	modalHeaderCorner.CornerRadius = UDim.new(0, 8)
	modalHeaderCorner.Parent = modalHeader

	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0, 10)
	headerFix.Position = UDim2.new(0, 0, 1, -10)
	headerFix.BackgroundColor3 = THEMES.player.headerBg
	headerFix.BorderSizePixel = 0
	headerFix.Parent = modalHeader

	local modalTitle = Instance.new("TextLabel")
	modalTitle.Size = UDim2.new(1, -40, 1, 0)
	modalTitle.Position = UDim2.new(0, 10, 0, 0)
	modalTitle.BackgroundTransparency = 1
	modalTitle.Text = "OUTPUT LOG"
	modalTitle.TextColor3 = COLORS.warning
	modalTitle.TextXAlignment = Enum.TextXAlignment.Left
	modalTitle.Font = Enum.Font.Code
	modalTitle.TextSize = 12
	modalTitle.Parent = modalHeader

	local modalCloseBtn = Instance.new("TextButton")
	modalCloseBtn.Size = UDim2.new(0, 24, 0, 24)
	modalCloseBtn.Position = UDim2.new(1, -27, 0, 3)
	modalCloseBtn.BackgroundColor3 = COLORS.danger
	modalCloseBtn.Text = "X"
	modalCloseBtn.TextColor3 = COLORS.text
	modalCloseBtn.Font = Enum.Font.Code
	modalCloseBtn.TextSize = 12
	modalCloseBtn.Parent = modalHeader

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 4)
	closeBtnCorner.Parent = modalCloseBtn

	local modalScroll = Instance.new("ScrollingFrame")
	modalScroll.Size = UDim2.new(1, -20, 1, -50)
	modalScroll.Position = UDim2.new(0, 10, 0, 40)
	modalScroll.BackgroundColor3 = COLORS.bg
	modalScroll.BorderSizePixel = 0
	modalScroll.ScrollBarThickness = 6
	modalScroll.ScrollBarImageColor3 = COLORS.subtext
	modalScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	modalScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	modalScroll.Parent = outputModal

	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 6)
	scrollCorner.Parent = modalScroll

	local modalOutputLabel = Instance.new("TextLabel")
	modalOutputLabel.Size = UDim2.new(1, -12, 0, 0)
	modalOutputLabel.Position = UDim2.new(0, 6, 0, 4)
	modalOutputLabel.BackgroundTransparency = 1
	modalOutputLabel.Text = ""
	modalOutputLabel.RichText = true
	modalOutputLabel.TextColor3 = COLORS.warning
	modalOutputLabel.TextXAlignment = Enum.TextXAlignment.Left
	modalOutputLabel.TextYAlignment = Enum.TextYAlignment.Top
	modalOutputLabel.Font = Enum.Font.Code
	modalOutputLabel.TextSize = 11
	modalOutputLabel.TextWrapped = true
	modalOutputLabel.AutomaticSize = Enum.AutomaticSize.Y
	modalOutputLabel.Parent = modalScroll

	-- Modal handlers
	outputExpandBtn.MouseButton1Click:Connect(function()
		-- Build output text with line numbers
		local lines = {}
		for i, line in ipairs(outputHistory) do
			table.insert(lines, '<font color="#606080">' .. string.format("%2d", i) .. '</font> ' .. line)
		end
		modalOutputLabel.Text = #lines > 0 and table.concat(lines, "\n") or '<font color="#606080">(no output)</font>'
		outputModal.Visible = true
	end)

	modalCloseBtn.MouseButton1Click:Connect(function()
		outputModal.Visible = false
	end)

	-- Store modal reference for theme updates
	panel.outputModal = outputModal
	panel.outputHistory = outputHistory

	local errorY = outputY + 36

	errorHeaderEl = Instance.new("TextLabel")
	errorHeaderEl.Size = UDim2.new(1, -40, 0, 14)
	errorHeaderEl.Position = UDim2.new(0, 10, 0, errorY)
	errorHeaderEl.BackgroundTransparency = 1
	errorHeaderEl.Text = "ERROR:"
	errorHeaderEl.TextColor3 = COLORS.subtext
	errorHeaderEl.TextXAlignment = Enum.TextXAlignment.Left
	errorHeaderEl.Font = Enum.Font.Code
	errorHeaderEl.TextSize = 10
	errorHeaderEl.Parent = frame

	errorClearBtnEl = Instance.new("TextButton")
	errorClearBtnEl.Size = UDim2.new(0, 20, 0, 14)
	errorClearBtnEl.Position = UDim2.new(1, -30, 0, errorY)
	errorClearBtnEl.BackgroundTransparency = 1
	errorClearBtnEl.Text = "X"
	errorClearBtnEl.TextColor3 = COLORS.subtext
	errorClearBtnEl.Font = Enum.Font.Code
	errorClearBtnEl.TextSize = 10
	errorClearBtnEl.Parent = frame

	errorScrollEl = Instance.new("ScrollingFrame")
	local errorScroll = errorScrollEl
	errorScroll.Name = "ErrorScroll"
	errorScroll.Size = UDim2.new(1, -20, 0, 50)
	errorScroll.Position = UDim2.new(0, 10, 0, errorY + 14)
	errorScroll.BackgroundColor3 = Color3.fromRGB(40, 25, 25)
	errorScroll.BorderSizePixel = 0
	errorScroll.ScrollBarThickness = 4
	errorScroll.ScrollBarImageColor3 = COLORS.danger
	errorScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	errorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	errorScroll.Parent = frame

	local errorScrollCorner = Instance.new("UICorner")
	errorScrollCorner.CornerRadius = UDim.new(0, 4)
	errorScrollCorner.Parent = errorScroll

	errorLabelEl = Instance.new("TextLabel")
	errorLabelEl.Size = UDim2.new(1, -8, 0, 0)
	errorLabelEl.Position = UDim2.new(0, 4, 0, 2)
	errorLabelEl.BackgroundTransparency = 1
	errorLabelEl.Text = ""
	errorLabelEl.TextColor3 = COLORS.danger
	errorLabelEl.TextXAlignment = Enum.TextXAlignment.Left
	errorLabelEl.TextYAlignment = Enum.TextYAlignment.Top
	errorLabelEl.Font = Enum.Font.Code
	errorLabelEl.TextSize = 11
	errorLabelEl.TextWrapped = true
	errorLabelEl.AutomaticSize = Enum.AutomaticSize.Y
	errorLabelEl.Parent = errorScroll

	outputClearBtnEl.MouseButton1Click:Connect(function()
		outputCleared = true
		outputLabelEl.Text = ""
		outputHistory = {}  -- Clear history too
	end)

	errorClearBtnEl.MouseButton1Click:Connect(function()
		errorCleared = true
		errorLabelEl.Text = ""
	end)

	local lastError = ""

	panel.frame = frame

	function panel:setTheme(themeName)
		currentTheme = themeName or "player"
		local theme = THEMES[currentTheme] or THEMES.player
		frame.BackgroundColor3 = theme.frameBg
		header.BackgroundColor3 = theme.headerBg
		codeScroll.BackgroundColor3 = theme.codeBg
		varsFrame.BackgroundColor3 = theme.codeBg
	end

	function panel:update(state)
		local theme = THEMES[currentTheme] or THEMES.player

		-- Status
		local displayStatus = state.status or "IDLE"
		if state.paused and state.status ~= "ERROR" and state.status ~= "DONE" then
			displayStatus = "PAUSED"
		end
		statusLabel.Text = displayStatus

		if state.status == "ERROR" then
			statusLabel.TextColor3 = COLORS.danger
		elseif state.paused then
			statusLabel.TextColor3 = COLORS.warning
		elseif state.status == "RUNNING" then
			statusLabel.TextColor3 = COLORS.accent
		elseif state.status == "DONE" then
			statusLabel.TextColor3 = COLORS.success
		else
			statusLabel.TextColor3 = COLORS.subtext
		end

		-- Code display - show Python source with line numbers
		-- Derive tokens from source, currentLine from bytecode[ip].line
		-- Important: preserve empty lines so line numbers match bytecode
		local source = state.source or ""
		local tokens = {}
		for line in (source .. "\n"):gmatch("(.-)\n") do
			table.insert(tokens, line)
		end

		local bytecode = state.bytecode or {}
		local ip = state.vm and state.vm.ip or 1
		local currentLine = bytecode[ip] and bytecode[ip].line or 0

		if #tokens > 0 then
			local lines = {}
			for i, line in ipairs(tokens) do
				local lineNum = string.format("%2d", i)
				local escaped = line:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

				-- Highlight current executing line with cyan/bright - no arrow to avoid offset
				if i == currentLine then
					-- Bright cyan line number + white text (no arrow!)
					lines[i] = '<font color="#00FFFF"><b>' .. lineNum .. '</b></font>  <font color="#FFFFFF"><b>' .. escaped .. '</b></font>'
				elseif escaped:match("^%s*#") then
					-- Color comments differently
					lines[i] = '<font color="#606080">' .. lineNum .. '</font>  <font color="#6A9955">' .. escaped .. '</font>'
				else
					lines[i] = '<font color="#606080">' .. lineNum .. '</font>  ' .. escaped
				end
			end
			codeLabel.Text = table.concat(lines, "\n")

			-- Update canvas size for scrolling
			local lineCount = #tokens
			codeScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(lineCount * 14 + 8, 100))
		else
			codeLabel.Text = '<font color="#606080">No code loaded</font>'
			codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		end

		-- Variables display
		local variables = state.variables or {}

		-- Sort variable names alphabetically
		local varNames = {}
		for name, _ in pairs(variables) do
			table.insert(varNames, name)
		end
		table.sort(varNames)

		-- Hide all labels first
		for i = 1, MAX_VARIABLES do
			varLabels[i].Visible = false
		end

		if #varNames == 0 then
			noVarsLabel.Visible = true
		else
			noVarsLabel.Visible = false

			local NIL_MARKER = "__NIL__"  -- Match server-side marker

			for i, name in ipairs(varNames) do
				if i > MAX_VARIABLES then
					-- Show overflow indicator
					varLabels[MAX_VARIABLES].Text = '<font color="#808080">... and ' .. (#varNames - MAX_VARIABLES + 1) .. ' more</font>'
					varLabels[MAX_VARIABLES].Visible = true
					break
				end

				local value = variables[name]
				-- Convert NIL_MARKER back to nil for display
				local isNil = (value == NIL_MARKER)
				if isNil then value = nil end

				local valueStr = isNil and "None" or formatValue(value, 25)

				-- Color code by type
				local valueColor
				if isNil or value == nil then
					valueColor = "#569CD6"  -- Blue for None
				elseif type(value) == "boolean" then
					valueColor = "#569CD6"  -- Blue for bool
				elseif type(value) == "number" then
					valueColor = "#B5CEA8"  -- Green for numbers
				elseif type(value) == "string" then
					valueColor = "#CE9178"  -- Orange for strings
				elseif type(value) == "table" then
					valueColor = "#DCDCAA"  -- Yellow for lists
				else
					valueColor = "#D4D4D4"  -- Gray for other
				end

				varLabels[i].Text = '<font color="#9CDCFE">' .. name .. '</font> = <font color="' .. valueColor .. '">' .. valueStr .. '</font>'
				varLabels[i].Visible = true
			end
		end

		-- Resize panel based on variable count
		resizePanel(#varNames)

		-- Output - array of lines from server
		outputHistory = state.output or {}

		if not outputCleared then
			-- Show only the last line
			local lastLine = outputHistory[#outputHistory] or ""
			outputLabelEl.Text = lastLine
		end

		-- Error
		local currentError = state.error or ""
		if currentError ~= lastError then
			lastError = currentError
			errorCleared = false
		end
		if not errorCleared then
			errorLabelEl.Text = currentError
		end
	end

	return panel
end

return ProgramPanel
