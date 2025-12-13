-- EditorPanel.luau
-- Simple code editor (no tabs, no word editing)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local DragModule = require(script.Parent.DragModule)
local ProgramLibrary = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("ProgramLibrary"))
local HelpDatabase = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("HelpDatabase"))
local Python = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("Python"))

local EditorPanel = {}

-- Character limit for Machinist programs (forces concise code)
local MAX_CHARS = 300

-- Bytecode instruction limit for bots (forces specialization)
local MAX_BOT_INSTRUCTIONS = 30

-- Clean up Python code (preserve indentation, just trim trailing whitespace)
local function formatCode(source)
	-- Python is indentation-based, so we preserve the structure
	-- Just clean up trailing whitespace on each line
	local lines = {}
	for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
		-- Trim trailing whitespace but preserve leading spaces/tabs
		local cleaned = string.gsub(line, "%s+$", "")
		table.insert(lines, cleaned)
	end

	-- Remove trailing empty lines
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end

	return table.concat(lines, "\n")
end

-- Theme definitions
-- Player = blue/green, Golem (turret) = silver, Bot = orange
local THEMES = {
	player = {
		topBarBg = Color3.fromRGB(40, 40, 55),
		frameBg = Color3.fromRGB(30, 30, 40),
		startBtn = Color3.fromRGB(60, 100, 60),
		accent = Color3.fromRGB(100, 180, 100),
		modeColor = Color3.fromRGB(100, 180, 100),
	},
	golem = {
		-- Silver/grey theme for turrets
		topBarBg = Color3.fromRGB(50, 50, 55),
		frameBg = Color3.fromRGB(35, 35, 40),
		startBtn = Color3.fromRGB(80, 80, 90),
		accent = Color3.fromRGB(180, 180, 200),
		modeColor = Color3.fromRGB(200, 200, 220),
	},
	bot = {
		-- Orange theme for bots
		topBarBg = Color3.fromRGB(55, 40, 25),
		frameBg = Color3.fromRGB(40, 30, 20),
		startBtn = Color3.fromRGB(120, 80, 40),
		accent = Color3.fromRGB(255, 160, 80),
		modeColor = Color3.fromRGB(255, 180, 100),
	}
}

