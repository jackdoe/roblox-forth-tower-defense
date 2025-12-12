-- BytecodePanel.luau
-- Shows bytecode instructions and VM state for educational visualization
-- Displays the "machine code" alongside source code

local DragModule = require(script.Parent.DragModule)

local BytecodePanel = {}

-- Theme definitions
-- Player = blue/green, Golem (turret) = silver, Bot = orange
local THEMES = {
	player = {
		frameBg = Color3.fromRGB(30, 30, 40),
		headerBg = Color3.fromRGB(40, 40, 55),
		codeBg = Color3.fromRGB(25, 25, 35),
		accent = Color3.fromRGB(100, 180, 255),
	},
	golem = {
		-- Silver/grey theme for turrets
		frameBg = Color3.fromRGB(35, 35, 40),
		headerBg = Color3.fromRGB(50, 50, 55),
		codeBg = Color3.fromRGB(30, 30, 35),
		accent = Color3.fromRGB(180, 180, 200),
	},
	bot = {
		-- Orange theme for bots
		frameBg = Color3.fromRGB(40, 30, 20),
		headerBg = Color3.fromRGB(55, 40, 25),
		codeBg = Color3.fromRGB(35, 25, 15),
		accent = Color3.fromRGB(255, 160, 80),
	},
}

-- Opcode colors for syntax highlighting
local OP_COLORS = {
	-- Load/Store (blue)
	LOAD_CONST = "#569CD6",
	LOAD_VAR = "#569CD6",
	STORE_VAR = "#569CD6",
	LOAD_ATTR = "#569CD6",
	STORE_ATTR = "#569CD6",

	-- Stack ops (gray)
	POP = "#808080",
	DUP = "#808080",

	-- Arithmetic (green)
	BINARY_ADD = "#4EC9B0",
	BINARY_SUB = "#4EC9B0",
	BINARY_MUL = "#4EC9B0",
	BINARY_DIV = "#4EC9B0",
	BINARY_MOD = "#4EC9B0",
	BINARY_POW = "#4EC9B0",
	BINARY_FLOOR_DIV = "#4EC9B0",

	-- Comparison (yellow)
	COMPARE_EQ = "#DCDCAA",
	COMPARE_NE = "#DCDCAA",
	COMPARE_LT = "#DCDCAA",
	COMPARE_GT = "#DCDCAA",
	COMPARE_LE = "#DCDCAA",
	COMPARE_GE = "#DCDCAA",

	-- Logical (purple)
	BINARY_AND = "#C586C0",
	BINARY_OR = "#C586C0",
	UNARY_NOT = "#C586C0",
	UNARY_NEG = "#C586C0",

	-- Control flow (orange)
	JUMP = "#CE9178",
	JUMP_IF_FALSE = "#CE9178",
	JUMP_IF_TRUE = "#CE9178",
	POP_JUMP_IF_FALSE = "#CE9178",
	POP_JUMP_IF_TRUE = "#CE9178",

	-- Functions (cyan)
	CALL = "#4FC1FF",
	RETURN = "#4FC1FF",
	MAKE_FUNCTION = "#4FC1FF",

	-- Data structures (light blue)
	BUILD_LIST = "#9CDCFE",
	GET_INDEX = "#9CDCFE",
	SET_INDEX = "#9CDCFE",
	UNPACK_SEQUENCE = "#9CDCFE",

	-- Iteration (pink)
	GET_ITER = "#F38BA8",
	FOR_ITER = "#F38BA8",

	-- Special (red)
	YIELD = "#F44747",
	HALT = "#F44747",
}

