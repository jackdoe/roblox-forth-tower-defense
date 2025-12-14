local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DragModule = require(script.Parent.DragModule)
local UITheme = require(script.Parent.UITheme)
local Python = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("Python"))
local Classes = Python.Classes

local EditorPanel = {}
local THEMES = UITheme.THEMES
local COLORS = UITheme.COLORS

local MAX_CHARS = 300
local DEFAULT_MAX_BYTECODE = 128

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
	local currentMaxBytecode = DEFAULT_MAX_BYTECODE
	local hasCompileError = true
	local currentSelfType = nil
	local currentEnvTypes = {}

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

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0, 80, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "EDITOR"
	titleLabel.TextColor3 = COLORS.text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.Code
	titleLabel.TextSize = 12
	titleLabel.Parent = topBar

	local compileStatusBar = Instance.new("Frame")
	compileStatusBar.Name = "CompileStatusBar"
	compileStatusBar.Size = UDim2.new(1, -6, 0, 18)
	compileStatusBar.Position = UDim2.new(0, 3, 1, -48)
	compileStatusBar.BackgroundColor3 = COLORS.bg
	compileStatusBar.BorderSizePixel = 0
	compileStatusBar.Parent = frame

	local compileStatusCorner = Instance.new("UICorner")
	compileStatusCorner.CornerRadius = UDim.new(0, 4)
	compileStatusCorner.Parent = compileStatusBar

	local bytecodeLabel = Instance.new("TextLabel")
	bytecodeLabel.Name = "BytecodeLabel"
	bytecodeLabel.Size = UDim2.new(0, 60, 1, 0)
	bytecodeLabel.Position = UDim2.new(0, 4, 0, 0)
	bytecodeLabel.BackgroundTransparency = 1
	bytecodeLabel.Text = "0 bytes"
	bytecodeLabel.TextColor3 = COLORS.success
	bytecodeLabel.TextXAlignment = Enum.TextXAlignment.Left
	bytecodeLabel.Font = Enum.Font.Code
	bytecodeLabel.TextSize = 10
	bytecodeLabel.Parent = compileStatusBar

	local compileErrorLabel = Instance.new("TextLabel")
	compileErrorLabel.Name = "CompileError"
	compileErrorLabel.Size = UDim2.new(1, -70, 1, 0)
	compileErrorLabel.Position = UDim2.new(0, 65, 0, 0)
	compileErrorLabel.BackgroundTransparency = 1
	compileErrorLabel.Text = ""
	compileErrorLabel.TextColor3 = COLORS.danger
	compileErrorLabel.TextXAlignment = Enum.TextXAlignment.Left
	compileErrorLabel.TextTruncate = Enum.TextTruncate.AtEnd
	compileErrorLabel.Font = Enum.Font.Code
	compileErrorLabel.TextSize = 10
	compileErrorLabel.Parent = compileStatusBar

	local actionBar = Instance.new("Frame")
	actionBar.Name = "ActionBar"
	actionBar.Size = UDim2.new(1, 0, 0, 30)
	actionBar.Position = UDim2.new(0, 0, 1, -30)
	actionBar.BackgroundColor3 = THEMES.player.headerBg
	actionBar.BorderSizePixel = 0
	actionBar.Parent = frame

	local actionBarCorner = Instance.new("UICorner")
	actionBarCorner.CornerRadius = UDim.new(0, 8)
	actionBarCorner.Parent = actionBar

	local compileBtn = Instance.new("TextButton")
	compileBtn.Name = "CompileBtn"
	compileBtn.Size = UDim2.new(0, 100, 0, 22)
	compileBtn.Position = UDim2.new(0, 6, 0, 4)
	compileBtn.BackgroundColor3 = COLORS.success
	compileBtn.Text = "COMPILE & RUN"
	compileBtn.TextColor3 = COLORS.text
	compileBtn.Font = Enum.Font.GothamBold
	compileBtn.TextSize = 9
	compileBtn.Parent = actionBar

	local compileBtnCorner = Instance.new("UICorner")
	compileBtnCorner.CornerRadius = UDim.new(0, 4)
	compileBtnCorner.Parent = compileBtn

	local buyCpuBtn = Instance.new("TextButton")
	buyCpuBtn.Name = "BuyCpuBtn"
	buyCpuBtn.Size = UDim2.new(0, 60, 0, 22)
	buyCpuBtn.Position = UDim2.new(0, 112, 0, 4)
	buyCpuBtn.BackgroundColor3 = COLORS.accent
	buyCpuBtn.Text = "BUY CPU"
	buyCpuBtn.TextColor3 = COLORS.text
	buyCpuBtn.Font = Enum.Font.GothamBold
	buyCpuBtn.TextSize = 9
	buyCpuBtn.Visible = false
	buyCpuBtn.Parent = actionBar

	local buyCpuBtnCorner = Instance.new("UICorner")
	buyCpuBtnCorner.CornerRadius = UDim.new(0, 4)
	buyCpuBtnCorner.Parent = buyCpuBtn

	local buyRamBtn = Instance.new("TextButton")
	buyRamBtn.Name = "BuyRamBtn"
	buyRamBtn.Size = UDim2.new(0, 60, 0, 22)
	buyRamBtn.Position = UDim2.new(0, 178, 0, 4)
	buyRamBtn.BackgroundColor3 = COLORS.accent
	buyRamBtn.Text = "BUY RAM"
	buyRamBtn.TextColor3 = COLORS.text
	buyRamBtn.Font = Enum.Font.GothamBold
	buyRamBtn.TextSize = 9
	buyRamBtn.Visible = false
	buyRamBtn.Parent = actionBar

	local buyRamBtnCorner = Instance.new("UICorner")
	buyRamBtnCorner.CornerRadius = UDim.new(0, 4)
	buyRamBtnCorner.Parent = buyRamBtn

	local resetBtn = Instance.new("TextButton")
	resetBtn.Name = "ResetBtn"
	resetBtn.Size = UDim2.new(0, 50, 0, 22)
	resetBtn.Position = UDim2.new(0, 112, 0, 4)
	resetBtn.BackgroundColor3 = COLORS.warning or Color3.fromRGB(200, 150, 50)
	resetBtn.Text = "RESET"
	resetBtn.TextColor3 = COLORS.text
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 9
	resetBtn.Visible = true
	resetBtn.Parent = actionBar

	local resetBtnCorner = Instance.new("UICorner")
	resetBtnCorner.CornerRadius = UDim.new(0, 4)
	resetBtnCorner.Parent = resetBtn

	local sellBtn = Instance.new("TextButton")
	sellBtn.Name = "SellBtn"
	sellBtn.Size = UDim2.new(0, 50, 0, 22)
	sellBtn.Position = UDim2.new(1, -56, 0, 4)
	sellBtn.BackgroundColor3 = COLORS.danger
	sellBtn.Text = "SELL"
	sellBtn.TextColor3 = COLORS.text
	sellBtn.Font = Enum.Font.GothamBold
	sellBtn.TextSize = 9
	sellBtn.Visible = false
	sellBtn.Parent = actionBar

	local sellBtnCorner = Instance.new("UICorner")
	sellBtnCorner.CornerRadius = UDim.new(0, 4)
	sellBtnCorner.Parent = sellBtn

	panel.onBuyCpu = nil
	panel.onBuyRam = nil
	panel.onSell = nil
	panel.onReset = nil

	buyCpuBtn.MouseButton1Click:Connect(function()
		if panel.onBuyCpu then
			panel.onBuyCpu()
		end
	end)

	buyRamBtn.MouseButton1Click:Connect(function()
		if panel.onBuyRam then
			panel.onBuyRam()
		end
	end)

	sellBtn.MouseButton1Click:Connect(function()
		if panel.onSell then
			panel.onSell()
		end
	end)

	resetBtn.MouseButton1Click:Connect(function()
		if panel.onReset then
			panel.onReset()
		end
	end)

	-- Line numbers (inside its own scrolling frame to sync with code)
	local lineScroll = Instance.new("ScrollingFrame")
	lineScroll.Name = "LineScroll"
	lineScroll.Size = UDim2.new(0, 25, 1, -130)  -- Room for top bar + suggestion bar + compile status + action bar
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
	codeScroll.Size = UDim2.new(1, -35, 1, -130)  -- Room for top bar + suggestion bar + compile status + action bar
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

	compileBtn.MouseButton1Click:Connect(function()
		if hasCompileError then return end
		if callbacks.onLoad then
			textBox.Text = formatCode(textBox.Text)
			callbacks.onLoad(textBox.Text)
		end
	end)

	codeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		lineScroll.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
	end)

	local suggestBar = Instance.new("ScrollingFrame")
	suggestBar.Name = "SuggestBar"
	suggestBar.Size = UDim2.new(1, -6, 0, 20)
	suggestBar.Position = UDim2.new(0, 3, 1, -83)  -- Above compile status bar
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
	helpTooltip.Position = UDim2.new(0, 3, 1, -98)  -- Above suggestion bar
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

	local function updateCompileButton()
		if hasCompileError then
			compileBtn.BackgroundColor3 = COLORS.subtext
			compileBtn.TextColor3 = COLORS.bg
		else
			compileBtn.BackgroundColor3 = COLORS.success
			compileBtn.TextColor3 = COLORS.text
		end
	end

	local function updateCompileStatus()
		local source = textBox.Text
		if source == "" then
			bytecodeLabel.Text = "0/" .. currentMaxBytecode
			bytecodeLabel.TextColor3 = COLORS.subtext
			compileErrorLabel.Text = ""
			hasCompileError = false
			updateCompileButton()
			return
		end

		local success, result = pcall(function()
			return Python.compile(source, currentMaxBytecode, currentSelfType, currentEnvTypes)
		end)

		if success and result then
			if result.error then
				bytecodeLabel.Text = "ERR"
				bytecodeLabel.TextColor3 = COLORS.danger
				compileErrorLabel.Text = result.error
				hasCompileError = true
			else
				bytecodeLabel.Text = result.instructionCount .. "/" .. currentMaxBytecode
				bytecodeLabel.TextColor3 = COLORS.success
				compileErrorLabel.Text = ""
				hasCompileError = false
			end
		else
			bytecodeLabel.Text = "ERR"
			bytecodeLabel.TextColor3 = COLORS.danger
			compileErrorLabel.Text = tostring(result)
			hasCompileError = true
		end
		updateCompileButton()
	end

	local compileUpdatePending = false
	local function scheduleCompileUpdate()
		if compileUpdatePending then return end
		compileUpdatePending = true
		task.delay(0.3, function()
			compileUpdatePending = false
			updateCompileStatus()
		end)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(scheduleCompileUpdate)

	local T = Classes.T

	local function formatType(typ)
		if type(typ) == "string" then
			return typ
		elseif type(typ) == "table" then
			if typ[1] == "optional" then return typ[2] .. "?" end
			if typ[1] == T.LIST then return "List[" .. (typ[2] or "any") .. "]" end
			return typ[1] or "any"
		end
		return "any"
	end

	local function formatArgs(args)
		if not args or #args == 0 then return "()" end
		local parts = {}
		for _, arg in ipairs(args) do parts[#parts + 1] = formatType(arg) end
		return "(" .. table.concat(parts, ", ") .. ")"
	end

	local function generateMethodsFromClass(className)
		local classDef = Classes[className]
		if not classDef or not classDef.members then return {} end
		local items = {}
		for name, member in pairs(classDef.members) do
			if member.kind == "method" then
				local sig = formatArgs(member.args) .. " -> " .. formatType(member.returns)
				items[#items + 1] = {word = name, snippet = name .. "()", help = name .. sig}
			elseif member.kind == "prop" then
				items[#items + 1] = {word = name, snippet = name, help = name .. ": " .. formatType(member.type)}
			end
		end
		table.sort(items, function(a, b) return a.word < b.word end)
		return items
	end

	local BOT_METHODS = generateMethodsFromClass("Bot")
	local TURRET_METHODS = generateMethodsFromClass("Turret")
	local PLAYER_METHODS = generateMethodsFromClass("Player")
	local ENEMY_METHODS = generateMethodsFromClass("Enemy")

	local KEYWORDS = {
		{word = "while", snippet = "while True:\n    ", help = "while condition:"},
		{word = "if", snippet = "if :\n    ", help = "if condition:"},
		{word = "elif", snippet = "elif :\n    ", help = "elif condition:"},
		{word = "else", snippet = "else:\n    ", help = "else:"},
		{word = "for", snippet = "for i in range():\n    ", help = "for var in list:"},
		{word = "def", snippet = "def ():\n    ", help = "def name(args):"},
		{word = "return", snippet = "return ", help = "return value"},
		{word = "True", snippet = "True", help = "bool"},
		{word = "False", snippet = "False", help = "bool"},
		{word = "None", snippet = "None", help = "nil"},
		{word = "and", snippet = "and ", help = "a and b"},
		{word = "or", snippet = "or ", help = "a or b"},
		{word = "not", snippet = "not ", help = "not a"},
	}

	local GLOBALS = {
		{word = "print", snippet = "print()", help = "print(any) -> nil"},
		{word = "len", snippet = "len()", help = "len(List) -> number"},
		{word = "range", snippet = "range()", help = "range(number) -> List[number]"},
		{word = "abs", snippet = "abs()", help = "abs(number) -> number"},
		{word = "min", snippet = "min()", help = "min(number, number) -> number"},
		{word = "max", snippet = "max()", help = "max(number, number) -> number"},
		{word = "nearest", snippet = "nearest()", help = "nearest(List[Enemy]) -> Enemy"},
		{word = "furthest", snippet = "furthest()", help = "furthest(List[Enemy]) -> Enemy"},
		{word = "weakest", snippet = "weakest()", help = "weakest(List[Enemy]) -> Enemy"},
		{word = "strongest", snippet = "strongest()", help = "strongest(List[Enemy]) -> Enemy"},
	}

	local CONSTANTS = {
		{word = "BULLET", snippet = "BULLET", help = "AmmoType = 1"},
		{word = "ROCKET", snippet = "ROCKET", help = "AmmoType = 2"},
		{word = "LASER", snippet = "LASER", help = "AmmoType = 3"},
		{word = "ICE", snippet = "ICE", help = "AmmoType = 4"},
		{word = "FREEZE", snippet = "FREEZE", help = "AmmoType = 5"},
		{word = "GRENADE", snippet = "GRENADE", help = "AmmoType = 5"},
		{word = "CORE", snippet = "CORE", help = "Core"},
	}

	local function isValidObjectPrefix(obj)
		if obj == "self" or obj == "CORE" then return true end
		if obj:match("^B[1-4]$") then return true end
		if obj:match("^T%d+$") then
			local n = tonumber(obj:sub(2))
			return n and n >= 1 and n <= 30
		end
		return false
	end

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

	local keywordTrie = buildTrie(KEYWORDS)
	local globalTrie = buildTrie(GLOBALS)
	local constantTrie = buildTrie(CONSTANTS)
	local botMethodTrie = buildTrie(BOT_METHODS)
	local turretMethodTrie = buildTrie(TURRET_METHODS)
	local playerMethodTrie = buildTrie(PLAYER_METHODS)
	local enemyMethodTrie = buildTrie(ENEMY_METHODS)

	local function getCurrentContext(text)
		local obj, word = text:match("([%w_]+)%.([%w_]*)$")
		if obj and isValidObjectPrefix(obj) then
			return obj, word:lower(), #obj + 1 + #word
		end
		local listVar, idx = text:match("([%w_]+)%[(%d*)$")
		if listVar then
			return "list[", idx, #listVar + 1 + #idx
		end
		local lastWord = text:match("([%w_]+)$") or ""
		return nil, lastWord:lower(), #lastWord
	end

	local coreTrie = buildTrie({
		{word = "position", snippet = "position", help = "position: Vector"},
		{word = "hp", snippet = "hp", help = "hp: number"},
	})

	local function getMethodsForObject(obj)
		if obj == "self" then
			if currentMode == "golem" then return turretMethodTrie end
			if currentMode == "player" then return playerMethodTrie end
			return botMethodTrie
		elseif obj:match("^B%d$") then
			return botMethodTrie
		elseif obj:match("^T%d+$") then
			return turretMethodTrie
		elseif obj == "CORE" then
			return coreTrie
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
			if #currentWord >= 2 then
				for _, trie in ipairs({keywordTrie, globalTrie, constantTrie}) do
					for _, item in ipairs(searchTrie(trie, currentWord)) do
						matches[#matches + 1] = {word = item.word, snippet = item.snippet, help = item.help}
						if #matches >= MAX_SUGGESTIONS then break end
					end
					if #matches >= MAX_SUGGESTIONS then break end
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

	function panel:setMode(mode, spotId, maxBytes, envTypes)
		currentMode = mode or "player"
		currentMaxBytecode = maxBytes or DEFAULT_MAX_BYTECODE
		currentEnvTypes = envTypes or {}
		local theme = THEMES[currentMode] or THEMES.player

		frame.BackgroundColor3 = theme.frameBg
		topBar.BackgroundColor3 = theme.headerBg
		actionBar.BackgroundColor3 = theme.headerBg

		if currentMode == "player" then
			currentSelfType = "Player"
			modeIndicator.Text = "PLAYER"
			modeIndicator.TextColor3 = theme.accent
			modeIndicator.BackgroundColor3 = theme.headerBg
			modeIndicator.Visible = true
			compileBtn.Visible = true
			resetBtn.Visible = true
			resetBtn.Position = UDim2.new(0, 112, 0, 4)
			buyCpuBtn.Visible = false
			buyRamBtn.Visible = false
			sellBtn.Visible = false
			textBox.TextEditable = true
			textBox.Active = true
		elseif currentMode == "golem" then
			currentSelfType = "Turret"
			modeIndicator.Text = "TURRET #" .. (spotId or "?")
			modeIndicator.TextColor3 = theme.accent
			modeIndicator.BackgroundColor3 = theme.headerBg
			modeIndicator.Visible = true
			compileBtn.Visible = true
			resetBtn.Visible = true
			resetBtn.Position = UDim2.new(0, 244, 0, 4)
			buyCpuBtn.Visible = true
			buyRamBtn.Visible = true
			sellBtn.Visible = true
			textBox.TextEditable = true
			textBox.Active = true
		elseif currentMode == "bot" then
			currentSelfType = "Bot"
			modeIndicator.Text = "BOT #" .. (spotId or "?")
			modeIndicator.TextColor3 = theme.accent
			modeIndicator.BackgroundColor3 = theme.headerBg
			modeIndicator.Visible = true
			compileBtn.Visible = true
			resetBtn.Visible = true
			resetBtn.Position = UDim2.new(0, 112, 0, 4)
			buyCpuBtn.Visible = false
			buyRamBtn.Visible = false
			sellBtn.Visible = true
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

	-- Callback for exiting golem/bot mode (set by main client)
	panel.onExitGolem = nil

	return panel
end

return EditorPanel