function EditorPanel.create(parent, callbacks)
	local panel = {}
	callbacks = callbacks or {}

	-- Track current mode for filtering examples
	local currentMode = "player" -- "player", "golem", or "bot"

	-- Main frame (compact: ~6 lines of code visible, aligned with debugger below)
	local frame = Instance.new("Frame")
	frame.Name = "EditorPanel"
	frame.Size = UDim2.new(0, 340, 0, 150)  -- Same width as debugger (340px)
	frame.Position = UDim2.new(1, -350, 1, -518)  -- Above debugger: -360 - 150 - 8 gap = -518
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Make frame consume/sink mouse clicks to prevent them from propagating
	-- This prevents clicking on the IDE border from deselecting units
	local inputSink = Instance.new("TextButton")
	inputSink.Name = "InputSink"
	inputSink.Size = UDim2.new(1, 0, 1, 0)
	inputSink.Position = UDim2.new(0, 0, 0, 0)
	inputSink.BackgroundTransparency = 1
	inputSink.Text = ""
	inputSink.ZIndex = 0  -- Behind all other elements
	inputSink.Parent = frame

	-- Top bar (compact)
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 32)
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
	exitGolemBtn.Size = UDim2.new(0, 50, 0, 22)
	exitGolemBtn.Position = UDim2.new(1, -55, 0, 5)  -- Right-aligned
	exitGolemBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 40)
	exitGolemBtn.Text = "EXIT"
	exitGolemBtn.TextColor3 = Color3.fromRGB(255, 180, 120)
	exitGolemBtn.Font = Enum.Font.GothamBold
	exitGolemBtn.TextSize = 9
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

	-- SELL and MOVE buttons removed from IDE - now in HUD inspector panel

	-- Control buttons (compact)
	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartBtn"
	startBtn.Size = UDim2.new(0, 50, 0, 22)
	startBtn.Position = UDim2.new(0, 4, 0, 5)
	startBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
	startBtn.Text = "RUN ^1"
	startBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
	startBtn.Font = Enum.Font.GothamBold
	startBtn.TextSize = 9
	startBtn.Parent = topBar

	local startBtnCorner = Instance.new("UICorner")
	startBtnCorner.CornerRadius = UDim.new(0, 4)
	startBtnCorner.Parent = startBtn

	local pauseBtn = Instance.new("TextButton")
	pauseBtn.Name = "PauseBtn"
	pauseBtn.Size = UDim2.new(0, 55, 0, 22)
	pauseBtn.Position = UDim2.new(0, 58, 0, 5)
	pauseBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 60)
	pauseBtn.Text = "PAUSE ^2"
	pauseBtn.TextColor3 = Color3.fromRGB(255, 220, 200)
	pauseBtn.Font = Enum.Font.GothamBold
	pauseBtn.TextSize = 9
	pauseBtn.Parent = topBar

	local pauseBtnCorner = Instance.new("UICorner")
	pauseBtnCorner.CornerRadius = UDim.new(0, 4)
	pauseBtnCorner.Parent = pauseBtn

	local stepBtn = Instance.new("TextButton")
	stepBtn.Name = "StepBtn"
	stepBtn.Size = UDim2.new(0, 50, 0, 22)
	stepBtn.Position = UDim2.new(0, 117, 0, 5)
	stepBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	stepBtn.Text = "STEP ^3"
	stepBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
	stepBtn.Font = Enum.Font.GothamBold
	stepBtn.TextSize = 9
	stepBtn.Parent = topBar

	local stepBtnCorner = Instance.new("UICorner")
	stepBtnCorner.CornerRadius = UDim.new(0, 4)
	stepBtnCorner.Parent = stepBtn

	local helpBtn = Instance.new("TextButton")
	helpBtn.Name = "HelpBtn"
	helpBtn.Size = UDim2.new(0, 22, 0, 22)
	helpBtn.Position = UDim2.new(0, 171, 0, 5)
	helpBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	helpBtn.Text = "?"
	helpBtn.TextColor3 = Color3.fromRGB(150, 150, 255)
	helpBtn.Font = Enum.Font.GothamBold
	helpBtn.TextSize = 12
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
	examplesBtn.Size = UDim2.new(0, 50, 0, 22)
	examplesBtn.Position = UDim2.new(0, 197, 0, 5)
	examplesBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	examplesBtn.Text = "PROGS"
	examplesBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
	examplesBtn.Font = Enum.Font.GothamBold
	examplesBtn.TextSize = 9
	examplesBtn.Parent = topBar

	local examplesBtnCorner = Instance.new("UICorner")
	examplesBtnCorner.CornerRadius = UDim.new(0, 4)
	examplesBtnCorner.Parent = examplesBtn

	-- Character counter (shows current/max) - hidden by default, only for bot mode
	local charCountLabel = Instance.new("TextLabel")
	charCountLabel.Name = "CharCount"
	charCountLabel.Size = UDim2.new(0, 55, 0, 22)
	charCountLabel.Position = UDim2.new(1, -110, 0, 5)  -- Left of exit button
	charCountLabel.BackgroundTransparency = 1
	charCountLabel.Text = "0/" .. MAX_CHARS
	charCountLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
	charCountLabel.Font = Enum.Font.Code
	charCountLabel.TextSize = 9
	charCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	charCountLabel.Visible = false  -- Only show in bot mode
	charCountLabel.Parent = topBar

	-- Line numbers (inside its own scrolling frame to sync with code)
	local lineScroll = Instance.new("ScrollingFrame")
	lineScroll.Name = "LineScroll"
	lineScroll.Size = UDim2.new(0, 25, 1, -82)  -- Room for top bar + suggestion bar + hints (compact)
	lineScroll.Position = UDim2.new(0, 2, 0, 33)
	lineScroll.BackgroundTransparency = 1
	lineScroll.BorderSizePixel = 0
	lineScroll.ScrollBarThickness = 0 -- Hidden, synced with code scroll
	lineScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	lineScroll.ScrollingEnabled = false -- Controlled by code scroll
	lineScroll.Parent = frame

	local lineNumbers = Instance.new("TextLabel")
	lineNumbers.Name = "LineNumbers"
	lineNumbers.Size = UDim2.new(1, 0, 0, 0)
	lineNumbers.Position = UDim2.new(0, 0, 0, 0)
	lineNumbers.BackgroundTransparency = 1
	lineNumbers.Text = "1\n2\n3\n4\n5\n6\n7\n8"
	lineNumbers.TextColor3 = Color3.fromRGB(100, 100, 120)
	lineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 14
	lineNumbers.AutomaticSize = Enum.AutomaticSize.Y
	lineNumbers.Parent = lineScroll

	-- Code input container (ScrollingFrame for scrolling long programs)
	local codeScroll = Instance.new("ScrollingFrame")
	codeScroll.Name = "CodeScroll"
	codeScroll.Size = UDim2.new(1, -35, 1, -82)  -- Room for top bar + suggestion bar + hints (compact)
	codeScroll.Position = UDim2.new(0, 30, 0, 33)
	codeScroll.BackgroundTransparency = 1
	codeScroll.BorderSizePixel = 0
	codeScroll.ScrollBarThickness = 4
	codeScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 500) -- Will be updated dynamically
	codeScroll.ScrollingEnabled = true
	codeScroll.Parent = frame

	-- Code input (TextBox inside ScrollingFrame)
	local textBox = Instance.new("TextBox")
	textBox.Name = "CodeInput"
	textBox.Size = UDim2.new(1, -10, 1, 0) -- Fill the scroll area
	textBox.Position = UDim2.new(0, 0, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Enter Python code..."
	textBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 100)
	textBox.TextColor3 = Color3.fromRGB(220, 220, 240)
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 14
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.TextWrapped = false -- Allow horizontal overflow
	textBox.Parent = codeScroll

	-- Sync line numbers scroll with code scroll
	codeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		lineScroll.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
	end)

	-- Suggestion bar (autocomplete snippets)
	local suggestBar = Instance.new("ScrollingFrame")
	suggestBar.Name = "SuggestBar"
	suggestBar.Size = UDim2.new(1, -6, 0, 20)
	suggestBar.Position = UDim2.new(0, 3, 1, -35)
	suggestBar.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
	suggestBar.BorderSizePixel = 0
	suggestBar.ScrollBarThickness = 0
	suggestBar.ScrollingDirection = Enum.ScrollingDirection.X
	suggestBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	suggestBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	suggestBar.Parent = frame

	local suggestCorner = Instance.new("UICorner")
	suggestCorner.CornerRadius = UDim.new(0, 4)
	suggestCorner.Parent = suggestBar

	local suggestLayout = Instance.new("UIListLayout")
	suggestLayout.FillDirection = Enum.FillDirection.Horizontal
	suggestLayout.Padding = UDim.new(0, 4)
	suggestLayout.SortOrder = Enum.SortOrder.LayoutOrder
	suggestLayout.Parent = suggestBar

	local suggestPadding = Instance.new("UIPadding")
	suggestPadding.PaddingLeft = UDim.new(0, 4)
	suggestPadding.PaddingTop = UDim.new(0, 2)
	suggestPadding.Parent = suggestBar

	-- Pool of suggestion buttons
	local MAX_SUGGESTIONS = 10
	local suggestionBtns = {}
	local suggestionConns = {}  -- Store click connections separately
	for i = 1, MAX_SUGGESTIONS do
		local btn = Instance.new("TextButton")
		btn.Name = "Suggest" .. i
		btn.Size = UDim2.new(0, 70, 0, 16)
		btn.BackgroundColor3 = Color3.fromRGB(50, 60, 70)
		btn.Text = ""
		btn.TextColor3 = Color3.fromRGB(180, 200, 220)
		btn.Font = Enum.Font.Code
		btn.TextSize = 9
		btn.AutomaticSize = Enum.AutomaticSize.X
		btn.Visible = false
		btn.LayoutOrder = i
		btn.Parent = suggestBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 3)
		btnCorner.Parent = btn

		local btnPadding = Instance.new("UIPadding")
		btnPadding.PaddingLeft = UDim.new(0, 6)
		btnPadding.PaddingRight = UDim.new(0, 6)
		btnPadding.Parent = btn

		suggestionBtns[i] = btn
		suggestionConns[i] = nil
	end

	-- Help tooltip (shows above suggestion bar when 1 match)
	local helpTooltip = Instance.new("TextLabel")
	helpTooltip.Name = "HelpTooltip"
	helpTooltip.Size = UDim2.new(1, -6, 0, 14)
	helpTooltip.Position = UDim2.new(0, 3, 1, -50)
	helpTooltip.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
	helpTooltip.BackgroundTransparency = 0.1
	helpTooltip.BorderSizePixel = 0
	helpTooltip.Text = ""
	helpTooltip.TextColor3 = Color3.fromRGB(150, 200, 150)
	helpTooltip.Font = Enum.Font.Code
	helpTooltip.TextSize = 9
	helpTooltip.TextXAlignment = Enum.TextXAlignment.Left
	helpTooltip.Visible = false
	helpTooltip.Parent = frame

	local helpCorner = Instance.new("UICorner")
	helpCorner.CornerRadius = UDim.new(0, 3)
	helpCorner.Parent = helpTooltip

	local helpPadding = Instance.new("UIPadding")
	helpPadding.PaddingLeft = UDim.new(0, 6)
	helpPadding.Parent = helpTooltip

	-- Program memory indicator (for bots - shows instruction count)
	local memoryLabel = Instance.new("TextLabel")
	memoryLabel.Name = "MemoryLabel"
	memoryLabel.Size = UDim2.new(0, 70, 0, 16)
	memoryLabel.Position = UDim2.new(1, -75, 1, -33)
	memoryLabel.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
	memoryLabel.BackgroundTransparency = 0.3
	memoryLabel.Text = "RAM: 0/30"
	memoryLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	memoryLabel.Font = Enum.Font.Code
	memoryLabel.TextSize = 9
	memoryLabel.Visible = false  -- Only visible in bot mode
	memoryLabel.Parent = frame

	local memoryCorner = Instance.new("UICorner")
	memoryCorner.CornerRadius = UDim.new(0, 4)
	memoryCorner.Parent = memoryLabel

	-- Hints bar
	local hintsBar = Instance.new("TextLabel")
	hintsBar.Name = "HintsBar"
	hintsBar.Size = UDim2.new(1, -6, 0, 13)
	hintsBar.Position = UDim2.new(0, 3, 1, -14)
	hintsBar.BackgroundTransparency = 1
	hintsBar.Text = "^Q: Unfocus  |  ^1: Run  |  ^2: Pause  |  ^3: Step"
	hintsBar.TextColor3 = Color3.fromRGB(90, 90, 110)
	hintsBar.Font = Enum.Font.Code
	hintsBar.TextSize = 9
	hintsBar.Parent = frame

	-- Update line numbers and sync canvas sizes
	local LINE_HEIGHT = 16 -- Approximate height per line at TextSize 14
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

		-- Calculate required canvas height based on line count
		local requiredHeight = (lines + 2) * LINE_HEIGHT
		local viewportHeight = codeScroll.AbsoluteSize.Y
		local canvasHeight = math.max(requiredHeight, viewportHeight)

		-- Update canvas sizes
		codeScroll.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
		lineScroll.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)

		-- Update textbox size to fill canvas
		textBox.Size = UDim2.new(1, -10, 0, canvasHeight)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateLineNumbers)

	-- Character count update
	local function updateCharCount()
		local text = textBox.Text
		local len = #text
		charCountLabel.Text = len .. "/" .. MAX_CHARS

		if len > MAX_CHARS then
			-- Over limit: red text, disable run
			charCountLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			startBtn.Active = false
			startBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			startBtn.Text = "LONG!"
		else
			-- Under limit: gray text, enable run
			charCountLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
			startBtn.Active = true
			startBtn.BackgroundColor3 = THEMES[currentMode].startBtn
			startBtn.Text = "RUN ^1"
		end
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateCharCount)

	-- Update instruction count for bot memory display
	local lastInstructionCount = 0
	local function updateInstructionCount()
		if currentMode ~= "bot" then return end

		local source = textBox.Text
		if source == "" then
			lastInstructionCount = 0
			panel:setMemoryUsage(0, MAX_BOT_INSTRUCTIONS)
			return
		end

		-- Try to compile to get instruction count
		local success, result = pcall(function()
			return Python.compile(source)
		end)

		if success and result and result.instructionCount then
			lastInstructionCount = result.instructionCount
			panel:setMemoryUsage(result.instructionCount, MAX_BOT_INSTRUCTIONS)
		end
	end

	-- Debounce the instruction count update (don't compile on every keystroke)
	local instructionUpdatePending = false
	local function scheduleInstructionUpdate()
		if instructionUpdatePending then return end
		instructionUpdatePending = true
		task.delay(0.5, function()
			instructionUpdatePending = false
			updateInstructionCount()
		end)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(scheduleInstructionUpdate)

	-- =====================================================
	-- AUTOCOMPLETE SYSTEM WITH HELP
	-- Generated from actual API methods, uses trie for prefix matching
	-- Each entry has: word, snippet, help (signature + description)
	-- =====================================================

	-- Keywords (no prefix needed)
	local KEYWORDS = {
		{word = "while", snippet = "while True:\n    ", help = "while condition: | Loop while true"},
		{word = "if", snippet = "if :\n    ", help = "if condition: | Conditional branch"},
		{word = "elif", snippet = "elif :\n    ", help = "elif condition: | Else-if branch"},
		{word = "else", snippet = "else:\n    ", help = "else: | Default branch"},
		{word = "for", snippet = "for i in range():\n    ", help = "for var in list: | Loop over items"},
		{word = "def", snippet = "def ():\n    ", help = "def name(args): | Define function"},
		{word = "return", snippet = "return ", help = "return value | Exit function"},
		{word = "True", snippet = "True", help = "True | Boolean true"},
		{word = "False", snippet = "False", help = "False | Boolean false"},
		{word = "None", snippet = "None", help = "None | No value"},
		{word = "and", snippet = "and ", help = "a and b | Both must be true"},
		{word = "or", snippet = "or ", help = "a or b | Either can be true"},
		{word = "not", snippet = "not ", help = "not a | Invert boolean"},
		{word = "in", snippet = "in ", help = "x in list | Check membership"},
	}

	-- Global functions (no prefix needed)
	local GLOBALS = {
		{word = "print", snippet = "print()", help = "print(value, ...) | Output to console"},
		{word = "len", snippet = "len()", help = "len(list) -> int | Get length"},
		{word = "range", snippet = "range()", help = "range(n) or range(start,end) | Number sequence"},
		{word = "abs", snippet = "abs()", help = "abs(x) -> num | Absolute value"},
		{word = "min", snippet = "min()", help = "min(a, b, ...) -> num | Smallest value"},
		{word = "max", snippet = "max()", help = "max(a, b, ...) -> num | Largest value"},
		{word = "int", snippet = "int()", help = "int(x) -> int | Convert to integer"},
		{word = "str", snippet = "str()", help = "str(x) -> str | Convert to string"},
		{word = "wait", snippet = "wait(1)", help = "wait(seconds) | Pause execution"},
	}

	-- Golem-specific globals (turret mode only)
	local GOLEM_GLOBALS = {
		{word = "nearest", snippet = "nearest()", help = "nearest() -> enemy | Closest enemy"},
		{word = "weakest", snippet = "weakest()", help = "weakest() -> enemy | Lowest HP enemy"},
		{word = "strongest", snippet = "strongest()", help = "strongest() -> enemy | Highest HP enemy"},
	}

	-- Methods available on self/B1-B4/T1-T4 proxies
	-- These get suggested when user types "self.", "B1.", "T1.", etc.
	local BOT_METHODS = {
		-- Movement (turtle style)
		{word = "forward", snippet = "forward(10)", help = "forward(dist) | Move forward"},
		{word = "backward", snippet = "backward(10)", help = "backward(dist) | Move backward"},
		{word = "left", snippet = "left(90)", help = "left(degrees) | Turn left"},
		{word = "right", snippet = "right(90)", help = "right(degrees) | Turn right"},
		{word = "goto", snippet = "goto(T1)", help = "goto(target) | Move to T1/B1/pos"},
		{word = "move", snippet = "move(0, 0)", help = "move(x, z) | Move to coords"},
		{word = "stop", snippet = "stop()", help = "stop() | Cancel movement"},
		{word = "flee", snippet = "flee()", help = "flee() | Run to core"},
		{word = "go_home", snippet = "go_home()", help = "go_home() | Return to core"},
		-- State queries
		{word = "position", snippet = "position()", help = "position() -> [x,z] | Get location"},
		{word = "cargo", snippet = "cargo()", help = "cargo() -> int | Scrap carried"},
		{word = "max_cargo", snippet = "max_cargo()", help = "max_cargo() -> int | Max capacity"},
		{word = "is_full", snippet = "is_full()", help = "is_full() -> bool | Inventory full?"},
		{word = "is_idle", snippet = "is_idle()", help = "is_idle() -> bool | Not busy?"},
		{word = "is_moving", snippet = "is_moving()", help = "is_moving() -> bool | Walking?"},
		{word = "alive", snippet = "alive()", help = "alive() -> bool | Bot exists?"},
		{word = "exists", snippet = "exists()", help = "exists() -> bool | Unit exists?"},
		{word = "status", snippet = "status()", help = "status() -> str | Current state"},
		{word = "spot", snippet = "spot()", help = "spot() -> int | Spawn slot (1-4)"},
		-- Collection & Supply
		{word = "scraps", snippet = "scraps()", help = "scraps() -> list | All scrap, nearest first"},
		{word = "collect", snippet = "collect(s[0])", help = "collect(scrap) | Pick up scrap"},
		{word = "supply", snippet = "supply(T1)", help = "supply(turret) | Give ammo to turret"},
		{word = "scan", snippet = "scan()", help = "scan() -> [x,z] | Find nearest scrap"},
		-- Personality
		{word = "say", snippet = "say('')", help = "say(msg) | Show chat bubble"},
		{word = "color", snippet = "color('cyan')", help = "color(name) | red/blue/green/cyan/..."},
		{word = "dance", snippet = "dance()", help = "dance() | Spin animation"},
		{word = "jump", snippet = "jump()", help = "jump() | Hop animation"},
		{word = "shake", snippet = "shake()", help = "shake() | Shiver animation"},
		{word = "emote", snippet = "emote('happy')", help = "emote(type) | happy/panic/spin"},
		-- Combat
		{word = "shield", snippet = "shield()", help = "shield(sec) | Activate shield"},
		{word = "shielded", snippet = "shielded()", help = "shielded() -> bool | Shield active?"},
		{word = "shield_ready", snippet = "shield_ready()", help = "shield_ready() -> bool | Can shield?"},
		{word = "zap", snippet = "zap()", help = "zap() | Shock nearby enemy"},
		{word = "attack", snippet = "attack()", help = "attack() | Attack nearest"},
		{word = "explode", snippet = "explode()", help = "explode() | Kamikaze! Bot dies"},
		{word = "danger", snippet = "danger()", help = "danger() -> int | Dist to enemy"},
		{word = "distance", snippet = "distance(T1)", help = "distance(target) -> int | Dist to target"},
		-- Sensors
		{word = "enemies_nearby", snippet = "enemies_nearby()", help = "enemies_nearby(range) -> int | Count enemies"},
		{word = "scrap_nearby", snippet = "scrap_nearby()", help = "scrap_nearby(range) -> bool | Scrap in range?"},
		-- Utility
		{word = "wait", snippet = "wait(1)", help = "wait(sec) | Pause bot"},
		{word = "methods", snippet = "methods()", help = "methods() -> list | List all methods"},
	}

	local TURRET_METHODS = {
		-- State
		{word = "exists", snippet = "exists()", help = "exists() -> bool | Turret exists?"},
		{word = "alive", snippet = "alive()", help = "alive() -> bool | Turret exists?"},
		{word = "spot", snippet = "spot()", help = "spot() -> int | Slot number (1-4)"},
		{word = "id", snippet = "id()", help = "id() -> str | Unique ID"},
		{word = "position", snippet = "position()", help = "position() -> [x,z] | Location"},
		{word = "ammo", snippet = "ammo()", help = "ammo() -> int | Current ammo"},
		{word = "max_ammo", snippet = "max_ammo()", help = "max_ammo() -> int | Max ammo"},
		{word = "range", snippet = "range()", help = "range() -> int | Attack range"},
		{word = "is_empty", snippet = "is_empty()", help = "is_empty() -> bool | No ammo?"},
		{word = "ammo_ratio", snippet = "ammo_ratio()", help = "ammo_ratio() -> float | 0.0-1.0"},
		-- Commands
		{word = "set_range", snippet = "set_range(30)", help = "set_range(10-60) | Low=damage, high=reach"},
		{word = "scan", snippet = "scan()", help = "scan() -> list | Enemies in range"},
		{word = "fire", snippet = "fire(BULLET)", help = "fire(type) | BULLET/ROCKET/LASER/ICE"},
		{word = "danger", snippet = "danger()", help = "danger() -> int | Dist to enemy"},
		{word = "methods", snippet = "methods()", help = "methods() -> list | List all methods"},
	}

	-- Player self methods (subset of bot methods)
	local PLAYER_SELF_METHODS = {
		{word = "forward", snippet = "forward(10)", help = "forward(dist) | Walk forward"},
		{word = "backward", snippet = "backward(10)", help = "backward(dist) | Walk backward"},
		{word = "left", snippet = "left(90)", help = "left(degrees) | Turn left"},
		{word = "right", snippet = "right(90)", help = "right(degrees) | Turn right"},
		{word = "goto", snippet = "goto(T1)", help = "goto(target) | Walk to T1/B1"},
		{word = "position", snippet = "position()", help = "position() -> [x,z] | Your location"},
		{word = "cargo", snippet = "cargo()", help = "cargo() -> int | Scrap carried"},
		{word = "max_cargo", snippet = "max_cargo()", help = "max_cargo() -> int | Max capacity"},
		{word = "is_full", snippet = "is_full()", help = "is_full() -> bool | Inventory full?"},
		{word = "scraps", snippet = "scraps()", help = "scraps() -> list | All scrap"},
		{word = "collect", snippet = "collect(s[0])", help = "collect(scrap) | Pick up scrap"},
		{word = "supply", snippet = "supply(T1)", help = "supply(turret) | Give ammo"},
		{word = "hit", snippet = "hit()", help = "hit() -> bool | Melee attack"},
	}

	-- Golem self methods (when editing turret code)
	local GOLEM_SELF_METHODS = {
		{word = "scan", snippet = "scan()", help = "scan() -> list | Enemies in range"},
		{word = "fire", snippet = "fire(BULLET)", help = "fire(type) | BULLET/ROCKET/LASER/ICE"},
		{word = "ammo", snippet = "ammo()", help = "ammo() -> int | Current ammo"},
		{word = "max_ammo", snippet = "max_ammo()", help = "max_ammo() -> int | Max ammo"},
		{word = "range", snippet = "range()", help = "range() -> int | Attack range"},
		{word = "set_range", snippet = "set_range(30)", help = "set_range(10-60) | Low=damage, high=reach"},
		{word = "is_empty", snippet = "is_empty()", help = "is_empty() -> bool | No ammo?"},
		{word = "position", snippet = "position()", help = "position() -> [x,z] | Location"},
		{word = "danger", snippet = "danger()", help = "danger() -> int | Dist to enemy"},
	}

	-- Valid object prefixes (what can come before the dot)
	local OBJECT_PREFIXES = {"self", "B1", "B2", "B3", "B4", "T1", "T2", "T3", "T4", "CORE"}

	-- Constants
	local CONSTANTS = {
		{word = "BULLET", snippet = "BULLET", help = "BULLET = 1 | Fast, cheap ammo"},
		{word = "ROCKET", snippet = "ROCKET", help = "ROCKET = 2 | Slow, splash damage"},
		{word = "LASER", snippet = "LASER", help = "LASER = 3 | High damage, fast"},
		{word = "ICE", snippet = "ICE", help = "ICE = 4 | Slows enemies 60%"},
		{word = "FREEZE", snippet = "FREEZE", help = "FREEZE = 5 | No damage, slows"},
		{word = "T1", snippet = "T1", help = "T1 | Turret slot 1"},
		{word = "T2", snippet = "T2", help = "T2 | Turret slot 2"},
		{word = "T3", snippet = "T3", help = "T3 | Turret slot 3"},
		{word = "T4", snippet = "T4", help = "T4 | Turret slot 4"},
		{word = "B1", snippet = "B1", help = "B1 | Bot slot 1"},
		{word = "B2", snippet = "B2", help = "B2 | Bot slot 2"},
		{word = "B3", snippet = "B3", help = "B3 | Bot slot 3"},
		{word = "B4", snippet = "B4", help = "B4 | Bot slot 4"},
		{word = "CORE", snippet = "CORE", help = "CORE | Base to defend"},
	}

	-- Build a simple trie for prefix matching
	local function buildTrie(items)
		local trie = {children = {}, items = {}}
		for _, item in ipairs(items) do
			local node = trie
			for i = 1, #item.word do
				local c = item.word:sub(i, i):lower()
				if not node.children[c] then
					node.children[c] = {children = {}, items = {}}
				end
				node = node.children[c]
			end
			table.insert(node.items, item)
		end
		return trie
	end

	-- Search trie for all items matching prefix
	local function searchTrie(trie, prefix)
		local node = trie
		for i = 1, #prefix do
			local c = prefix:sub(i, i):lower()
			if not node.children[c] then
				return {}
			end
			node = node.children[c]
		end
		-- Collect all items in subtree
		local results = {}
		local function collect(n)
			for _, item in ipairs(n.items) do
				table.insert(results, item)
			end
			for _, child in pairs(n.children) do
				collect(child)
			end
		end
		collect(node)
		return results
	end

	-- Build tries for each category
	local keywordTrie = buildTrie(KEYWORDS)
	local globalTrie = buildTrie(GLOBALS)
	local golemGlobalTrie = buildTrie(GOLEM_GLOBALS)
	local constantTrie = buildTrie(CONSTANTS)
	local botMethodTrie = buildTrie(BOT_METHODS)
	local turretMethodTrie = buildTrie(TURRET_METHODS)
	local playerSelfTrie = buildTrie(PLAYER_SELF_METHODS)
	local golemSelfTrie = buildTrie(GOLEM_SELF_METHODS)

	-- Parse the current context from text
	local function getCurrentContext(text)
		-- Check for object.method pattern: self.for, B1.sc, T2.fi, etc.
		local obj, word = text:match("([%w_]+)%.([%w_]*)$")
		if obj then
			-- Check if it's a valid object prefix
			for _, prefix in ipairs(OBJECT_PREFIXES) do
				if obj == prefix then
					return obj, word:lower(), #obj + 1 + #word
				end
			end
		end

		-- Check for s[ pattern (list indexing)
		local listVar, idx = text:match("([%w_]+)%[(%d*)$")
		if listVar then
			return "list[", idx, #listVar + 1 + #idx
		end

		-- No special prefix - just get last word
		local lastWord = text:match("([%w_]+)$") or ""
		return nil, lastWord:lower(), #lastWord
	end

	-- Get appropriate methods for an object
	local function getMethodsForObject(obj)
		if obj == "self" then
			if currentMode == "golem" then
				return golemSelfTrie
			elseif currentMode == "player" then
				return playerSelfTrie
			else -- bot
				return botMethodTrie
			end
		elseif obj:match("^B%d$") then
			return botMethodTrie
		elseif obj:match("^T%d$") then
			return turretMethodTrie
		elseif obj == "CORE" then
			-- CORE only has position() and hp()
			return buildTrie({{word = "position", snippet = "position()"}, {word = "hp", snippet = "hp()"}})
		end
		return nil
	end

	-- Update suggestions based on current input
	local function updateSuggestions()
		local text = textBox.Text
		local obj, currentWord, totalLen = getCurrentContext(text)

		-- Hide all buttons first
		for i = 1, MAX_SUGGESTIONS do
			suggestionBtns[i].Visible = false
		end

		-- Collect matches
		local matches = {}

		if obj then
			-- Object.method context
			if obj == "list[" then
				-- List indexing - suggest 0]
				if currentWord == "" or ("0"):sub(1, #currentWord) == currentWord then
					table.insert(matches, {word = "0", snippet = "0]", prefix = obj, help = "list[0] | First item in list"})
				end
			else
				-- Get methods for this object type
				local methodTrie = getMethodsForObject(obj)
				if methodTrie then
					local results = searchTrie(methodTrie, currentWord)
					for _, item in ipairs(results) do
						table.insert(matches, {
							word = item.word,
							snippet = item.snippet,
							help = item.help,
							prefix = obj .. "."
						})
						if #matches >= MAX_SUGGESTIONS then break end
					end
				end
			end
		else
			-- No object prefix - search keywords, globals, constants
			if #currentWord >= 2 then
				-- Keywords
				for _, item in ipairs(searchTrie(keywordTrie, currentWord)) do
					table.insert(matches, {word = item.word, snippet = item.snippet, help = item.help})
					if #matches >= MAX_SUGGESTIONS then break end
				end
				-- Globals
				if #matches < MAX_SUGGESTIONS then
					for _, item in ipairs(searchTrie(globalTrie, currentWord)) do
						table.insert(matches, {word = item.word, snippet = item.snippet, help = item.help})
						if #matches >= MAX_SUGGESTIONS then break end
					end
				end
				-- Golem-specific globals
				if currentMode == "golem" and #matches < MAX_SUGGESTIONS then
					for _, item in ipairs(searchTrie(golemGlobalTrie, currentWord)) do
						table.insert(matches, {word = item.word, snippet = item.snippet, help = item.help})
						if #matches >= MAX_SUGGESTIONS then break end
					end
				end
				-- Constants
				if #matches < MAX_SUGGESTIONS then
					for _, item in ipairs(searchTrie(constantTrie, currentWord)) do
						table.insert(matches, {word = item.word, snippet = item.snippet, help = item.help})
						if #matches >= MAX_SUGGESTIONS then break end
					end
				end
			end
		end

		-- Show matching buttons
		for i, match in ipairs(matches) do
			local btn = suggestionBtns[i]
			local displayText = match.snippet:gsub("\n.*", "...")
			if match.prefix then
				displayText = match.prefix .. displayText
			end
			btn.Text = displayText
			btn.Visible = true

			-- Disconnect old handler and set new one
			if suggestionConns[i] then suggestionConns[i]:Disconnect() end
			suggestionConns[i] = btn.MouseButton1Click:Connect(function()
				local beforeWord = text:sub(1, #text - totalLen)
				local insertText = match.snippet
				if match.prefix then
					insertText = match.prefix .. insertText
				end
				textBox.Text = beforeWord .. insertText
				textBox.CursorPosition = #textBox.Text + 1
				textBox:CaptureFocus()
			end)
		end

		-- Show help tooltip when there are few matches (1-3) with help text
		if #matches >= 1 and #matches <= 3 then
			local helpTexts = {}
			for _, m in ipairs(matches) do
				if m.help then
					table.insert(helpTexts, m.help)
				end
			end
			if #helpTexts > 0 then
				helpTooltip.Text = table.concat(helpTexts, "  |  ")
				helpTooltip.Visible = true
			else
				helpTooltip.Visible = false
			end
		else
			helpTooltip.Visible = false
		end
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateSuggestions)

	-- Button handlers
	startBtn.MouseButton1Click:Connect(function()
		-- Check character limit
		if #textBox.Text > MAX_CHARS then
			return  -- Don't run if over limit
		end
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

	-- Show programs list view (filtered by current mode)
	showProgramsList = function()
		-- Clear content
		for _, child in ipairs(programsScroll:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		-- Update title based on mode
		local modeTitle = currentMode:upper() .. " PROGRAMS"
		programsTitle.Text = modeTitle
		progBackBtn.Visible = false

		-- Get theme colors
		local theme = THEMES[currentMode] or THEMES.player

		local totalHeight = 0
		local layoutOrder = 0

		-- Get programs for current target type
		local relevantProgs = ProgramLibrary.getByTarget(currentMode)

		-- Group by category
		local categories = {}
		for _, prog in ipairs(relevantProgs) do
			local cat = prog.category
			if not categories[cat] then
				categories[cat] = {}
			end
			table.insert(categories[cat], prog)
		end

		-- Display by category
		for _, category in ipairs(ProgramLibrary.categories) do
			local progs = categories[category]
			if progs and #progs > 0 then
				-- Category header
				local catHeader = Instance.new("TextLabel")
				catHeader.Size = UDim2.new(1, 0, 0, 22)
				catHeader.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
				catHeader.Text = "  " .. category .. " (" .. #progs .. ")"
				catHeader.TextColor3 = theme.accent
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
					progName.TextColor3 = theme.accent
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

	-- Track current weapon for player mode indicator
	local currentWeaponName = "BULLET"

	-- Generic mode setter: "player", "golem", or "bot"
	function panel:setMode(mode, spotId)
		currentMode = mode or "player"
		local theme = THEMES[currentMode] or THEMES.player

		frame.BackgroundColor3 = theme.frameBg
		topBar.BackgroundColor3 = theme.topBarBg

		if currentMode == "player" then
			-- Player mode: READ-ONLY but with debugger controls
			modeIndicator.Text = "WEAPON: " .. currentWeaponName
			modeIndicator.TextColor3 = theme.modeColor
			modeIndicator.BackgroundColor3 = theme.topBarBg
			modeIndicator.Visible = true
			exitGolemBtn.Visible = false  -- Can't exit player mode
			startBtn.Visible = false  -- No RUN - weapons auto-run
			pauseBtn.Visible = true   -- Can pause weapon
			stepBtn.Visible = true    -- Can step through
			memoryLabel.Visible = false
			charCountLabel.Visible = false  -- No char limit for weapons
			examplesBtn.Visible = false  -- No PROGS for player
			textBox.TextEditable = false  -- READ-ONLY (change weapons with 1-4)
			textBox.Active = false  -- Prevent focus/click capture so WASD still works
			hintsBar.Text = "READ-ONLY  |  1-4: Switch Weapon  |  ^2: Pause  |  ^3: Step"
		elseif currentMode == "golem" then
			-- Turret mode: READ-ONLY (view code, can't edit)
			modeIndicator.Text = "TURRET #" .. (spotId or "?") .. " (READ-ONLY)"
			modeIndicator.TextColor3 = theme.modeColor
			modeIndicator.BackgroundColor3 = theme.topBarBg
			modeIndicator.Visible = true
			exitGolemBtn.Visible = true
			-- Hide run/pause/step - turrets are read-only
			startBtn.Visible = false
			pauseBtn.Visible = false
			stepBtn.Visible = true  -- Allow stepping to see bytecode execution
			memoryLabel.Visible = false
			charCountLabel.Visible = false  -- No char limit for turrets
			examplesBtn.Visible = false  -- No PROGS for turrets
			textBox.TextEditable = false  -- READ-ONLY
			textBox.Active = false  -- Prevent focus/click capture so WASD still works
			hintsBar.Text = "READ-ONLY  |  Use panel buttons to MOVE/SELL"
		elseif currentMode == "bot" then
			-- Bot mode: FULL PROGRAMMING
			modeIndicator.Text = "BOT #" .. (spotId or "?")
			modeIndicator.TextColor3 = theme.modeColor
			modeIndicator.BackgroundColor3 = theme.topBarBg
			modeIndicator.Visible = true
			exitGolemBtn.Visible = true
			startBtn.Visible = true
			startBtn.BackgroundColor3 = theme.startBtn
			pauseBtn.Visible = true
			stepBtn.Visible = true
			memoryLabel.Visible = true  -- Show memory usage for bots
			charCountLabel.Visible = true  -- Show char limit for bots
			examplesBtn.Visible = true  -- Show PROGS for bots only
			textBox.TextEditable = true
			textBox.Active = true  -- Allow focus/editing for bot programming
			hintsBar.Text = "BOT PROGRAMMING  |  ^1: Run  |  ^2: Pause  |  ^3: Step"
		end
	end

	-- Backwards compatibility
	function panel:setGolemMode(isGolemMode, spotId)
		if isGolemMode then
			panel:setMode("golem", spotId)
		else
			panel:setMode("player")
		end
	end

	function panel:isGolemMode()
		return currentMode == "golem"
	end

	function panel:isBotMode()
		return currentMode == "bot"
	end

	function panel:getMode()
		return currentMode
	end

	-- Update weapon name in player mode indicator
	function panel:setWeaponName(name)
		currentWeaponName = name or "BULLET"
		if currentMode == "player" then
			modeIndicator.Text = "WEAPON: " .. currentWeaponName
		end
	end

	-- Update memory display (instruction count)
	function panel:setMemoryUsage(used, max)
		max = max or 30
		used = used or 0
		memoryLabel.Text = "RAM: " .. used .. "/" .. max

		-- Color based on usage
		local ratio = used / max
		if ratio > 1 then
			memoryLabel.TextColor3 = Color3.fromRGB(255, 80, 80)  -- Red: over limit
		elseif ratio > 0.8 then
			memoryLabel.TextColor3 = Color3.fromRGB(255, 200, 80)  -- Yellow: near limit
		else
			memoryLabel.TextColor3 = Color3.fromRGB(100, 200, 255)  -- Cyan: OK
		end
	end

	-- Callbacks for golem/bot mode
	panel.onExitGolem = nil

	return panel
end

return EditorPanel