-- Format instruction argument for display
local function formatArg(arg)
	if arg == nil then
		return ""
	elseif type(arg) == "table" then
		if arg.type then
			-- Constant value
			if arg.value == nil then
				return "None"
			elseif type(arg.value) == "string" then
				local str = arg.value
				if #str > 12 then
					str = str:sub(1, 10) .. ".."
				end
				return '"' .. str .. '"'
			elseif type(arg.value) == "boolean" then
				return arg.value and "True" or "False"
			else
				return tostring(arg.value)
			end
		elseif arg.name then
			-- Function
			return "<fn:" .. arg.name .. ">"
		else
			return "<table>"
		end
	elseif type(arg) == "string" then
		return arg
	else
		return tostring(arg)
	end
end

-- Format stack value for display
local function formatStackValue(v)
	if v == nil then
		return "None"
	elseif type(v) == "boolean" then
		return v and "True" or "False"
	elseif type(v) == "table" then
		if v._isFunction then
			return "<fn>"
		elseif v.items then
			return "<iter>"
		else
			return "[" .. #v .. "]"
		end
	elseif type(v) == "string" then
		if #v > 8 then
			return '"' .. v:sub(1, 6) .. '.."'
		end
		return '"' .. v .. '"'
	else
		return tostring(v)
	end
end

