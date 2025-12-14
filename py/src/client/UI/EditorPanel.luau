local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local DragModule = require(script.Parent.DragModule)
local UITheme = require(script.Parent.UITheme)
local Python = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("Python"))

local EditorPanel = {}
local THEMES = UITheme.THEMES
local COLORS = UITheme.COLORS

local MAX_CHARS = 300
local DEFAULT_RAM = 32
local DEFAULT_CPU_HZ = 1

local function formatCode(source)
	local lines = {}
	for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
		local cleaned = string.gsub(line, "%s+$", "")
		table.insert(lines, cleaned)
	end
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end
	return table.concat(lines, "\n")
end

function EditorPanel.create(parent, callbacks)
	local panel = {}
	callbacks = callbacks or {}

	local currentMode = "player"
	local currentMaxRAM = DEFAULT_RAM
	local currentCpuHz = DEFAULT_CPU_HZ

	local frame = Instance.new("Frame")
	frame.Name = "EditorPanel"
	frame.Size = UDim2.new(0, 380, 0, 260)
	frame.Position = UDim2.new(1, -390, 1, -628)
	frame.BackgroundColor3 = THEMES.player.frameBg
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

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 32)
	topBar.BackgroundColor3 = THEMES.player.headerBg
	topBar.BorderSizePixel = 0
	topBar.Parent = frame

	local topBarCorner = Instance.new("UICorner")
	topBarCorner.CornerRadius = UDim.new(0, 8)
	topBarCorner.Parent = topBar

	DragModule.makeDraggable(frame, topBar)

	local modeIndicator = Instance.new("TextLabel")
	modeIndicator.Name = "ModeIndicator"
	modeIndicator.Size = UDim2.new(0, 80, 0, 20)
	modeIndicator.Position = UDim2.new(0.5, -40, 0, -24)
	modeIndicator.BackgroundColor3 = THEMES.bot.headerBg
	modeIndicator.BackgroundTransparency = 0.2
	modeIndicator.BorderSizePixel = 0
	modeIndicator.Text = ""
	modeIndicator.TextColor3 = THEMES.bot.accent
	modeIndicator.Font = Enum.Font.GothamBold
	modeIndicator.TextSize = 12
	modeIndicator.Visible = false
	modeIndicator.Parent = frame

	local modeCorner = Instance.new("UICorner")
	modeCorner.CornerRadius = UDim.new(0, 6)
	modeCorner.Parent = modeIndicator

	local cpuLabel = Instance.new("TextLabel")
	cpuLabel.Name = "CPULabel"
	cpuLabel.Size = UDim2.new(0, 50, 0, 22)
	cpuLabel.Position = UDim2.new(1, -130, 0, 5)
	cpuLabel.BackgroundColor3 = COLORS.bg
	cpuLabel.BackgroundTransparency = 0.3
	cpuLabel.Text = "1 Hz"
	cpuLabel.TextColor3 = COLORS.success
	cpuLabel.Font = Enum.Font.Code
	cpuLabel.TextSize = 9
	cpuLabel.Parent = topBar

	local cpuCorner = Instance.new("UICorner")
	cpuCorner.CornerRadius = UDim.new(0, 4)
	cpuCorner.Parent = cpuLabel

	local ramLabel = Instance.new("TextLabel")
	ramLabel.Name = "RAMLabel"
	ramLabel.Size = UDim2.new(0, 70, 0, 22)
	ramLabel.Position = UDim2.new(1, -75, 0, 5)
	ramLabel.BackgroundColor3 = COLORS.bg
	ramLabel.BackgroundTransparency = 0.3
	ramLabel.Text = "RAM: 0/32"
	ramLabel.TextColor3 = COLORS.accent
	ramLabel.Font = Enum.Font.Code
	ramLabel.TextSize = 9
	ramLabel.Parent = topBar

	local ramCorner = Instance.new("UICorner")
	ramCorner.CornerRadius = UDim.new(0, 4)
	ramCorner.Parent = ramLabel

	-- SELL and MOVE buttons removed from IDE - now in HUD inspector panel

	local startBtn = Instance.new("TextButton")
	startBtn.Name = "StartBtn"
	startBtn.Size = UDim2.new(0, 50, 0, 22)
	startBtn.Position = UDim2.new(0, 4, 0, 5)
	startBtn.BackgroundColor3 = COLORS.success
	startBtn.Text = "RUN ^1"
	startBtn.TextColor3 = COLORS.text
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
	pauseBtn.BackgroundColor3 = COLORS.warning
	pauseBtn.Text = "PAUSE ^2"
	pauseBtn.TextColor3 = COLORS.text
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
	stepBtn.BackgroundColor3 = COLORS.panel
	stepBtn.Text = "STEP ^3"
	stepBtn.TextColor3 = COLORS.text
	stepBtn.Font = Enum.Font.GothamBold
	stepBtn.TextSize = 9
	stepBtn.Parent = topBar

	local stepBtnCorner = Instance.new("UICorner")
	stepBtnCorner.CornerRadius = UDim.new(0, 4)
	stepBtnCorner.Parent = stepBtn


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
	lineNumbers.TextColor3 = COLORS.subtext
	lineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 14
	lineNumbers.AutomaticSize = Enum.AutomaticSize.Y
	lineNumbers.Parent = lineScroll

	local codeScroll = Instance.new("ScrollingFrame")
	codeScroll.Name = "CodeScroll"
	codeScroll.Size = UDim2.new(1, -35, 1, -82)
	codeScroll.Position = UDim2.new(0, 30, 0, 33)
	codeScroll.BackgroundTransparency = 1
	codeScroll.BorderSizePixel = 0
	codeScroll.ScrollBarThickness = 4
	codeScroll.ScrollBarImageColor3 = COLORS.subtext
	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 500)
	codeScroll.ScrollingEnabled = true
	codeScroll.Parent = frame

	local textBox = Instance.new("TextBox")
	textBox.Name = "CodeInput"
	textBox.Size = UDim2.new(1, -10, 1, 0)
	textBox.Position = UDim2.new(0, 0, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Enter Python code..."
	textBox.PlaceholderColor3 = COLORS.subtext
	textBox.TextColor3 = COLORS.text
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 14
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.TextWrapped = false
	textBox.Parent = codeScroll

	-- Sync line numbers scroll with code scroll
	codeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		lineScroll.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
	end)

	local suggestBar = Instance.new("ScrollingFrame")
	suggestBar.Name = "SuggestBar"
	suggestBar.Size = UDim2.new(1, -6, 0, 20)
	suggestBar.Position = UDim2.new(0, 3, 1, -35)
	suggestBar.BackgroundColor3 = COLORS.bg
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

	local MAX_SUGGESTIONS = 10
	local suggestionBtns = {}
	local suggestionConns = {}
	for i = 1, MAX_SUGGESTIONS do
		local btn = Instance.new("TextButton")
		btn.Name = "Suggest" .. i
		btn.Size = UDim2.new(0, 70, 0, 16)
		btn.BackgroundColor3 = COLORS.panel
		btn.Text = ""
		btn.TextColor3 = COLORS.text
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

	local helpTooltip = Instance.new("TextLabel")
	helpTooltip.Name = "HelpTooltip"
	helpTooltip.Size = UDim2.new(1, -6, 0, 14)
	helpTooltip.Position = UDim2.new(0, 3, 1, -50)
	helpTooltip.BackgroundColor3 = COLORS.panel
	helpTooltip.BackgroundTransparency = 0.1
	helpTooltip.BorderSizePixel = 0
	helpTooltip.Text = ""
	helpTooltip.TextColor3 = COLORS.success
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

	-- Hints bar and old memory label removed - RAM now shown in top bar

	-- Update line numbers and sync canvas sizes
	local LINE_HEIGHT = 16
	local function updateLineNumbers()
		local text = textBox.Text
		local lines = 1
		for _ in string.gmatch(text, "\n") do
			lines = lines + 1
		end
		lines = math.max(lines, 10)
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

	local lastInstructionCount = 0
	local function updateInstructionCount()
		local source = textBox.Text
		if source == "" then
			lastInstructionCount = 0
			panel:setMemoryUsage(0, currentMaxRAM)
			return
		end

		local success, result = pcall(function()
			return Python.compile(source)
		end)

		if success and result and result.instructionCount then
			lastInstructionCount = result.instructionCount
			panel:setMemoryUsage(result.instructionCount, currentMaxRAM)
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
			pauseBtn.BackgroundColor3 = COLORS.success
		else
			pauseBtn.Text = "PAUSE ^2"
			pauseBtn.BackgroundColor3 = COLORS.warning
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

	local currentWeaponName = "BULLET"

	function panel:setMode(mode, spotId, maxRAM, cpuHz)
		currentMode = mode or "player"
		currentMaxRAM = maxRAM or DEFAULT_RAM
		currentCpuHz = cpuHz or DEFAULT_CPU_HZ
		local theme = THEMES[currentMode] or THEMES.player

		frame.BackgroundColor3 = theme.frameBg
		topBar.BackgroundColor3 = theme.headerBg

		panel:setMemoryUsage(0, currentMaxRAM)
		panel:setCpuHz(currentCpuHz)
		updateInstructionCount()

		if currentMode == "player" then
			modeIndicator.Text = currentWeaponName
			modeIndicator.TextColor3 = theme.accent
			modeIndicator.BackgroundColor3 = theme.headerBg
			modeIndicator.Visible = true
			startBtn.Visible = false
			pauseBtn.Visible = true
			stepBtn.Visible = true
			cpuLabel.Visible = false
			ramLabel.Visible = false
			textBox.TextEditable = false
			textBox.Active = false
		elseif currentMode == "golem" then
			modeIndicator.Text = "TURRET #" .. (spotId or "?")
			modeIndicator.TextColor3 = theme.accent
			modeIndicator.BackgroundColor3 = theme.headerBg
			modeIndicator.Visible = true
			startBtn.Visible = true
			startBtn.BackgroundColor3 = COLORS.success
			pauseBtn.Visible = true
			stepBtn.Visible = true
			cpuLabel.Visible = true
			ramLabel.Visible = true
			textBox.TextEditable = true
			textBox.Active = true
		elseif currentMode == "bot" then
			modeIndicator.Text = "BOT #" .. (spotId or "?")
			modeIndicator.TextColor3 = theme.accent
			modeIndicator.BackgroundColor3 = theme.headerBg
			modeIndicator.Visible = true
			startBtn.Visible = true
			startBtn.BackgroundColor3 = COLORS.success
			pauseBtn.Visible = true
			stepBtn.Visible = true
			cpuLabel.Visible = false
			ramLabel.Visible = true
			textBox.TextEditable = true
			textBox.Active = true
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

	function panel:setMemoryUsage(used, max)
		max = max or 32
		used = used or 0
		ramLabel.Text = "RAM: " .. used .. "/" .. max

		local ratio = used / max
		if ratio > 1 then
			ramLabel.TextColor3 = COLORS.danger
		elseif ratio > 0.8 then
			ramLabel.TextColor3 = COLORS.warning
		else
			ramLabel.TextColor3 = COLORS.accent
		end
	end

	function panel:setCpuHz(hz)
		currentCpuHz = hz or DEFAULT_CPU_HZ
		cpuLabel.Text = currentCpuHz .. " Hz"

		if currentCpuHz >= 20 then
			cpuLabel.TextColor3 = COLORS.warning
		elseif currentCpuHz >= 5 then
			cpuLabel.TextColor3 = COLORS.accent
		else
			cpuLabel.TextColor3 = COLORS.success
		end
	end

	function panel:setMaxBytecode(max)
		currentMaxRAM = max or DEFAULT_RAM
		panel:setMemoryUsage(lastInstructionCount, currentMaxRAM)
	end

	-- Callback for exiting golem/bot mode (set by main client)
	panel.onExitGolem = nil

	return panel
end

return EditorPanel
