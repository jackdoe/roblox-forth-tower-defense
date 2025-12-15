local UITheme = require(script.Parent.UITheme)

local EditorPanel = {}
local COLORS = UITheme.COLORS

function EditorPanel.create(parent)
	local panel = {}
	local isReadOnly = false
	local currentErrorLine = -1
	local currentExecLine = -1

	local frame = Instance.new("Frame")
	frame.Name = "EditorFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local lineScroll = Instance.new("ScrollingFrame")
	lineScroll.Name = "LineScroll"
	lineScroll.Size = UDim2.new(0, 40, 1, 0)
	lineScroll.BackgroundTransparency = 1
	lineScroll.BorderSizePixel = 0
	lineScroll.ScrollBarThickness = 0
	lineScroll.ScrollingEnabled = false
	lineScroll.Parent = frame

	local lineNumbers = Instance.new("TextLabel")
	lineNumbers.Name = "LineNumbers"
	lineNumbers.Size = UDim2.new(1, -4, 0, 0)
	lineNumbers.BackgroundTransparency = 1
	lineNumbers.Text = "1"
	lineNumbers.TextColor3 = COLORS.subtext
	lineNumbers.TextXAlignment = Enum.TextXAlignment.Right
	lineNumbers.TextYAlignment = Enum.TextYAlignment.Top
	lineNumbers.Font = Enum.Font.Code
	lineNumbers.TextSize = 13
	lineNumbers.RichText = true
	lineNumbers.AutomaticSize = Enum.AutomaticSize.Y
	lineNumbers.Parent = lineScroll

	local codeScroll = Instance.new("ScrollingFrame")
	codeScroll.Name = "CodeScroll"
	codeScroll.Size = UDim2.new(1, -45, 1, 0)
	codeScroll.Position = UDim2.new(0, 45, 0, 0)
	codeScroll.BackgroundTransparency = 1
	codeScroll.BorderSizePixel = 0
	codeScroll.ScrollBarThickness = 6
	codeScroll.ScrollBarImageColor3 = COLORS.subtext
	codeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	codeScroll.Parent = frame

	local textBox = Instance.new("TextBox")
	textBox.Name = "CodeInput"
	textBox.Size = UDim2.new(1, -10, 1, 0)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = ""
	textBox.TextColor3 = COLORS.text
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.Font = Enum.Font.Code
	textBox.TextSize = 13
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.TextWrapped = false
	textBox.Parent = codeScroll

	codeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		lineScroll.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
	end)

	local function updateLines()
		local text = textBox.Text
		local lines = 1
		for _ in string.gmatch(text, "\n") do lines = lines + 1 end

		local numStr = ""
		for i = 1, lines do
			if i == currentErrorLine then
				numStr = numStr .. '<font color="#FF5050">● ' .. i .. '</font>\n'
			elseif i == currentExecLine then
				numStr = numStr .. '<font color="#6A9955">▶ ' .. i .. '</font>\n'
			else
				numStr = numStr .. i .. "\n"
			end
		end

		lineNumbers.Text = numStr

		local h = math.max(codeScroll.AbsoluteWindowSize.Y, lines * 13 + 50)
		codeScroll.CanvasSize = UDim2.new(0, 0, 0, h)
		lineScroll.CanvasSize = UDim2.new(0, 0, 0, h)
		textBox.Size = UDim2.new(1, -10, 0, h)
	end

	textBox:GetPropertyChangedSignal("Text"):Connect(updateLines)

	function panel:getText() return textBox.Text end
	function panel:setText(t) textBox.Text = t; updateLines() end
	function panel:getFrame() return frame end
	function panel:getTextBox() return textBox end

	function panel:setReadOnly(ro)
		isReadOnly = ro
		textBox.TextEditable = not ro
		textBox.TextColor3 = ro and COLORS.subtext or COLORS.text
	end

	function panel:setErrorLine(line)
		currentErrorLine = line or -1
		updateLines()
	end

	function panel:setExecLine(line)
		currentExecLine = line or -1
		updateLines()
	end

	return panel
end

return EditorPanel
