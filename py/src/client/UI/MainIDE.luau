local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(script.Parent.UITheme)
local EditorPanel = require(script.Parent.EditorPanel)

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Python = require(PythonTD.Python)

local MainIDE = {}
local COLORS = UITheme.COLORS
local THEMES = UITheme.THEMES
local OP_COLORS = UITheme.OP_COLORS
local formatValue = UITheme.formatValue

local VARS_WIDTH = 220
local BYTECODE_WIDTH = 240
local IDE_HEIGHT_SCALE = 0.45
local HEADER_HEIGHT = 32
local OUTPUT_HEIGHT = 120

function MainIDE.create(parent, callbacks)
	callbacks = callbacks or {}
	local interpreters = {}
	local currentTabId = nil
	local tabs = {}

	local container = Instance.new("Frame")
	container.Name = "IDE_Main"
	container.Size = UDim2.new(1, 0, IDE_HEIGHT_SCALE, 0)
	container.Position = UDim2.new(0, 0, 1 - IDE_HEIGHT_SCALE, 0)
	container.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Parent = parent

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 4)
	topBar.BackgroundColor3 = COLORS.accent
	topBar.BorderSizePixel = 0
	topBar.Parent = container

	local collapseBtn = Instance.new("TextButton")
	collapseBtn.Size = UDim2.new(0, 80, 0, 20)
	collapseBtn.Position = UDim2.new(0.5, -40, 0, -20)
	collapseBtn.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	collapseBtn.Text = "TERMINAL"
	collapseBtn.TextColor3 = COLORS.text
	collapseBtn.Font = Enum.Font.GothamBold
	collapseBtn.TextSize = 10
	collapseBtn.Parent = container
	Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 4)

	local colVars = Instance.new("Frame")
	colVars.Name = "Col_Vars"
	colVars.Size = UDim2.new(0, VARS_WIDTH, 1, -4)
	colVars.AnchorPoint = Vector2.new(1, 0)
	colVars.Position = UDim2.new(1, 0, 0, 4)
	colVars.BackgroundColor3 = Color3.fromHex("#252526")
	colVars.BorderSizePixel = 0
	colVars.Parent = container

	local varHeader = Instance.new("TextLabel")
	varHeader.Size = UDim2.new(1, -10, 0, HEADER_HEIGHT)
	varHeader.Position = UDim2.new(0, 10, 0, 0)
	varHeader.BackgroundTransparency = 1
	varHeader.Text = "VARIABLES"
	varHeader.TextColor3 = COLORS.subtext
	varHeader.Font = Enum.Font.GothamBold
	varHeader.TextSize = 10
	varHeader.TextXAlignment = Enum.TextXAlignment.Left
	varHeader.Parent = colVars

	local varList = Instance.new("ScrollingFrame")
	varList.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	varList.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	varList.BackgroundTransparency = 1
	varList.BorderSizePixel = 0
	varList.CanvasSize = UDim2.new(0, 0, 0, 0)
	varList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	varList.ScrollBarThickness = 2
	varList.Parent = colVars

	local varLayout = Instance.new("UIListLayout")
	varLayout.Padding = UDim.new(0, 2)
	varLayout.Parent = varList

	local colBytecode = Instance.new("Frame")
	colBytecode.Name = "Col_Bytecode"
	colBytecode.Size = UDim2.new(0, BYTECODE_WIDTH, 1, -4)
	colBytecode.AnchorPoint = Vector2.new(1, 0)
	colBytecode.Position = UDim2.new(1, -VARS_WIDTH - 2, 0, 4)
	colBytecode.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	colBytecode.BorderSizePixel = 0
	colBytecode.Parent = container

	local bcHeader = Instance.new("Frame")
	bcHeader.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + 40)
	bcHeader.BackgroundTransparency = 1
	bcHeader.Parent = colBytecode

	local bcTitle = Instance.new("TextLabel")
	bcTitle.Size = UDim2.new(1, -10, 0, 20)
	bcTitle.Position = UDim2.new(0, 10, 0, 0)
	bcTitle.BackgroundTransparency = 1
	bcTitle.Text = "BYTECODE (COMPUTER)"
	bcTitle.TextColor3 = COLORS.subtext
	bcTitle.Font = Enum.Font.GothamBold
	bcTitle.TextSize = 9
	bcTitle.TextXAlignment = Enum.TextXAlignment.Left
	bcTitle.Parent = bcHeader

	local cpuRamLabel = Instance.new("TextLabel")
	cpuRamLabel.Name = "Stats"
	cpuRamLabel.Size = UDim2.new(1, -10, 0, 15)
	cpuRamLabel.Position = UDim2.new(0, 10, 0, 15)
	cpuRamLabel.BackgroundTransparency = 1
	cpuRamLabel.Text = "CPU: 10Hz | RAM: 0/32"
	cpuRamLabel.TextColor3 = COLORS.accent
	cpuRamLabel.Font = Enum.Font.Code
	cpuRamLabel.TextSize = 9
	cpuRamLabel.TextXAlignment = Enum.TextXAlignment.Left
	cpuRamLabel.Parent = bcHeader

	local buyContainer = Instance.new("Frame")
	buyContainer.Size = UDim2.new(1, 0, 0, 25)
	buyContainer.Position = UDim2.new(0, 0, 0, 35)
	buyContainer.BackgroundTransparency = 1
	buyContainer.Visible = false
	buyContainer.Parent = bcHeader

	local buyCpuBtn = Instance.new("TextButton")
	buyCpuBtn.Size = UDim2.new(0, 70, 0, 20)
	buyCpuBtn.Position = UDim2.new(0, 10, 0, 0)
	buyCpuBtn.BackgroundColor3 = COLORS.panel
	buyCpuBtn.Text = "BUY CPU"
	buyCpuBtn.TextColor3 = COLORS.success
	buyCpuBtn.Font = Enum.Font.GothamBold
	buyCpuBtn.TextSize = 9
	buyCpuBtn.Parent = buyContainer
	Instance.new("UICorner", buyCpuBtn).CornerRadius = UDim.new(0, 4)

	local buyRamBtn = Instance.new("TextButton")
	buyRamBtn.Size = UDim2.new(0, 70, 0, 20)
	buyRamBtn.Position = UDim2.new(0, 90, 0, 0)
	buyRamBtn.BackgroundColor3 = COLORS.panel
	buyRamBtn.Text = "BUY RAM"
	buyRamBtn.TextColor3 = COLORS.warning
	buyRamBtn.Font = Enum.Font.GothamBold
	buyRamBtn.TextSize = 9
	buyRamBtn.Parent = buyContainer
	Instance.new("UICorner", buyRamBtn).CornerRadius = UDim.new(0, 4)

	local bcList = Instance.new("ScrollingFrame")
	bcList.Size = UDim2.new(1, 0, 1, -70)
	bcList.Position = UDim2.new(0, 0, 0, 70)
	bcList.BackgroundTransparency = 1
	bcList.BorderSizePixel = 0
	bcList.CanvasSize = UDim2.new(0, 0, 0, 0)
	bcList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bcList.ScrollBarThickness = 2
	bcList.Parent = colBytecode

	local bcLayout = Instance.new("UIListLayout")
	bcLayout.Parent = bcList

	local colEditor = Instance.new("Frame")
	colEditor.Name = "Col_Editor"
	colEditor.Size = UDim2.new(1, -(VARS_WIDTH + BYTECODE_WIDTH + 4), 1, -4)
	colEditor.Position = UDim2.new(0, 0, 0, 4)
	colEditor.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	colEditor.BorderSizePixel = 0
	colEditor.Parent = container

	local editHeader = Instance.new("Frame")
	editHeader.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	editHeader.BackgroundColor3 = Color3.fromHex("#2d2d2d")
	editHeader.BorderSizePixel = 0
	editHeader.Parent = colEditor

	local controlsFrame = Instance.new("Frame")
	controlsFrame.Size = UDim2.new(0, 200, 1, 0)
	controlsFrame.AnchorPoint = Vector2.new(1, 0)
	controlsFrame.Position = UDim2.new(1, 0, 0, 0)
	controlsFrame.BackgroundTransparency = 1
	controlsFrame.Parent = editHeader

	local runBtn = Instance.new("TextButton")
	runBtn.Name = "RunBtn"
	runBtn.Size = UDim2.new(0, 100, 0, 22)
	runBtn.Position = UDim2.new(1, -110, 0.5, -11)
	runBtn.BackgroundColor3 = COLORS.success
	runBtn.Text = "./script.py"
	runBtn.TextColor3 = COLORS.bg
	runBtn.Font = Enum.Font.Code
	runBtn.TextSize = 11
	runBtn.Parent = controlsFrame
	Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 4)

	local gdbBtn = Instance.new("TextButton")
	gdbBtn.Name = "GdbBtn"
	gdbBtn.Size = UDim2.new(0, 60, 0, 22)
	gdbBtn.Position = UDim2.new(1, -180, 0.5, -11)
	gdbBtn.BackgroundColor3 = COLORS.warning
	gdbBtn.Text = "GDB"
	gdbBtn.TextColor3 = COLORS.bg
	gdbBtn.Font = Enum.Font.GothamBold
	gdbBtn.TextSize = 11
	gdbBtn.Parent = controlsFrame
	Instance.new("UICorner", gdbBtn).CornerRadius = UDim.new(0, 4)

	local tabsScroll = Instance.new("ScrollingFrame")
	tabsScroll.Size = UDim2.new(1, -205, 1, 0)
	tabsScroll.BackgroundTransparency = 1
	tabsScroll.BorderSizePixel = 0
	tabsScroll.ScrollBarThickness = 0
	tabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	tabsScroll.ClipsDescendants = false
	tabsScroll.Parent = editHeader

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabsScroll

	local editorArea = Instance.new("Frame")
	editorArea.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + OUTPUT_HEIGHT))
	editorArea.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	editorArea.BackgroundTransparency = 1
	editorArea.Parent = colEditor

	local editor = EditorPanel.create(editorArea)
	local editorTextBox = editor:getTextBox()
	local isProcessingSync = false

	local stdOutLabel, stdErrLabel

	local function tryCompile(source, maxBytecode, selfType)
		local success, result = pcall(function()
			return Python.compile(source, maxBytecode or 9999, selfType or "Entity", {})
		end)
		if not success then
			return false, { message = tostring(result), line = nil }
		end
		if result.error then
			return false, result.error
		end
		return true, nil
	end

	local function isEditing(data)
		return data and data.localSource and data.originalSource and data.localSource ~= data.originalSource
	end

	local function onTextChanged()
		if isProcessingSync then return end
		if not currentTabId then return end

		local data = interpreters[currentTabId]
		if not data then return end

		local newSource = editorTextBox.Text
		local wasEditing = isEditing(data)
		data.localSource = newSource

		if not wasEditing and isEditing(data) then
			if callbacks.onPause then
				callbacks.onPause(currentTabId)
			end
		end

		if isEditing(data) then
			local maxBytecode = data.maxBytecode or 128
			local compileOk, compileError = tryCompile(newSource, maxBytecode, data.selfType)
			data.compileOk = compileOk
			data.compileError = compileError

			if compileOk then
				stdErrLabel.Text = ""
				editor:setErrorLine(-1)
				runBtn.BackgroundColor3 = COLORS.success
			else
				stdErrLabel.Text = compileError.message or ""
				editor:setErrorLine(compileError.line)
				runBtn.BackgroundColor3 = COLORS.disabledBg
			end

			runBtn.Text = "./" .. (data.name or "script.py")
			gdbBtn.Text = "RESTORE"
			gdbBtn.BackgroundColor3 = COLORS.danger
		end
	end

	local outputArea = Instance.new("Frame")
	outputArea.Size = UDim2.new(1, 0, 0, OUTPUT_HEIGHT)
	outputArea.Position = UDim2.new(0, 0, 1, -OUTPUT_HEIGHT)
	outputArea.BackgroundColor3 = Color3.fromHex("#1a1a1a")
	outputArea.BorderSizePixel = 0
	outputArea.Parent = colEditor

	local outDivider = Instance.new("Frame")
	outDivider.Size = UDim2.new(0, 2, 1, 0)
	outDivider.Position = UDim2.new(0.6, 0, 0, 0)
	outDivider.BackgroundColor3 = Color3.fromHex("#333333")
	outDivider.BorderSizePixel = 0
	outDivider.Parent = outputArea

	local stdOutContainer = Instance.new("Frame")
	stdOutContainer.Size = UDim2.new(0.6, -1, 1, 0)
	stdOutContainer.BackgroundTransparency = 1
	stdOutContainer.Parent = outputArea

	local stdOutTitle = Instance.new("TextLabel")
	stdOutTitle.Size = UDim2.new(1, 0, 0, 16)
	stdOutTitle.BackgroundTransparency = 1
	stdOutTitle.Text = "  OUTPUT"
	stdOutTitle.TextColor3 = COLORS.subtext
	stdOutTitle.Font = Enum.Font.GothamBold
	stdOutTitle.TextSize = 9
	stdOutTitle.TextXAlignment = Enum.TextXAlignment.Left
	stdOutTitle.Parent = stdOutContainer

	local stdOut = Instance.new("ScrollingFrame")
	stdOut.Size = UDim2.new(1, 0, 1, -16)
	stdOut.Position = UDim2.new(0, 0, 0, 16)
	stdOut.BackgroundTransparency = 1
	stdOut.BorderSizePixel = 0
	stdOut.CanvasSize = UDim2.new(0, 0, 0, 0)
	stdOut.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stdOut.ScrollBarThickness = 2
	stdOut.Parent = stdOutContainer

	stdOutLabel = Instance.new("TextLabel")
	stdOutLabel.Size = UDim2.new(1, -6, 0, 0)
	stdOutLabel.Position = UDim2.new(0, 3, 0, 0)
	stdOutLabel.BackgroundTransparency = 1
	stdOutLabel.Text = ""
	stdOutLabel.TextColor3 = COLORS.success
	stdOutLabel.TextXAlignment = Enum.TextXAlignment.Left
	stdOutLabel.TextYAlignment = Enum.TextYAlignment.Top
	stdOutLabel.Font = Enum.Font.Code
	stdOutLabel.TextSize = 11
	stdOutLabel.TextWrapped = true
	stdOutLabel.AutomaticSize = Enum.AutomaticSize.Y
	stdOutLabel.Parent = stdOut

	local stdErrContainer = Instance.new("Frame")
	stdErrContainer.Size = UDim2.new(0.4, -1, 1, 0)
	stdErrContainer.Position = UDim2.new(0.6, 2, 0, 0)
	stdErrContainer.BackgroundTransparency = 1
	stdErrContainer.Parent = outputArea

	local stdErrTitle = Instance.new("TextLabel")
	stdErrTitle.Size = UDim2.new(1, 0, 0, 16)
	stdErrTitle.BackgroundTransparency = 1
	stdErrTitle.Text = "  ERRORS"
	stdErrTitle.TextColor3 = COLORS.subtext
	stdErrTitle.Font = Enum.Font.GothamBold
	stdErrTitle.TextSize = 9
	stdErrTitle.TextXAlignment = Enum.TextXAlignment.Left
	stdErrTitle.Parent = stdErrContainer

	local stdErr = Instance.new("ScrollingFrame")
	stdErr.Size = UDim2.new(1, 0, 1, -16)
	stdErr.Position = UDim2.new(0, 0, 0, 16)
	stdErr.BackgroundTransparency = 1
	stdErr.BorderSizePixel = 0
	stdErr.CanvasSize = UDim2.new(0, 0, 0, 0)
	stdErr.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stdErr.ScrollBarThickness = 2
	stdErr.Parent = stdErrContainer

	stdErrLabel = Instance.new("TextLabel")
	stdErrLabel.Size = UDim2.new(1, -6, 0, 0)
	stdErrLabel.Position = UDim2.new(0, 3, 0, 0)
	stdErrLabel.BackgroundTransparency = 1
	stdErrLabel.Text = ""
	stdErrLabel.TextColor3 = COLORS.danger
	stdErrLabel.TextXAlignment = Enum.TextXAlignment.Left
	stdErrLabel.TextYAlignment = Enum.TextYAlignment.Top
	stdErrLabel.Font = Enum.Font.Code
	stdErrLabel.TextSize = 11
	stdErrLabel.TextWrapped = true
	stdErrLabel.AutomaticSize = Enum.AutomaticSize.Y
	stdErrLabel.Parent = stdErr

	editorTextBox:GetPropertyChangedSignal("Text"):Connect(onTextChanged)

	local ide = {}

	local function clearList(frame)
		for _, c in ipairs(frame:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end

	local function updateStats(cpu, ram, maxRam)
		cpuRamLabel.Text = string.format("CPU: %dHz | RAM: %d/%d", cpu or 10, ram or 0, maxRam or 128)
	end

	local function updateState(pid)
		if pid ~= currentTabId then return end
		local data = interpreters[pid]
		if not data then return end

		local status = data.status
		local isPaused = data.paused
		local editing = isEditing(data)

		if editing then
			runBtn.Text = "./" .. (data.name or "script.py")
			runBtn.BackgroundColor3 = data.compileOk and COLORS.success or COLORS.disabledBg
			gdbBtn.Text = "RESTORE"
			gdbBtn.BackgroundColor3 = COLORS.danger
			editor:setReadOnly(false)
		elseif isPaused then
			runBtn.Text = "RESUME"
			runBtn.BackgroundColor3 = COLORS.success
			gdbBtn.Text = "STEP"
			gdbBtn.BackgroundColor3 = COLORS.warning
			editor:setReadOnly(true)
		elseif status == "RUNNING" then
			runBtn.Text = "RUNNING..."
			runBtn.BackgroundColor3 = COLORS.disabledBg
			gdbBtn.Text = "PAUSE"
			gdbBtn.BackgroundColor3 = COLORS.warning
			editor:setReadOnly(false)
		else
			runBtn.Text = "./" .. (data.name or "script.py")
			runBtn.BackgroundColor3 = COLORS.success
			gdbBtn.Text = "GDB"
			gdbBtn.BackgroundColor3 = COLORS.warning
			editor:setReadOnly(false)
		end

		buyContainer.Visible = (data.type == "golem")

		clearList(varList)
		local varNames = {}
		for k in pairs(data.variables or {}) do table.insert(varNames, k) end
		table.sort(varNames)

		for _, k in ipairs(varNames) do
			local v = data.variables[k]
			if v ~= "__NIL__" then
				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, 0, 0, 16)
				l.BackgroundTransparency = 1
				l.RichText = true
				l.Text = string.format('<font color="#9CDCFE">%s</font> = <font color="#CE9178">%s</font>', k, formatValue(v, 15))
				l.Font = Enum.Font.Code
				l.TextSize = 10
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Parent = varList
			end
		end

		clearList(bcList)
		local execLine = nil
		if data.bytecode then
			for i, instr in ipairs(data.bytecode) do
				local l = Instance.new("TextLabel")
				l.Size = UDim2.new(1, 0, 0, 14)
				l.BackgroundTransparency = 1
				l.RichText = true
				local color = (data.ip == i) and "#FFFF00" or "#AAAAAA"
				l.Text = string.format('<font color="%s">%03d %s %s</font>', color, i, instr.op or "?", tostring(instr.arg or ""))
				l.Font = Enum.Font.Code
				l.TextSize = 10
				l.TextXAlignment = Enum.TextXAlignment.Left
				l.Parent = bcList

				if data.ip == i and (status == "RUNNING" or isPaused) and instr.line then
					execLine = instr.line
				end
			end
			updateStats(data.cpuHz, #data.bytecode, data.maxBytecode)
		end

		editor:setExecLine(execLine)

		stdOutLabel.Text = data.output or ""

		if editing and data.compileError then
			stdErrLabel.Text = data.compileError.message or ""
			editor:setErrorLine(data.compileError.line)
		elseif data.error and data.error.message and data.error.message ~= "" then
			stdErrLabel.Text = data.error.message
			editor:setErrorLine(data.error.line)
		else
			stdErrLabel.Text = ""
			editor:setErrorLine(-1)
		end
	end

	local function ensureTab(pid)
		if tabs[pid] then return end

		local data = interpreters[pid]
		local name = data and (data.name or data.type) or "script.py"
		local isPlayer = data and data.type == "player"

		local btn = Instance.new("TextButton")
		btn.Name = tostring(pid)
		btn.Size = UDim2.new(0, 100, 1, 0)
		btn.BackgroundColor3 = Color3.fromHex("#2d2d2d")
		btn.BorderSizePixel = 0
		btn.Text = " " .. name .. "  "
		btn.TextColor3 = COLORS.subtext
		btn.Font = Enum.Font.Code
		btn.TextSize = 10
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = tabsScroll

		if not isPlayer then
			local close = Instance.new("TextButton")
			close.Name = "CloseBtn"
			close.Size = UDim2.new(0, 20, 1, 0)
			close.Position = UDim2.new(1, -20, 0, 0)
			close.BackgroundTransparency = 1
			close.Text = "x"
			close.TextColor3 = COLORS.subtext
			close.Parent = btn
			close.MouseButton1Click:Connect(function() ide:closeTab(pid) end)
		end

		btn.MouseButton1Click:Connect(function() ide:openTab(pid) end)

		tabs[pid] = { button = btn }
	end

	function ide:openTab(pid)
		ensureTab(pid)

		for id, tab in pairs(tabs) do
			if id == pid then
				tab.button.BackgroundColor3 = Color3.fromHex("#1e1e1e")
				tab.button.TextColor3 = COLORS.text
			else
				tab.button.BackgroundColor3 = Color3.fromHex("#2d2d2d")
				tab.button.TextColor3 = COLORS.subtext
			end
		end

		currentTabId = pid
		local data = interpreters[pid]
		if data then
			local source = data.localSource or data.source or ""
			isProcessingSync = true
			editor:setText(source)
			isProcessingSync = false

			if not data.originalSource then
				data.originalSource = data.source or ""
			end
			if not data.localSource then
				data.localSource = source
			end

			updateState(pid)
			if callbacks.onTabOpen then
				callbacks.onTabOpen(pid)
			end
		end
	end

	function ide:closeTab(pid)
		local tab = tabs[pid]
		if not tab then return end

		local data = interpreters[pid]
		if data and data.type == "player" then return end

		tab.button:Destroy()
		tabs[pid] = nil
		if currentTabId == pid then
			currentTabId = nil
			for nextPid in pairs(tabs) do
				ide:openTab(nextPid)
				break
			end
		end
		if callbacks.onTabClose then callbacks.onTabClose(pid) end
	end

	function ide:closeTabSilent(pid)
		if tabs[pid] then
			tabs[pid].button:Destroy()
			tabs[pid] = nil
			if currentTabId == pid then
				currentTabId = nil
				for nextPid in pairs(tabs) do
					ide:openTab(nextPid)
					break
				end
			end
		end
	end

	function ide:sync(payload)
		local payloadPids = {}
		for pid in pairs(payload) do
			payloadPids[tostring(pid)] = true
		end

		local toRemove = {}
		for pid in pairs(interpreters) do
			if not payloadPids[tostring(pid)] then
				table.insert(toRemove, pid)
			end
		end
		for _, pid in ipairs(toRemove) do
			interpreters[pid] = nil
			if tabs[pid] then
				ide:closeTabSilent(pid)
			end
		end

		local playerPid = nil
		for pid, data in pairs(payload) do
			local isNew = not interpreters[pid]
			if isNew then
				interpreters[pid] = { pid = pid }
			end
			local localData = interpreters[pid]

			local hadLocalSource = localData.localSource
			for k, v in pairs(data) do localData[k] = v end

			if data.type == "player" then
				playerPid = pid
			end

			if not localData.originalSource and data.source then
				localData.originalSource = data.source
			end
			if not hadLocalSource and data.source then
				localData.localSource = data.source
			end

			ensureTab(pid)

			if pid == currentTabId then
				if not isEditing(localData) then
					isProcessingSync = true
					editor:setText(localData.localSource or localData.source or "")
					isProcessingSync = false
				end
				updateState(pid)
			end
		end

		if not currentTabId and playerPid then
			ide:openTab(playerPid)
		end
	end

	function ide:getInterpreterType(pid)
		return interpreters[pid] and interpreters[pid].type
	end

	function ide:getCounts()
		local g, b = 0, 0
		for _, d in pairs(interpreters) do
			if d.type == "golem" then g = g + 1 elseif d.type == "bot" then b = b + 1 end
		end
		return g, b
	end

	function ide:getCurrentTabId() return currentTabId end
	function ide:getText() return editor:getText() end

	runBtn.MouseButton1Click:Connect(function()
		if not currentTabId then return end
		local data = interpreters[currentTabId]
		if not data then return end

		if isEditing(data) then
			if not data.compileOk then return end
			data.originalSource = data.localSource
			if callbacks.onRun then callbacks.onRun(currentTabId) end
		else
			if data.paused or data.status ~= "RUNNING" then
				if callbacks.onRun then callbacks.onRun(currentTabId) end
			end
		end
	end)

	gdbBtn.MouseButton1Click:Connect(function()
		if not currentTabId then return end
		local data = interpreters[currentTabId]
		if not data then return end

		if isEditing(data) then
			data.localSource = data.originalSource
			data.compileOk = true
			data.compileError = nil
			isProcessingSync = true
			editor:setText(data.originalSource or "")
			isProcessingSync = false
			stdErrLabel.Text = ""
			editor:setErrorLine(-1)
			updateState(currentTabId)
		else
			if data.status == "RUNNING" and not data.paused then
				if callbacks.onPause then callbacks.onPause(currentTabId) end
			else
				if callbacks.onStep then callbacks.onStep(currentTabId) end
			end
		end
	end)

	buyCpuBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyCpu and currentTabId then callbacks.onBuyCpu(currentTabId) end
	end)

	buyRamBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyRam and currentTabId then callbacks.onBuyRam(currentTabId) end
	end)

	local collapsed = false
	collapseBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		if collapsed then
			TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0, 0, 1, -30)
			}):Play()
		else
			TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0, 0, 1 - IDE_HEIGHT_SCALE, 0)
			}):Play()
		end
	end)

	ide.frame = container
	ide.container = container

	return ide
end

return MainIDE
