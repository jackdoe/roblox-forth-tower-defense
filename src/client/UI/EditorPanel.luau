-- EditorPanel.luau
-- Simple code editor (no tabs, no word editing)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DragModule = require(script.Parent.DragModule)
local ProgramLibrary = require(ReplicatedStorage:WaitForChild("Forthy"):WaitForChild("ProgramLibrary"))

local EditorPanel = {}

-- Auto-format Forth code with proper indentation
local function formatCode(source)
	-- Tokenize
	local tokens = {}
	for token in string.gmatch(source, "%S+") do
		table.insert(tokens, token:upper())
	end

	if #tokens == 0 then return "" end

	-- Words that increase indent after them
	local INDENT_AFTER = {
		["BEGIN"] = true,
		["IF"] = true,
		["DO"] = true,
		["?DO"] = true,
	}

	-- Words that decrease indent before them
	local DEDENT_BEFORE = {
		["AGAIN"] = true,
		["UNTIL"] = true,
		["REPEAT"] = true,
		["THEN"] = true,
		["LOOP"] = true,
		["+LOOP"] = true,
	}

	-- ELSE is special: dedent, print, then indent again
	local DEDENT_THEN_INDENT = {
		["ELSE"] = true,
	}

	local lines = {}
	local currentLine = {}
	local indent = 0
	local skipNext = false

	local i = 1
	while i <= #tokens do
		local token = tokens[i]

		if skipNext then
			skipNext = false
			i = i + 1
			continue
		end

		-- Handle word definition start
		if token == ":" then
			-- Start new line for word definition
			if #currentLine > 0 then
				table.insert(lines, { indent = indent, tokens = currentLine })
				currentLine = {}
			end
			-- : and word name on same line
			local wordName = tokens[i + 1]
			if wordName and wordName ~= ";" then
				table.insert(lines, { indent = indent, tokens = { ":", wordName } })
				indent = indent + 1
				skipNext = true
			else
				table.insert(currentLine, ":")
			end
		elseif token == ";" then
			-- End word definition
			indent = math.max(0, indent - 1)
			if #currentLine > 0 then
				table.insert(currentLine, ";")
				table.insert(lines, { indent = indent, tokens = currentLine })
				currentLine = {}
			else
				table.insert(lines, { indent = indent, tokens = { ";" } })
			end
		elseif INDENT_AFTER[token] then
			-- BEGIN, IF, etc - put on own line then increase indent
			if #currentLine > 0 then
				table.insert(lines, { indent = indent, tokens = currentLine })
				currentLine = {}
			end
			table.insert(lines, { indent = indent, tokens = { token } })
			indent = indent + 1
		elseif DEDENT_BEFORE[token] then
			-- AGAIN, THEN, etc - decrease indent first, then put on own line
			if #currentLine > 0 then
				table.insert(lines, { indent = indent, tokens = currentLine })
				currentLine = {}
			end
			indent = math.max(0, indent - 1)
			table.insert(lines, { indent = indent, tokens = { token } })
		elseif DEDENT_THEN_INDENT[token] then
			-- ELSE - dedent, print at same level as IF, then indent for body
			if #currentLine > 0 then
				table.insert(lines, { indent = indent, tokens = currentLine })
				currentLine = {}
			end
			indent = math.max(0, indent - 1)
			table.insert(lines, { indent = indent, tokens = { token } })
			indent = indent + 1
		else
			-- Regular token - add to current line
			table.insert(currentLine, token)
		end

		i = i + 1
	end

	-- Add remaining tokens
	if #currentLine > 0 then
		table.insert(lines, { indent = indent, tokens = currentLine })
	end

	-- Build output
	local output = {}
	for _, line in ipairs(lines) do
		local indentStr = string.rep("  ", line.indent)
		table.insert(output, indentStr .. table.concat(line.tokens, " "))
	end

	return table.concat(output, "\n")
end