function BytecodePanel.create(parent)
	local panel = {}
	local currentTheme = "player"

	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "BytecodePanel"
	frame.Size = UDim2.new(0, 280, 0, 400)
	frame.Position = UDim2.new(1, -640, 1, -410)  -- Left of ProgramPanel
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
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
	title.Text = "BYTECODE"
	title.TextColor3 = Color3.fromRGB(180, 180, 200)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.Code
	title.TextSize = 12
	title.Parent = header

	-- Copy button
	local copyBtn = Instance.new("TextButton")
	copyBtn.Name = "CopyBtn"
	copyBtn.Size = UDim2.new(0, 45, 0, 18)
	copyBtn.Position = UDim2.new(1, -125, 0, 5)
	copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	copyBtn.Text = "COPY"
	copyBtn.TextColor3 = Color3.fromRGB(150, 150, 180)
	copyBtn.Font = Enum.Font.Code
	copyBtn.TextSize = 10
	copyBtn.Parent = header

	local copyBtnCorner = Instance.new("UICorner")
	copyBtnCorner.CornerRadius = UDim.new(0, 4)
	copyBtnCorner.Parent = copyBtn

	local ipLabel = Instance.new("TextLabel")
	ipLabel.Name = "IP"
	ipLabel.Size = UDim2.new(0, 70, 1, 0)
	ipLabel.Position = UDim2.new(1, -75, 0, 0)
	ipLabel.BackgroundTransparency = 1
	ipLabel.Text = "IP: 0"
	ipLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	ipLabel.TextXAlignment = Enum.TextXAlignment.Right
	ipLabel.Font = Enum.Font.Code
	ipLabel.TextSize = 12
	ipLabel.Parent = header

	-- Store bytecode text for copying
	local currentBytecodeText = ""

	-- ===== BYTECODE SECTION =====
	local bcY = 34

	local bcHeader = Instance.new("TextLabel")
	bcHeader.Size = UDim2.new(1, -20, 0, 16)
	bcHeader.Position = UDim2.new(0, 10, 0, bcY)
	bcHeader.BackgroundTransparency = 1
	bcHeader.Text = "INSTRUCTIONS"
	bcHeader.TextColor3 = Color3.fromRGB(120, 120, 140)
	bcHeader.TextXAlignment = Enum.TextXAlignment.Left
	bcHeader.Font = Enum.Font.Code
	bcHeader.TextSize = 10
	bcHeader.Parent = frame

	local bcScroll = Instance.new("ScrollingFrame")
	bcScroll.Name = "BytecodeScroll"
	bcScroll.Size = UDim2.new(1, -20, 0, 240)
	bcScroll.Position = UDim2.new(0, 10, 0, bcY + 18)
	bcScroll.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	bcScroll.BorderSizePixel = 0
	bcScroll.ScrollBarThickness = 4
	bcScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
	bcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	bcScroll.Parent = frame

	local bcCorner = Instance.new("UICorner")
	bcCorner.CornerRadius = UDim.new(0, 6)
	bcCorner.Parent = bcScroll

	local bcLabel = Instance.new("TextLabel")
	bcLabel.Name = "Bytecode"
	bcLabel.Size = UDim2.new(1, -8, 0, 0)
	bcLabel.Position = UDim2.new(0, 4, 0, 4)
	bcLabel.BackgroundTransparency = 1
	bcLabel.Text = ""
	bcLabel.RichText = true
	bcLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	bcLabel.TextXAlignment = Enum.TextXAlignment.Left
	bcLabel.TextYAlignment = Enum.TextYAlignment.Top
	bcLabel.Font = Enum.Font.Code
	bcLabel.TextSize = 11
	bcLabel.TextWrapped = false
	bcLabel.AutomaticSize = Enum.AutomaticSize.Y
	bcLabel.Parent = bcScroll

	-- ===== STACK SECTION =====
	local stackY = bcY + 265

	local stackHeader = Instance.new("TextLabel")
	stackHeader.Size = UDim2.new(1, -20, 0, 16)
	stackHeader.Position = UDim2.new(0, 10, 0, stackY)
	stackHeader.BackgroundTransparency = 1
	stackHeader.Text = "STACK"
	stackHeader.TextColor3 = Color3.fromRGB(120, 120, 140)
	stackHeader.TextXAlignment = Enum.TextXAlignment.Left
	stackHeader.Font = Enum.Font.Code
	stackHeader.TextSize = 10
	stackHeader.Parent = frame

	local stackFrame = Instance.new("Frame")
	stackFrame.Name = "StackFrame"
	stackFrame.Size = UDim2.new(1, -20, 0, 80)
	stackFrame.Position = UDim2.new(0, 10, 0, stackY + 18)
	stackFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	stackFrame.BorderSizePixel = 0
	stackFrame.ClipsDescendants = true
	stackFrame.Parent = frame

	local stackCorner = Instance.new("UICorner")
	stackCorner.CornerRadius = UDim.new(0, 6)
	stackCorner.Parent = stackFrame

	local stackLabel = Instance.new("TextLabel")
	stackLabel.Name = "Stack"
	stackLabel.Size = UDim2.new(1, -8, 1, -8)
	stackLabel.Position = UDim2.new(0, 4, 0, 4)
	stackLabel.BackgroundTransparency = 1
	stackLabel.Text = "(empty)"
	stackLabel.RichText = true
	stackLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
	stackLabel.TextXAlignment = Enum.TextXAlignment.Left
	stackLabel.TextYAlignment = Enum.TextYAlignment.Top
	stackLabel.Font = Enum.Font.Code
	stackLabel.TextSize = 11
	stackLabel.TextWrapped = true
	stackLabel.Parent = stackFrame

	-- Track if user is manually scrolling
	local lastUserScrollTime = 0
	local isUserScrolling = false

	bcScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		lastUserScrollTime = tick()
		isUserScrolling = true
		-- Reset after a short delay
		task.delay(1, function()
			if tick() - lastUserScrollTime >= 0.9 then
				isUserScrolling = false
			end
		end)
	end)

	panel.frame = frame

	function panel:setTheme(themeName)
		currentTheme = themeName or "player"
		local theme = THEMES[currentTheme] or THEMES.player
		frame.BackgroundColor3 = theme.frameBg
		header.BackgroundColor3 = theme.headerBg
		bcScroll.BackgroundColor3 = theme.codeBg
		stackFrame.BackgroundColor3 = theme.codeBg
	end

	-- Store current IP for copy and scroll tracking
	local currentIP = 0
	local lastScrolledIP = -1  -- Track which IP we last scrolled to

	-- Copy button handler
	copyBtn.MouseButton1Click:Connect(function()
		if currentBytecodeText ~= "" then
			-- Use setclipboard if available (Roblox Studio)
			if setclipboard then
				setclipboard("IP: " .. currentIP .. "\n" .. currentBytecodeText)
				copyBtn.Text = "DONE!"
				copyBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
			else
				-- Fallback: print to output
				print("=== BYTECODE (IP: " .. currentIP .. ") ===")
				print(currentBytecodeText)
				print("================")
				copyBtn.Text = "LOG"
				copyBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 60)
			end
			task.delay(1, function()
				copyBtn.Text = "COPY"
				copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
			end)
		end
	end)

	function panel:update(state)
		local bytecode = state.bytecode or {}
		local vm = state.vm or {}
		local ip = vm.ip or 0
		local stack = vm.stack or {}

		-- Store IP for copy button
		currentIP = ip

		-- Update IP display
		ipLabel.Text = "IP: " .. ip

		-- Build bytecode display
		if #bytecode > 0 then
			local lines = {}
			local plainLines = {}  -- For copy
			for i, instr in ipairs(bytecode) do
				local addr = string.format("%3d", i)
				local op = instr.op or "?"
				local arg = formatArg(instr.arg)
				local srcLine = instr.line or 0

				-- Plain text for copying
				local plainLine = addr .. " " .. op
				if arg ~= "" then
					plainLine = plainLine .. " " .. arg
				end
				if srcLine > 0 then
					plainLine = plainLine .. " L" .. srcLine
				end
				table.insert(plainLines, plainLine)

				-- Get opcode color
				local opColor = OP_COLORS[op] or "#D4D4D4"

				-- Format the line (rich text)
				local line
				if i == ip then
					-- Current instruction - bright highlight with arrow
					line = '<font color="#00FFFF"><b>-&gt;' .. addr .. '</b></font> <font color="' .. opColor .. '"><b>' .. op .. '</b></font>'
					if arg ~= "" then
						line = line .. ' <font color="#FFFFFF"><b>' .. arg .. '</b></font>'
					end
				else
					-- Normal instruction
					line = '<font color="#505060">' .. addr .. '</font> <font color="' .. opColor .. '">' .. op .. '</font>'
					if arg ~= "" then
						line = line .. ' <font color="#9CDCFE">' .. arg .. '</font>'
					end
				end

				-- Add source line reference (dim)
				if srcLine > 0 then
					line = line .. ' <font color="#404040">L' .. srcLine .. '</font>'
				end

				table.insert(lines, line)
			end

			bcLabel.Text = table.concat(lines, "\n")
			currentBytecodeText = table.concat(plainLines, "\n")

			-- Update canvas size
			bcScroll.CanvasSize = UDim2.new(0, 0, 0, #bytecode * 14 + 8)

			-- Auto-scroll to keep IP visible (but not if user is scrolling or IP hasn't changed)
			if not isUserScrolling and ip > 0 and ip <= #bytecode and ip ~= lastScrolledIP then
				lastScrolledIP = ip
				local targetY = (ip - 5) * 14  -- Show a few lines before current
				targetY = math.max(0, math.min(targetY, bcScroll.AbsoluteCanvasSize.Y - bcScroll.AbsoluteWindowSize.Y))
				bcScroll.CanvasPosition = Vector2.new(0, targetY)
			end
		else
			bcLabel.Text = '<font color="#606080">No bytecode loaded</font>'
			bcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		end

		-- Build stack display
		if #stack > 0 then
			local stackParts = {}

			-- Show stack from bottom to top (reversed)
			for i = #stack, 1, -1 do
				local val = formatStackValue(stack[i])
				local marker = ""
				if i == #stack then
					marker = '<font color="#00FFFF"> &lt;- TOP</font>'
				end
				table.insert(stackParts, '<font color="#B5CEA8">[' .. (i-1) .. ']</font> ' .. val .. marker)
			end

			stackLabel.Text = table.concat(stackParts, "\n")
		else
			stackLabel.Text = '<font color="#606080">(empty)</font>'
		end
	end

	function panel:setVisible(visible)
		frame.Visible = visible
	end

	return panel
end

return BytecodePanel
