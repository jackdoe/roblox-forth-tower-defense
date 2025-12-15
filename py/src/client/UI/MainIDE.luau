local TweenService = game:GetService("TweenService")
local UITheme = require(script.Parent.UITheme)

local MainIDE = {}
local COLORS = UITheme.COLORS
local THEMES = UITheme.THEMES
local OP_COLORS = UITheme.OP_COLORS
local formatValue = UITheme.formatValue

local IDE_HEIGHT_SCALE = 0.45
local EXPLORER_WIDTH = 160
local INSPECTOR_WIDTH = 240
local HEADER_HEIGHT = 28
local OUTPUT_HEIGHT = 80
local LINE_HEIGHT = 13

function MainIDE.create(parent, callbacks)
	callbacks = callbacks or {}

	local tabs = {}
	local tabOrder = {}
	local currentTabId = nil
	local interpreters = {}

	local container = Instance.new("Frame")
	container.Name = "IDE_Container"
	container.Size = UDim2.new(1, 0, IDE_HEIGHT_SCALE, 0)
	container.Position = UDim2.new(0, 0, 1 - IDE_HEIGHT_SCALE, 0)
	container.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Parent = parent

	local topBorder = Instance.new("Frame")
	topBorder.Size = UDim2.new(1, 0, 0, 2)
	topBorder.BackgroundColor3 = COLORS.accent
	topBorder.BorderSizePixel = 0
	topBorder.Parent = container

	local collapseBtn = Instance.new("TextButton")
	collapseBtn.Size = UDim2.new(0, 80, 0, 16)
	collapseBtn.Position = UDim2.new(0.5, -40, 0, -16)
	collapseBtn.BackgroundColor3 = COLORS.panel
	collapseBtn.Text = "TERMINAL"
	collapseBtn.TextColor3 = COLORS.text
	collapseBtn.Font = Enum.Font.GothamBold
	collapseBtn.TextSize = 10
	collapseBtn.BorderSizePixel = 0
	collapseBtn.Parent = container
	Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 4)

	local colExplorer = Instance.new("Frame")
	colExplorer.Name = "Explorer"
	colExplorer.Size = UDim2.new(0, EXPLORER_WIDTH, 1, -2)
	colExplorer.Position = UDim2.new(0, 0, 0, 2)
	colExplorer.BackgroundColor3 = Color3.fromHex("#252526")
	colExplorer.BorderSizePixel = 0
	colExplorer.Parent = container

	local explorerTitle = Instance.new("TextLabel")
	explorerTitle.Size = UDim2.new(1, -10, 0, HEADER_HEIGHT)
	explorerTitle.Position = UDim2.new(0, 10, 0, 0)
	explorerTitle.BackgroundTransparency = 1
	explorerTitle.Text = "EXPLORER"
	explorerTitle.TextColor3 = COLORS.subtext
	explorerTitle.Font = Enum.Font.GothamBold
	explorerTitle.TextSize = 10
	explorerTitle.TextXAlignment = Enum.TextXAlignment.Left
	explorerTitle.Parent = colExplorer

	local fileList = Instance.new("ScrollingFrame")
	fileList.Name = "FileList"
	fileList.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	fileList.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	fileList.BackgroundTransparency = 1
	fileList.ScrollBarThickness = 2
	fileList.CanvasSize = UDim2.new(0, 0, 0, 0)
	fileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	fileList.Parent = colExplorer

	local fileLayout = Instance.new("UIListLayout")
	fileLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fileLayout.Padding = UDim.new(0, 1)
	fileLayout.Parent = fileList

	local colInspector = Instance.new("Frame")
	colInspector.Name = "Inspector"
	colInspector.Size = UDim2.new(0, INSPECTOR_WIDTH, 1, -2)
	colInspector.Position = UDim2.new(1, -INSPECTOR_WIDTH, 0, 2)
	colInspector.BackgroundColor3 = Color3.fromHex("#252526")
	colInspector.BorderSizePixel = 0
	colInspector.Visible = false
	colInspector.Parent = container

	local varsFrame = Instance.new("Frame")
	varsFrame.Name = "Variables"
	varsFrame.Size = UDim2.new(1, 0, 0.5, -1)
	varsFrame.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	varsFrame.BorderSizePixel = 0
	varsFrame.Parent = colInspector

	local varsTitle = Instance.new("TextLabel")
	varsTitle.Size = UDim2.new(1, -10, 0, 20)
	varsTitle.Position = UDim2.new(0, 8, 0, 0)
	varsTitle.BackgroundTransparency = 1
	varsTitle.Text = "VARIABLES"
	varsTitle.TextColor3 = COLORS.subtext
	varsTitle.Font = Enum.Font.GothamBold
	varsTitle.TextSize = 9
	varsTitle.TextXAlignment = Enum.TextXAlignment.Left
	varsTitle.Parent = varsFrame

	local varsScroll = Instance.new("ScrollingFrame")
	varsScroll.Size = UDim2.new(1, -4, 1, -22)
	varsScroll.Position = UDim2.new(0, 2, 0, 20)
	varsScroll.BackgroundTransparency = 1
	varsScroll.ScrollBarThickness = 3
	varsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	varsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	varsScroll.Parent = varsFrame

	local varsLayout = Instance.new("UIListLayout")
	varsLayout.Padding = UDim.new(0, 1)
	varsLayout.Parent = varsScroll

	local varsPadding = Instance.new("UIPadding")
	varsPadding.PaddingLeft = UDim.new(0, 4)
	varsPadding.Parent = varsScroll

	local bcFrame = Instance.new("Frame")
	bcFrame.Name = "Bytecode"
	bcFrame.Size = UDim2.new(1, 0, 0.5, -1)
	bcFrame.Position = UDim2.new(0, 0, 0.5, 1)
	bcFrame.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	bcFrame.BorderSizePixel = 0
	bcFrame.Parent = colInspector

	local bcTitle = Instance.new("TextLabel")
	bcTitle.Size = UDim2.new(1, -10, 0, 20)
	bcTitle.Position = UDim2.new(0, 8, 0, 0)
	bcTitle.BackgroundTransparency = 1
	bcTitle.Text = "BYTECODE"
	bcTitle.TextColor3 = COLORS.subtext
	bcTitle.Font = Enum.Font.GothamBold
	bcTitle.TextSize = 9
	bcTitle.TextXAlignment = Enum.TextXAlignment.Left
	bcTitle.Parent = bcFrame

	local bcScroll = Instance.new("ScrollingFrame")
	bcScroll.Name = "BC_Scroll"
	bcScroll.Size = UDim2.new(1, -4, 1, -22)
	bcScroll.Position = UDim2.new(0, 2, 0, 20)
	bcScroll.BackgroundTransparency = 1
	bcScroll.ScrollBarThickness = 3
	bcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	bcScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bcScroll.Parent = bcFrame

	local bcLayout = Instance.new("UIListLayout")
	bcLayout.Padding = UDim.new(0, 0)
	bcLayout.Parent = bcScroll

	local colEditor = Instance.new("Frame")
	colEditor.Name = "Editor"
	colEditor.Size = UDim2.new(1, -(EXPLORER_WIDTH + INSPECTOR_WIDTH), 1, -2)
	colEditor.Position = UDim2.new(0, EXPLORER_WIDTH, 0, 2)
	colEditor.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	colEditor.BorderSizePixel = 0
	colEditor.Visible = false
	colEditor.Parent = container

	local editorHeader = Instance.new("Frame")
	editorHeader.Name = "Header"
	editorHeader.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	editorHeader.BackgroundColor3 = Color3.fromHex("#2d2d2d")
	editorHeader.BorderSizePixel = 0
	editorHeader.Parent = colEditor

	local controlsGroup = Instance.new("Frame")
	controlsGroup.Size = UDim2.new(0, 150, 1, 0)
	controlsGroup.Position = UDim2.new(1, -150, 0, 0)
	controlsGroup.BackgroundTransparency = 1
	controlsGroup.Parent = editorHeader

	local function createHeaderBtn(name, color, pos, text, callback)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0, 42, 0, 18)
		btn.Position = pos
		btn.BackgroundColor3 = color
		btn.Text = text
		btn.TextColor3 = COLORS.text
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 9
		btn.Parent = controlsGroup
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	createHeaderBtn("Run", COLORS.success, UDim2.new(0, 4, 0.5, -9), "RUN", function()
		if callbacks.onRun and currentTabId then
			callbacks.onRun(currentTabId)
		end
	end)

	createHeaderBtn("Step", COLORS.accent, UDim2.new(0, 52, 0.5, -9), "STEP", function()
		if callbacks.onStep and currentTabId then
			callbacks.onStep(currentTabId)
		end
	end)

	createHeaderBtn("Reset", COLORS.warning, UDim2.new(0, 100, 0.5, -9), "RESET", function()
		if callbacks.onReset and currentTabId then
			callbacks.onReset(currentTabId)
		end
	end)

	local tabsScroll = Instance.new("ScrollingFrame")
	tabsScroll.Size = UDim2.new(1, -155, 1, 0)
	tabsScroll.BackgroundTransparency = 1
	tabsScroll.ScrollBarThickness = 0
	tabsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	tabsScroll.Parent = editorHeader

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabsScroll

	local codeArea = Instance.new("Frame")
	codeArea.Name = "CodeArea"
	codeArea.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT - OUTPUT_HEIGHT)
	codeArea.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	codeArea.BackgroundTransparency = 1
	codeArea.Parent = colEditor

	local lineNumbers = Instance.new("TextLabel")
	lineNumbers.Size = UDim2.new(0, 28, 1, 0)
	lineNumbers.BackgroundTransparency = 1
	lineNumbers.Text = "1"
	lineNumbers.TextColor3 = Color3.fromHex("#858585")
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 13
	lineNumbers.Parent = codeArea

	local codeScroll = Instance.new("ScrollingFrame")
	codeScroll.Name = "CodeScroll"
	codeScroll.Size = UDim2.new(1, -28, 1, 0)
	codeScroll.Position = UDim2.new(0, 28, 0, 0)
	codeScroll.BackgroundTransparency = 1
	codeScroll.ScrollBarThickness = 5
	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
	codeScroll.Parent = codeArea

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -8, 1, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.TextColor3 = COLORS.text
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 13
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.Parent = codeScroll

	local lineHighlight = Instance.new("Frame")
	lineHighlight.Name = "Highlight"
	lineHighlight.Size = UDim2.new(0, 28, 0, 13)
	lineHighlight.BackgroundColor3 = Color3.fromRGB(100, 100, 60)
	lineHighlight.BackgroundTransparency = 0.3
	lineHighlight.BorderSizePixel = 0
	lineHighlight.Visible = false
	lineHighlight.ZIndex = 0
	lineHighlight.Parent = codeArea

	local outputFrame = Instance.new("Frame")
	outputFrame.Name = "Output"
	outputFrame.Size = UDim2.new(1, 0, 0, OUTPUT_HEIGHT)
	outputFrame.Position = UDim2.new(0, 0, 1, -OUTPUT_HEIGHT)
	outputFrame.BackgroundColor3 = Color3.fromHex("#1a1a1a")
	outputFrame.BorderSizePixel = 0
	outputFrame.Parent = colEditor

	local outputTitle = Instance.new("TextLabel")
	outputTitle.Size = UDim2.new(1, -10, 0, 18)
	outputTitle.Position = UDim2.new(0, 8, 0, 0)
	outputTitle.BackgroundTransparency = 1
	outputTitle.Text = "OUTPUT"
	outputTitle.TextColor3 = COLORS.subtext
	outputTitle.Font = Enum.Font.GothamBold
	outputTitle.TextSize = 9
	outputTitle.TextXAlignment = Enum.TextXAlignment.Left
	outputTitle.Parent = outputFrame

	local outputScroll = Instance.new("ScrollingFrame")
	outputScroll.Size = UDim2.new(1, -4, 1, -20)
	outputScroll.Position = UDim2.new(0, 2, 0, 18)
	outputScroll.BackgroundTransparency = 1
	outputScroll.ScrollBarThickness = 3
	outputScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	outputScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	outputScroll.Parent = outputFrame

	local outputLayout = Instance.new("UIListLayout")
	outputLayout.Padding = UDim.new(0, 0)
	outputLayout.Parent = outputScroll

	local emptyState = Instance.new("Frame")
	emptyState.Name = "EmptyState"
	emptyState.Size = UDim2.new(1, -EXPLORER_WIDTH, 1, -2)
	emptyState.Position = UDim2.new(0, EXPLORER_WIDTH, 0, 2)
	emptyState.BackgroundColor3 = Color3.fromHex("#1e1e1e")
	emptyState.BorderSizePixel = 0
	emptyState.Parent = container

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Size = UDim2.new(1, 0, 1, 0)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "Select a file to edit"
	emptyLabel.TextColor3 = COLORS.subtext
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.TextSize = 14
	emptyLabel.Parent = emptyState

	local function clearChildren(inst)
		for _, c in ipairs(inst:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end

	local function showEditor(show)
		colEditor.Visible = show
		colInspector.Visible = show
		emptyState.Visible = not show
	end

	showEditor(false)

	local function updateLineNumbers()
		local text = textBox.Text
		local count = 1
		for _ in string.gmatch(text, "\n") do count = count + 1 end
		local s = ""
		for i = 1, math.max(count, 15) do s = s .. i .. "\n" end
		lineNumbers.Text = s
		local h = math.max(count * LINE_HEIGHT + 100, codeScroll.AbsoluteWindowSize.Y)
		codeScroll.CanvasSize = UDim2.new(0, 0, 0, h)
		textBox.Size = UDim2.new(1, -8, 0, h)
		lineNumbers.Size = UDim2.new(0, 28, 0, h)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		updateLineNumbers()
		if currentTabId and tabs[currentTabId] then
			tabs[currentTabId].source = textBox.Text
		end
		lineHighlight.Visible = false
	end)

	local function renderVariables(vars)
		clearChildren(varsScroll)
		local names = {}
		for k in pairs(vars or {}) do table.insert(names, k) end
		table.sort(names)

		for i, name in ipairs(names) do
			if i > 25 then break end
			local value = vars[name]
			if value == "__NIL__" then value = nil end
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 14)
			lbl.BackgroundTransparency = 1
			lbl.RichText = true
			lbl.Text = string.format('<font color="#9CDCFE">%s</font> = <font color="#CE9178">%s</font>', name, formatValue(value, 18))
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 9
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = varsScroll
		end

		if #names == 0 then
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 14)
			lbl.BackgroundTransparency = 1
			lbl.Text = "(no variables)"
			lbl.TextColor3 = COLORS.subtext
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 9
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = varsScroll
		end
	end

	local function renderBytecode(bytecode, ip)
		clearChildren(bcScroll)
		if not bytecode or #bytecode == 0 then return end

		for i, instr in ipairs(bytecode) do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 0, 14)
			lbl.BackgroundTransparency = 1
			lbl.RichText = true
			local opColor = OP_COLORS[instr.op] or "#cccccc"
			local prefix = (i == ip) and ">" or " "
			lbl.Text = string.format('%s<font color="#555">%02d</font> <font color="%s">%-14s</font> %s',
				prefix, i, opColor, instr.op or "?", tostring(instr.arg or ""))
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 9
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			if i == ip then
				lbl.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
				lbl.BackgroundTransparency = 0
			end
			lbl.Parent = bcScroll
		end
	end

	local function updateHighlight(tab)
		if tab and tab.bytecode and tab.ip and tab.bytecode[tab.ip] then
			local line = tab.bytecode[tab.ip].line
			if line and line > 0 then
				lineHighlight.Visible = true
				lineHighlight.Position = UDim2.new(0, 0, 0, (line - 1) * LINE_HEIGHT)
			else
				lineHighlight.Visible = false
			end
		else
			lineHighlight.Visible = false
		end
	end

	local function renderTab(tab)
		if not tab then return end
		textBox.Text = tab.source or ""
		renderVariables(tab.variables)
		renderBytecode(tab.bytecode, tab.ip)
		updateHighlight(tab)
	end

	local function updateTabDisplay(tab)
		if not tab then return end
		renderVariables(tab.variables)
		renderBytecode(tab.bytecode, tab.ip)
		updateHighlight(tab)
	end

	local function updateTabButton(id, active)
		local tab = tabs[id]
		if tab and tab.button then
			if active then
				tab.button.BackgroundColor3 = Color3.fromHex("#1e1e1e")
				tab.button.TextColor3 = COLORS.text
			else
				tab.button.BackgroundColor3 = Color3.fromHex("#2d2d2d")
				tab.button.TextColor3 = COLORS.subtext
			end
		end
	end

	local ide = {}

	function ide:openTab(id, name)
		if tabs[id] then
			ide:switchTab(id)
			return
		end

		local interp = interpreters[id]
		local canClose = interp and interp.type ~= "player"

		local tabWidth = math.max(50, #name * 7 + (canClose and 24 or 8))
		local btn = Instance.new("TextButton")
		btn.Name = tostring(id)
		btn.Size = UDim2.new(0, tabWidth, 1, 0)
		btn.BackgroundColor3 = Color3.fromHex("#2d2d2d")
		btn.BorderSizePixel = 0
		btn.Text = " " .. name
		btn.TextColor3 = COLORS.subtext
		btn.Font = Enum.Font.Code
		btn.TextSize = 10
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.Parent = tabsScroll

		if canClose then
			local close = Instance.new("TextButton")
			close.Size = UDim2.new(0, 16, 1, 0)
			close.Position = UDim2.new(1, -16, 0, 0)
			close.BackgroundTransparency = 1
			close.Text = "×"
			close.TextColor3 = COLORS.subtext
			close.Parent = btn
			close.MouseButton1Click:Connect(function() ide:closeTab(id) end)
		end

		btn.MouseButton1Click:Connect(function() ide:switchTab(id) end)

		tabs[id] = {
			id = id,
			name = name,
			source = "",
			bytecode = nil,
			variables = {},
			ip = 0,
			button = btn,
		}
		table.insert(tabOrder, id)

		if callbacks.onTabOpen then
			callbacks.onTabOpen(id)
		end

		ide:switchTab(id)
	end

	function ide:switchTab(id)
		if currentTabId then
			updateTabButton(currentTabId, false)
		end

		currentTabId = id
		local tab = tabs[id]
		if tab then
			showEditor(true)
			updateTabButton(id, true)
			renderTab(tab)
		end
	end

	local function removeTab(id)
		local tab = tabs[id]
		if not tab then return end

		if tab.button then tab.button:Destroy() end
		tabs[id] = nil

		for i, tid in ipairs(tabOrder) do
			if tid == id then
				table.remove(tabOrder, i)
				break
			end
		end

		if currentTabId == id then
			if #tabOrder > 0 then
				ide:switchTab(tabOrder[#tabOrder])
			else
				currentTabId = nil
				showEditor(false)
			end
		end
	end

	function ide:closeTabSilent(id)
		removeTab(id)
	end

	function ide:closeTab(id)
		if callbacks.onTabClose then
			callbacks.onTabClose(id)
		end
		removeTab(id)
	end

	function ide:updateVM(id, state)
		local tab = tabs[id]
		if not tab then return end

		local shouldSetText = state.source and (tab.source == "" or tab.source == nil)
		if state.source then
			tab.source = state.source
		end
		if state.bytecode then
			tab.bytecode = state.bytecode
		end
		if state.variables then
			tab.variables = state.variables
		end
		if state.ip then
			tab.ip = state.ip
		elseif state.vm and state.vm.ip then
			tab.ip = state.vm.ip
		end

		if currentTabId == id then
			if shouldSetText then
				textBox.Text = tab.source or ""
			end
			updateTabDisplay(tab)
		end
	end

	function ide:getTab(id)
		return tabs[id]
	end

	function ide:getCurrentTabId()
		return currentTabId
	end

	function ide:getText()
		return textBox.Text
	end

	local function refreshExplorerInternal()
		clearChildren(fileList)
		local order = 0

		local function addHeader(txt)
			local l = Instance.new("TextLabel")
			l.Size = UDim2.new(1, 0, 0, 18)
			l.BackgroundTransparency = 1
			l.Text = "  " .. txt
			l.TextColor3 = COLORS.subtext
			l.Font = Enum.Font.GothamBold
			l.TextSize = 9
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.LayoutOrder = order
			l.Parent = fileList
			order = order + 1
		end

		local function addFile(pid, name, color)
			local btn = Instance.new("TextButton")
			btn.Name = tostring(pid)
			btn.Size = UDim2.new(1, 0, 0, 20)
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.LayoutOrder = order
			btn.Parent = fileList
			order = order + 1

			local icon = Instance.new("Frame")
			icon.Size = UDim2.new(0, 3, 0, 14)
			icon.Position = UDim2.new(0, 4, 0.5, -7)
			icon.BackgroundColor3 = color
			icon.BorderSizePixel = 0
			icon.Parent = btn

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -14, 1, 0)
			lbl.Position = UDim2.new(0, 14, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = name
			lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 11
			lbl.Active = false
			lbl.Parent = btn

			btn.MouseButton1Click:Connect(function()
				ide:openTab(pid, name)
			end)

			btn.MouseEnter:Connect(function()
				btn.BackgroundTransparency = 0.7
				btn.BackgroundColor3 = Color3.fromHex("#3c3c3c")
			end)
			btn.MouseLeave:Connect(function()
				btn.BackgroundTransparency = 1
			end)
		end

		local players, golems, bots = {}, {}, {}
		for pid, interp in pairs(interpreters) do
			if interp.type == "player" then
				table.insert(players, interp)
			elseif interp.type == "golem" then
				table.insert(golems, interp)
			elseif interp.type == "bot" then
				table.insert(bots, interp)
			end
		end

		table.sort(golems, function(a, b) return (a.spotId or 0) < (b.spotId or 0) end)
		table.sort(bots, function(a, b) return (a.spotId or 0) < (b.spotId or 0) end)

		addHeader("PLAYER")
		for _, p in ipairs(players) do
			addFile(p.pid, p.name or "shoot.py", THEMES.player.accent)
		end

		addHeader("TURRETS")
		for _, g in ipairs(golems) do
			addFile(g.pid, g.name or ("turret_" .. (g.spotId or "?") .. ".py"), THEMES.golem.accent)
		end

		addHeader("BOTS")
		for _, b in ipairs(bots) do
			addFile(b.pid, b.name or ("bot_" .. (b.spotId or "?") .. ".py"), THEMES.bot.accent)
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

		for pid, state in pairs(payload) do
			local isNew = not interpreters[pid]
			if isNew then
				interpreters[pid] = { pid = pid }
			end

			local interp = interpreters[pid]
			interp.type = state.type or interp.type
			interp.name = state.name or interp.name
			interp.spotId = state.spotId or interp.spotId
			interp.status = state.status
			interp.error = state.error
			interp.paused = state.paused
			interp.ip = state.ip
			interp.variables = state.variables or interp.variables
			interp.cpuHz = state.cpuHz or interp.cpuHz
			interp.maxBytecode = state.maxBytecode or interp.maxBytecode
			interp.tier = state.tier or interp.tier

			if state.source then
				interp.source = state.source
			end
			if state.bytecode then
				interp.bytecode = state.bytecode
			end
			if state.gen then
				interp.gen = state.gen
			end

			if isNew then
				ide:openTab(pid, interp.name or (interp.type .. ".py"))
			end

			if tabs[pid] then
				ide:updateVM(pid, interp)
			end
		end

		refreshExplorerInternal()
	end

	function ide:getInterpreter(pid)
		return interpreters[pid]
	end

	function ide:getInterpreterType(pid)
		local interp = interpreters[pid]
		return interp and interp.type
	end

	function ide:getCounts()
		local golemCount, botCount = 0, 0
		for _, interp in pairs(interpreters) do
			if interp.type == "golem" then
				golemCount = golemCount + 1
			elseif interp.type == "bot" then
				botCount = botCount + 1
			end
		end
		return golemCount, botCount
	end

	local collapsed = false
	function ide:toggle()
		collapsed = not collapsed
		if collapsed then
			TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0, 0, 1, -20)
			}):Play()
		else
			TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0, 0, 1 - IDE_HEIGHT_SCALE, 0)
			}):Play()
		end
	end

	collapseBtn.MouseButton1Click:Connect(function() ide:toggle() end)

	ide.frame = container
	ide.container = container
	ide.textBox = textBox

	return ide
end

return MainIDE