-- Theme definitions
local THEMES = {
	player = {
		topBarBg = Color3.fromRGB(40, 40, 55),
		frameBg = Color3.fromRGB(30, 30, 40),
		startBtn = Color3.fromRGB(60, 100, 60),
	},
	golem = {
		topBarBg = Color3.fromRGB(55, 45, 30),
		frameBg = Color3.fromRGB(40, 35, 25),
		startBtn = Color3.fromRGB(100, 80, 40),
	}
}

function EditorPanel.create(parent, callbacks)
	local panel = {}
	callbacks = callbacks or {}

	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "EditorPanel"
	frame.Size = UDim2.new(0, 480, 0, 235)
	frame.Position = UDim2.new(0.5, -240, 1, -245)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Top bar
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 35)
	topBar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	topBar.BorderSizePixel = 0
	topBar.Parent = frame

	local topBarCorner = Instance.new("UICorner")
	topBarCorner.CornerRadius = UDim.new(0, 8)
	topBarCorner.Parent = topBar

	DragModule.makeDraggable(frame, topBar)

	-- Mode indicator badge (hidden by default)
	local modeIndicator = Instance.new("TextLabel")
	modeIndicator.Name = "ModeIndicator"
	modeIndicator.Size = UDim2.new(0, 120, 0, 20)
	modeIndicator.Position = UDim2.new(0.5, -60, 0, -24)
	modeIndicator.BackgroundColor3 = Color3.fromRGB(100, 70, 30)
	modeIndicator.BackgroundTransparency = 0.2
	modeIndicator.BorderSizePixel = 0
	modeIndicator.Text = ""
	modeIndicator.TextColor3 = Color3.fromRGB(255, 200, 100)
	modeIndicator.Font = Enum.Font.GothamBold
	modeIndicator.TextSize = 12
	modeIndicator.Visible = false
	modeIndicator.Parent = frame

	local modeCorner = Instance.new("UICorner")
	modeCorner.CornerRadius = UDim.new(0, 6)
	modeCorner.Parent = modeIndicator

	-- Exit golem button (hidden by default)
	local exitGolemBtn = Instance.new("TextButton")
	exitGolemBtn.Name = "ExitGolemBtn"
	exitGolemBtn.Size = UDim2.new(0, 80, 0, 26)
	exitGolemBtn.Position = UDim2.new(0, 295, 0, 4)
	exitGolemBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 40)
	exitGolemBtn.Text = "EXIT (ESC)"
	exitGolemBtn.TextColor3 = Color3.fromRGB(255, 180, 120)
	exitGolemBtn.Font = Enum.Font.GothamBold
	exitGolemBtn.TextSize = 10
	exitGolemBtn.Visible = false
	exitGolemBtn.Parent = topBar

	local exitCorner = Instance.new("UICorner")
	exitCorner.CornerRadius = UDim.new(0, 4)
	exitCorner.Parent = exitGolemBtn

	exitGolemBtn.MouseButton1Click:Connect(function()
		if panel.onExitGolem then
			panel.onExitGolem()
		end
	end)

	-- Sell golem button (hidden by default)
	local sellGolemBtn = Instance.new("TextButton")
	sellGolemBtn.Name = "SellGolemBtn"
	sellGolemBtn.Size = UDim2.new(0, 50, 0, 26)
	sellGolemBtn.Position = UDim2.new(0, 380, 0, 4)
	sellGolemBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
	sellGolemBtn.Text = "SELL"
	sellGolemBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
	sellGolemBtn.Font = Enum.Font.GothamBold
	sellGolemBtn.TextSize = 10
	sellGolemBtn.Visible = false
	sellGolemBtn.Parent = topBar

	local sellCorner = Instance.new("UICorner")
	sellCorner.CornerRadius = UDim.new(0, 4)
	sellCorner.Parent = sellGolemBtn

	sellGolemBtn.MouseButton1Click:Connect(function()
		if panel.onSellGolem then
			panel.onSellGolem()
		end
	end)

	-- Control buttons
	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartBtn"
	startBtn.Size = UDim2.new(0, 60, 0, 26)
	startBtn.Position = UDim2.new(0, 5, 0, 4)
	startBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
	startBtn.Text = "RUN ^1"
	startBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
	startBtn.Font = Enum.Font.GothamBold
	startBtn.TextSize = 10
	startBtn.Parent = topBar

	local startBtnCorner = Instance.new("UICorner")
	startBtnCorner.CornerRadius = UDim.new(0, 4)
	startBtnCorner.Parent = startBtn

	local pauseBtn = Instance.new("TextButton")
	pauseBtn.Name = "PauseBtn"
	pauseBtn.Size = UDim2.new(0, 65, 0, 26)
	pauseBtn.Position = UDim2.new(0, 70, 0, 4)
	pauseBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 60)
	pauseBtn.Text = "PAUSE ^2"
	pauseBtn.TextColor3 = Color3.fromRGB(255, 220, 200)
	pauseBtn.Font = Enum.Font.GothamBold
	pauseBtn.TextSize = 10
	pauseBtn.Parent = topBar

	local pauseBtnCorner = Instance.new("UICorner")
	pauseBtnCorner.CornerRadius = UDim.new(0, 4)
	pauseBtnCorner.Parent = pauseBtn

	local stepBtn = Instance.new("TextButton")
	stepBtn.Name = "StepBtn"
	stepBtn.Size = UDim2.new(0, 55, 0, 26)
	stepBtn.Position = UDim2.new(0, 140, 0, 4)
	stepBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	stepBtn.Text = "STEP ^3"
	stepBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
	stepBtn.Font = Enum.Font.GothamBold
	stepBtn.TextSize = 10
	stepBtn.Parent = topBar

	local stepBtnCorner = Instance.new("UICorner")
	stepBtnCorner.CornerRadius = UDim.new(0, 4)
	stepBtnCorner.Parent = stepBtn

	local helpBtn = Instance.new("TextButton")
	helpBtn.Name = "HelpBtn"
	helpBtn.Size = UDim2.new(0, 26, 0, 26)
	helpBtn.Position = UDim2.new(0, 200, 0, 4)
	helpBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	helpBtn.Text = "?"
	helpBtn.TextColor3 = Color3.fromRGB(150, 150, 255)
	helpBtn.Font = Enum.Font.GothamBold
	helpBtn.TextSize = 14
	helpBtn.Parent = topBar

	local helpBtnCorner = Instance.new("UICorner")
	helpBtnCorner.CornerRadius = UDim.new(0, 4)
	helpBtnCorner.Parent = helpBtn

	helpBtn.MouseButton1Click:Connect(function()
		if callbacks.onHelp then
			callbacks.onHelp()
		end
	end)

	local examplesBtn = Instance.new("TextButton")
	examplesBtn.Name = "ExamplesBtn"
	examplesBtn.Size = UDim2.new(0, 60, 0, 26)
	examplesBtn.Position = UDim2.new(0, 230, 0, 4)
	examplesBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	examplesBtn.Text = "EXAMPLES"
	examplesBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
	examplesBtn.Font = Enum.Font.GothamBold
	examplesBtn.TextSize = 10
	examplesBtn.Parent = topBar

	local examplesBtnCorner = Instance.new("UICorner")
	examplesBtnCorner.CornerRadius = UDim.new(0, 4)
	examplesBtnCorner.Parent = examplesBtn

	-- Line numbers
	local lineNumbers = Instance.new("TextLabel")
	lineNumbers.Name = "LineNumbers"
	lineNumbers.Size = UDim2.new(0, 25, 1, -60)
	lineNumbers.Position = UDim2.new(0, 5, 0, 40)
	lineNumbers.BackgroundTransparency = 1
	lineNumbers.Text = "1\n2\n3\n4\n5\n6\n7\n8"
	lineNumbers.TextColor3 = Color3.fromRGB(100, 100, 120)
	lineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 14
	lineNumbers.Parent = frame

	-- Code input
	local textBox = Instance.new("TextBox")
	textBox.Name = "CodeInput"
	textBox.Size = UDim2.new(1, -40, 1, -60)
	textBox.Position = UDim2.new(0, 35, 0, 40)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Enter Forth code..."
	textBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
	textBox.TextColor3 = Color3.fromRGB(220, 220, 240)
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 14
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.TextWrapped = true
	textBox.Parent = frame

	-- Hints bar
	local hintsBar = Instance.new("TextLabel")
	hintsBar.Name = "HintsBar"
	hintsBar.Size = UDim2.new(1, -10, 0, 15)
	hintsBar.Position = UDim2.new(0, 5, 1, -18)
	hintsBar.BackgroundTransparency = 1
	hintsBar.Text = "^Q: Unfocus  |  ^1: Run  |  ^2: Pause  |  ^3: Step"
	hintsBar.TextColor3 = Color3.fromRGB(90, 90, 110)
	hintsBar.Font = Enum.Font.Code
	hintsBar.TextSize = 10
	hintsBar.Parent = frame

	-- Update line numbers
	local function updateLineNumbers()
		local text = textBox.Text
		local lines = 1
		for _ in string.gmatch(text, "\n") do
			lines = lines + 1
		end
		lines = math.max(lines, 8)
		local nums = {}
		for i = 1, lines do
			table.insert(nums, tostring(i))
		end
		lineNumbers.Text = table.concat(nums, "\n")
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateLineNumbers)

	-- Button handlers
	startBtn.MouseButton1Click:Connect(function()
		-- Auto-format before saving
		textBox.Text = formatCode(textBox.Text)
		updateLineNumbers()
		if callbacks.onLoad then
			callbacks.onLoad(textBox.Text)
		end
	end)

	stepBtn.MouseButton1Click:Connect(function()
		if callbacks.onStep then
			callbacks.onStep(textBox.Text)
		end
	end)

	pauseBtn.MouseButton1Click:Connect(function()
		if callbacks.onPause then
			callbacks.onPause()
		end
	end)

	-- Programs popup (using ProgramLibrary)
	local programsPopup = Instance.new("Frame")
	programsPopup.Name = "ProgramsPopup"
	programsPopup.Size = UDim2.new(0, 500, 0, 420)
	programsPopup.Position = UDim2.new(0.5, -250, 0.5, -210)
	programsPopup.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	programsPopup.BorderSizePixel = 0
	programsPopup.Visible = false
	programsPopup.ZIndex = 100
	programsPopup.Parent = parent

	local programsCorner = Instance.new("UICorner")
	programsCorner.CornerRadius = UDim.new(0, 10)
	programsCorner.Parent = programsPopup

	local programsStroke = Instance.new("UIStroke")
	programsStroke.Color = Color3.fromRGB(100, 180, 100)
	programsStroke.Thickness = 2
	programsStroke.Parent = programsPopup

	local programsHeader = Instance.new("Frame")
	programsHeader.Size = UDim2.new(1, 0, 0, 40)
	programsHeader.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	programsHeader.BorderSizePixel = 0
	programsHeader.Parent = programsPopup

	local programsHeaderCorner = Instance.new("UICorner")
	programsHeaderCorner.CornerRadius = UDim.new(0, 10)
	programsHeaderCorner.Parent = programsHeader

	DragModule.makeDraggable(programsPopup, programsHeader)

	local programsTitle = Instance.new("TextLabel")
	programsTitle.Size = UDim2.new(0, 200, 1, 0)
	programsTitle.Position = UDim2.new(0, 15, 0, 0)
	programsTitle.BackgroundTransparency = 1
	programsTitle.Text = "PROGRAMS"
	programsTitle.TextColor3 = Color3.fromRGB(100, 255, 150)
	programsTitle.TextXAlignment = Enum.TextXAlignment.Left
	programsTitle.Font = Enum.Font.GothamBold
	programsTitle.TextSize = 16
	programsTitle.ZIndex = 101
	programsTitle.Parent = programsHeader

	-- Back button (hidden initially)
	local progBackBtn = Instance.new("TextButton")
	progBackBtn.Name = "BackBtn"
	progBackBtn.Size = UDim2.new(0, 60, 0, 26)
	progBackBtn.Position = UDim2.new(0, 220, 0, 7)
	progBackBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	progBackBtn.Text = "< BACK"
	progBackBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
	progBackBtn.Font = Enum.Font.GothamBold
	progBackBtn.TextSize = 10
	progBackBtn.Visible = false
	progBackBtn.ZIndex = 101
	progBackBtn.Parent = programsHeader

	local progBackBtnCorner = Instance.new("UICorner")
	progBackBtnCorner.CornerRadius = UDim.new(0, 4)
	progBackBtnCorner.Parent = progBackBtn

	local programsCloseBtn = Instance.new("TextButton")
	programsCloseBtn.Size = UDim2.new(0, 30, 0, 30)
	programsCloseBtn.Position = UDim2.new(1, -35, 0, 5)
	programsCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
	programsCloseBtn.Text = "X"
	programsCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	programsCloseBtn.Font = Enum.Font.GothamBold
	programsCloseBtn.TextSize = 14
	programsCloseBtn.ZIndex = 101
	programsCloseBtn.Parent = programsHeader

	local progCloseBtnCorner = Instance.new("UICorner")
	progCloseBtnCorner.CornerRadius = UDim.new(0, 6)
	progCloseBtnCorner.Parent = programsCloseBtn

	programsCloseBtn.MouseButton1Click:Connect(function()
		programsPopup.Visible = false
	end)

	local programsScroll = Instance.new("ScrollingFrame")
	programsScroll.Size = UDim2.new(1, -20, 1, -50)
	programsScroll.Position = UDim2.new(0, 10, 0, 45)
	programsScroll.BackgroundTransparency = 1
	programsScroll.ScrollBarThickness = 6
	programsScroll.ZIndex = 100
	programsScroll.Parent = programsPopup

	local programsLayout = Instance.new("UIListLayout")
	programsLayout.Padding = UDim.new(0, 4)
	programsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	programsLayout.Parent = programsScroll

	-- Forward declarations
	local showProgramDetails
	local showProgramsList

	-- Show program details view
	showProgramDetails = function(prog)
		-- Clear content
		for _, child in ipairs(programsScroll:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		programsTitle.Text = prog.name
		progBackBtn.Visible = true

		-- Program name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 30)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = prog.name
		nameLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 20
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 101
		nameLabel.LayoutOrder = 0
		nameLabel.Parent = programsScroll

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, 0, 0, 25)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = prog.desc
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 13
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.ZIndex = 101
		descLabel.LayoutOrder = 1
		descLabel.Parent = programsScroll

		-- Category
		local catLabel = Instance.new("TextLabel")
		catLabel.Size = UDim2.new(1, 0, 0, 20)
		catLabel.BackgroundTransparency = 1
		catLabel.Text = "Category: " .. prog.category
		catLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
		catLabel.Font = Enum.Font.Gotham
		catLabel.TextSize = 11
		catLabel.TextXAlignment = Enum.TextXAlignment.Left
		catLabel.ZIndex = 101
		catLabel.LayoutOrder = 2
		catLabel.Parent = programsScroll

		-- Code header
		local codeHeader = Instance.new("TextLabel")
		codeHeader.Size = UDim2.new(1, 0, 0, 25)
		codeHeader.BackgroundTransparency = 1
		codeHeader.Text = "Code:"
		codeHeader.TextColor3 = Color3.fromRGB(150, 200, 150)
		codeHeader.Font = Enum.Font.GothamBold
		codeHeader.TextSize = 12
		codeHeader.TextXAlignment = Enum.TextXAlignment.Left
		codeHeader.ZIndex = 101
		codeHeader.LayoutOrder = 3
		codeHeader.Parent = programsScroll

		-- Code preview
		local codeLines = select(2, string.gsub(prog.code, "\n", "\n")) + 1
		local codeHeight = math.min(codeLines * 16 + 16, 180)

		local codeBox = Instance.new("TextLabel")
		codeBox.Size = UDim2.new(1, 0, 0, codeHeight)
		codeBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		codeBox.Text = "  " .. string.gsub(prog.code, "\n", "\n  ")
		codeBox.TextColor3 = Color3.fromRGB(200, 200, 220)
		codeBox.Font = Enum.Font.Code
		codeBox.TextSize = 12
		codeBox.TextXAlignment = Enum.TextXAlignment.Left
		codeBox.TextYAlignment = Enum.TextYAlignment.Top
		codeBox.TextWrapped = true
		codeBox.ZIndex = 101
		codeBox.LayoutOrder = 4
		codeBox.Parent = programsScroll

		local codeCorner = Instance.new("UICorner")
		codeCorner.CornerRadius = UDim.new(0, 6)
		codeCorner.Parent = codeBox

		local codePadding = Instance.new("UIPadding")
		codePadding.PaddingTop = UDim.new(0, 8)
		codePadding.PaddingLeft = UDim.new(0, 8)
		codePadding.Parent = codeBox

		-- Load button
		local loadBtn = Instance.new("TextButton")
		loadBtn.Size = UDim2.new(0, 120, 0, 35)
		loadBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
		loadBtn.Text = "LOAD PROGRAM"
		loadBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
		loadBtn.Font = Enum.Font.GothamBold
		loadBtn.TextSize = 13
		loadBtn.ZIndex = 101
		loadBtn.LayoutOrder = 5
		loadBtn.Parent = programsScroll

		local loadCorner = Instance.new("UICorner")
		loadCorner.CornerRadius = UDim.new(0, 6)
		loadCorner.Parent = loadBtn

		loadBtn.MouseButton1Click:Connect(function()
			textBox.Text = prog.code
			updateLineNumbers()
			programsPopup.Visible = false
		end)

		programsScroll.CanvasSize = UDim2.new(0, 0, 0, 30 + 25 + 20 + 25 + codeHeight + 35 + 40)
	end

	-- Show programs list view
	showProgramsList = function()
		-- Clear content
		for _, child in ipairs(programsScroll:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		programsTitle.Text = "PROGRAMS"
		progBackBtn.Visible = false

		local totalHeight = 0
		local layoutOrder = 0

		for _, category in ipairs(ProgramLibrary.categories) do
			local progs = ProgramLibrary.getByCategory(category)
			if #progs > 0 then
				-- Category header
				local catHeader = Instance.new("TextLabel")
				catHeader.Size = UDim2.new(1, 0, 0, 22)
				catHeader.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
				catHeader.Text = "  " .. category .. " (" .. #progs .. ")"
				catHeader.TextColor3 = Color3.fromRGB(100, 200, 255)
				catHeader.Font = Enum.Font.GothamBold
				catHeader.TextSize = 11
				catHeader.TextXAlignment = Enum.TextXAlignment.Left
				catHeader.ZIndex = 101
				catHeader.LayoutOrder = layoutOrder
				catHeader.Parent = programsScroll
				totalHeight = totalHeight + 26
				layoutOrder = layoutOrder + 1

				local catCorner = Instance.new("UICorner")
				catCorner.CornerRadius = UDim.new(0, 4)
				catCorner.Parent = catHeader

				-- Programs in this category
				for _, prog in ipairs(progs) do
					local progBtn = Instance.new("TextButton")
					progBtn.Size = UDim2.new(1, 0, 0, 28)
					progBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
					progBtn.Text = ""
					progBtn.ZIndex = 100
					progBtn.LayoutOrder = layoutOrder
					progBtn.Parent = programsScroll
					totalHeight = totalHeight + 32
					layoutOrder = layoutOrder + 1

					local progBtnCorner = Instance.new("UICorner")
					progBtnCorner.CornerRadius = UDim.new(0, 4)
					progBtnCorner.Parent = progBtn

					local progName = Instance.new("TextLabel")
					progName.Size = UDim2.new(0, 120, 1, 0)
					progName.Position = UDim2.new(0, 8, 0, 0)
					progName.BackgroundTransparency = 1
					progName.Text = prog.name
					progName.TextColor3 = Color3.fromRGB(100, 255, 150)
					progName.Font = Enum.Font.GothamBold
					progName.TextSize = 12
					progName.TextXAlignment = Enum.TextXAlignment.Left
					progName.ZIndex = 101
					progName.Parent = progBtn

					local progDesc = Instance.new("TextLabel")
					progDesc.Size = UDim2.new(1, -140, 1, 0)
					progDesc.Position = UDim2.new(0, 130, 0, 0)
					progDesc.BackgroundTransparency = 1
					progDesc.Text = prog.desc
					progDesc.TextColor3 = Color3.fromRGB(140, 140, 160)
					progDesc.Font = Enum.Font.Gotham
					progDesc.TextSize = 10
					progDesc.TextXAlignment = Enum.TextXAlignment.Left
					progDesc.TextTruncate = Enum.TextTruncate.AtEnd
					progDesc.ZIndex = 101
					progDesc.Parent = progBtn

					progBtn.MouseButton1Click:Connect(function()
						showProgramDetails(prog)
					end)
				end
			end
		end

		programsScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
	end

	-- Back button handler
	progBackBtn.MouseButton1Click:Connect(function()
		showProgramsList()
	end)

	-- Initialize with list view
	showProgramsList()

	examplesBtn.MouseButton1Click:Connect(function()
		if programsPopup.Visible then
			programsPopup.Visible = false
		else
			showProgramsList()
			programsPopup.Visible = true
		end
	end)

	-- Public interface
	panel.frame = frame
	panel.textBox = textBox

	function panel:getText()
		return textBox.Text
	end

	function panel:setText(text)
		textBox.Text = text
		updateLineNumbers()
	end

	function panel:setTextFormatted(text)
		textBox.Text = formatCode(text)
		updateLineNumbers()
	end

	function panel:format()
		textBox.Text = formatCode(textBox.Text)
		updateLineNumbers()
	end

	function panel:setPaused(paused)
		if paused then
			pauseBtn.Text = "PLAY ^2"
			pauseBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
		else
			pauseBtn.Text = "PAUSE ^2"
			pauseBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 60)
		end
	end

	function panel:toggle()
		if frame.Visible then
			textBox:ReleaseFocus()
			frame.Visible = false
		else
			frame.Visible = true
			textBox:CaptureFocus()
		end
	end

	function panel:show()
		frame.Visible = true
		textBox:CaptureFocus()
	end

	function panel:hide()
		textBox:ReleaseFocus()
		frame.Visible = false
	end

	function panel:isVisible()
		return frame.Visible
	end

	function panel:hideExamples()
		programsPopup.Visible = false
	end

	function panel:setGolemMode(isGolemMode, spotId)
		local theme = isGolemMode and THEMES.golem or THEMES.player

		frame.BackgroundColor3 = theme.frameBg
		topBar.BackgroundColor3 = theme.topBarBg
		startBtn.BackgroundColor3 = theme.startBtn

		if isGolemMode then
			modeIndicator.Text = "GOLEM #" .. (spotId or "?")
			modeIndicator.Visible = true
			exitGolemBtn.Visible = true
			sellGolemBtn.Visible = true
			hintsBar.Text = "CONTROLLING GOLEM  |  ^1: Upload  |  SELL: Reclaim 75% scrap"
		else
			modeIndicator.Visible = false
			exitGolemBtn.Visible = false
			sellGolemBtn.Visible = false
			hintsBar.Text = "^Q: Unfocus  |  ^1: Run  |  ^2: Pause  |  ^3: Step"
		end
	end

	function panel:isGolemMode()
		return modeIndicator.Visible
	end

	-- Callbacks for golem mode
	panel.onExitGolem = nil
	panel.onSellGolem = nil

	return panel
end

return EditorPanel
