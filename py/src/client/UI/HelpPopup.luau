-- HelpPopup.luau
-- Interactive help system for Python TD commands

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local HelpDatabase = require(PythonTD.HelpDatabase)

local HelpPopup = {}

function HelpPopup.create(parent, dragModule)
	local popup = {}

	-- Main frame
	local helpPopup = Instance.new("Frame")
	helpPopup.Name = "HelpPopup"
	helpPopup.Size = UDim2.new(0, 550, 0, 450)
	helpPopup.Position = UDim2.new(0.5, -275, 0.5, -225)
	helpPopup.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	helpPopup.BorderSizePixel = 0
	helpPopup.Visible = false
	helpPopup.ZIndex = 300
	helpPopup.Parent = parent

	local helpCorner = Instance.new("UICorner")
	helpCorner.CornerRadius = UDim.new(0, 10)
	helpCorner.Parent = helpPopup

	local helpStroke = Instance.new("UIStroke")
	helpStroke.Color = Color3.fromRGB(100, 150, 255)
	helpStroke.Thickness = 2
	helpStroke.Parent = helpPopup

	-- Header
	local helpHeader = Instance.new("Frame")
	helpHeader.Name = "Header"
	helpHeader.Size = UDim2.new(1, 0, 0, 40)
	helpHeader.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	helpHeader.BorderSizePixel = 0
	helpHeader.Parent = helpPopup

	local helpHeaderCorner = Instance.new("UICorner")
	helpHeaderCorner.CornerRadius = UDim.new(0, 10)
	helpHeaderCorner.Parent = helpHeader

	if dragModule then
		dragModule.makeDraggable(helpPopup, helpHeader)
	end

	local helpTitle = Instance.new("TextLabel")
	helpTitle.Name = "Title"
	helpTitle.Size = UDim2.new(0, 150, 1, 0)
	helpTitle.Position = UDim2.new(0, 15, 0, 0)
	helpTitle.BackgroundTransparency = 1
	helpTitle.Text = "PYTHON HELP"
	helpTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
	helpTitle.TextXAlignment = Enum.TextXAlignment.Left
	helpTitle.Font = Enum.Font.GothamBold
	helpTitle.TextSize = 16
	helpTitle.ZIndex = 301
	helpTitle.Parent = helpHeader

	-- Search box
	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(0, 200, 0, 26)
	searchBox.Position = UDim2.new(0, 170, 0, 7)
	searchBox.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	searchBox.Text = ""
	searchBox.PlaceholderText = "Search words..."
	searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	searchBox.TextColor3 = Color3.fromRGB(220, 220, 240)
	searchBox.Font = Enum.Font.Code
	searchBox.TextSize = 13
	searchBox.ClearTextOnFocus = false
	searchBox.ZIndex = 301
	searchBox.Parent = helpHeader

	local searchBoxCorner = Instance.new("UICorner")
	searchBoxCorner.CornerRadius = UDim.new(0, 4)
	searchBoxCorner.Parent = searchBox

	local searchBoxPadding = Instance.new("UIPadding")
	searchBoxPadding.PaddingLeft = UDim.new(0, 8)
	searchBoxPadding.Parent = searchBox

	-- Back button (hidden initially)
	local backBtn = Instance.new("TextButton")
	backBtn.Name = "BackBtn"
	backBtn.Size = UDim2.new(0, 60, 0, 26)
	backBtn.Position = UDim2.new(0, 380, 0, 7)
	backBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	backBtn.Text = "< BACK"
	backBtn.TextColor3 = Color3.fromRGB(180, 180, 220)
	backBtn.Font = Enum.Font.GothamBold
	backBtn.TextSize = 10
	backBtn.Visible = false
	backBtn.ZIndex = 301
	backBtn.Parent = helpHeader

	local backBtnCorner = Instance.new("UICorner")
	backBtnCorner.CornerRadius = UDim.new(0, 4)
	backBtnCorner.Parent = backBtn

	local helpCloseBtn = Instance.new("TextButton")
	helpCloseBtn.Name = "CloseBtn"
	helpCloseBtn.Size = UDim2.new(0, 30, 0, 30)
	helpCloseBtn.Position = UDim2.new(1, -35, 0, 5)
	helpCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
	helpCloseBtn.Text = "X"
	helpCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	helpCloseBtn.Font = Enum.Font.GothamBold
	helpCloseBtn.TextSize = 14
	helpCloseBtn.ZIndex = 301
	helpCloseBtn.Parent = helpHeader

	local helpCloseBtnCorner = Instance.new("UICorner")
	helpCloseBtnCorner.CornerRadius = UDim.new(0, 6)
	helpCloseBtnCorner.Parent = helpCloseBtn

	helpCloseBtn.MouseButton1Click:Connect(function()
		helpPopup.Visible = false
	end)

	-- Content area
	local helpContent = Instance.new("ScrollingFrame")
	helpContent.Name = "Content"
	helpContent.Size = UDim2.new(1, -20, 1, -50)
	helpContent.Position = UDim2.new(0, 10, 0, 45)
	helpContent.BackgroundTransparency = 1
	helpContent.ScrollBarThickness = 6
	helpContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	helpContent.ZIndex = 301
	helpContent.Parent = helpPopup

	local helpLayout = Instance.new("UIListLayout")
	helpLayout.Padding = UDim.new(0, 4)
	helpLayout.SortOrder = Enum.SortOrder.LayoutOrder
	helpLayout.Parent = helpContent

	-- Forward declare for mutual reference
	local showWordHelp
	local showFilteredWords

	-- Function to show help for a specific word
	showWordHelp = function(word)
		-- Clear content
		for _, child in ipairs(helpContent:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local info = HelpDatabase.getWordHelp(word)
		if not info then
			local notFound = Instance.new("TextLabel")
			notFound.Size = UDim2.new(1, 0, 0, 40)
			notFound.BackgroundTransparency = 1
			notFound.Text = "Word '" .. word .. "' not found"
			notFound.TextColor3 = Color3.fromRGB(255, 150, 150)
			notFound.Font = Enum.Font.Gotham
			notFound.TextSize = 14
			notFound.ZIndex = 302
			notFound.Parent = helpContent
			helpContent.CanvasSize = UDim2.new(0, 0, 0, 50)
			return
		end

		helpTitle.Text = "HELP: " .. word
		backBtn.Visible = true
		searchBox.Visible = false

		-- Word name
		local wordLabel = Instance.new("TextLabel")
		wordLabel.Size = UDim2.new(1, 0, 0, 35)
		wordLabel.BackgroundTransparency = 1
		wordLabel.Text = word
		wordLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		wordLabel.Font = Enum.Font.Code
		wordLabel.TextSize = 24
		wordLabel.TextXAlignment = Enum.TextXAlignment.Left
		wordLabel.ZIndex = 302
		wordLabel.Parent = helpContent

		-- Stack effect
		local stackLabel = Instance.new("TextLabel")
		stackLabel.Size = UDim2.new(1, 0, 0, 25)
		stackLabel.BackgroundTransparency = 1
		stackLabel.Text = info.stack
		stackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		stackLabel.Font = Enum.Font.Code
		stackLabel.TextSize = 14
		stackLabel.TextXAlignment = Enum.TextXAlignment.Left
		stackLabel.ZIndex = 302
		stackLabel.Parent = helpContent

		-- Category
		local catLabel = Instance.new("TextLabel")
		catLabel.Size = UDim2.new(1, 0, 0, 20)
		catLabel.BackgroundTransparency = 1
		catLabel.Text = "Category: " .. (info.category or "General")
		catLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
		catLabel.Font = Enum.Font.Gotham
		catLabel.TextSize = 11
		catLabel.TextXAlignment = Enum.TextXAlignment.Left
		catLabel.ZIndex = 302
		catLabel.Parent = helpContent

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, 0, 0, 50)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = info.desc
		descLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextSize = 14
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.TextWrapped = true
		descLabel.ZIndex = 302
		descLabel.Parent = helpContent

		-- Example header
		local exHeader = Instance.new("TextLabel")
		exHeader.Size = UDim2.new(1, 0, 0, 25)
		exHeader.BackgroundTransparency = 1
		exHeader.Text = "Example:"
		exHeader.TextColor3 = Color3.fromRGB(150, 200, 255)
		exHeader.Font = Enum.Font.GothamBold
		exHeader.TextSize = 12
		exHeader.TextXAlignment = Enum.TextXAlignment.Left
		exHeader.ZIndex = 302
		exHeader.Parent = helpContent

		-- Example code
		local exCode = Instance.new("TextLabel")
		exCode.Size = UDim2.new(1, 0, 0, 60)
		exCode.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		exCode.Text = "  " .. info.example
		exCode.TextColor3 = Color3.fromRGB(200, 200, 220)
		exCode.Font = Enum.Font.Code
		exCode.TextSize = 13
		exCode.TextXAlignment = Enum.TextXAlignment.Left
		exCode.TextYAlignment = Enum.TextYAlignment.Top
		exCode.TextWrapped = true
		exCode.ZIndex = 302
		exCode.Parent = helpContent

		local exCodeCorner = Instance.new("UICorner")
		exCodeCorner.CornerRadius = UDim.new(0, 4)
		exCodeCorner.Parent = exCode

		helpContent.CanvasSize = UDim2.new(0, 0, 0, 250)
	end

	-- Helper to create a word row
	local function createWordRow(wordInfo, layoutOrder)
		local wordBtn = Instance.new("TextButton")
		wordBtn.Size = UDim2.new(1, 0, 0, 28)
		wordBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		wordBtn.Text = ""
		wordBtn.ZIndex = 302
		wordBtn.LayoutOrder = layoutOrder
		wordBtn.Parent = helpContent

		local wordBtnCorner = Instance.new("UICorner")
		wordBtnCorner.CornerRadius = UDim.new(0, 4)
		wordBtnCorner.Parent = wordBtn

		local wordName = Instance.new("TextLabel")
		wordName.Size = UDim2.new(0, 90, 1, 0)
		wordName.Position = UDim2.new(0, 8, 0, 0)
		wordName.BackgroundTransparency = 1
		wordName.Text = wordInfo.word
		wordName.TextColor3 = Color3.fromRGB(100, 255, 100)
		wordName.Font = Enum.Font.Code
		wordName.TextSize = 12
		wordName.TextXAlignment = Enum.TextXAlignment.Left
		wordName.ZIndex = 303
		wordName.Parent = wordBtn

		local wordStack = Instance.new("TextLabel")
		wordStack.Size = UDim2.new(0, 130, 1, 0)
		wordStack.Position = UDim2.new(0, 100, 0, 0)
		wordStack.BackgroundTransparency = 1
		wordStack.Text = wordInfo.info.stack
		wordStack.TextColor3 = Color3.fromRGB(255, 200, 100)
		wordStack.Font = Enum.Font.Code
		wordStack.TextSize = 10
		wordStack.TextXAlignment = Enum.TextXAlignment.Left
		wordStack.ZIndex = 303
		wordStack.Parent = wordBtn

		local wordDesc = Instance.new("TextLabel")
		wordDesc.Size = UDim2.new(1, -240, 1, 0)
		wordDesc.Position = UDim2.new(0, 235, 0, 0)
		wordDesc.BackgroundTransparency = 1
		wordDesc.Text = wordInfo.info.desc
		wordDesc.TextColor3 = Color3.fromRGB(160, 160, 180)
		wordDesc.Font = Enum.Font.Gotham
		wordDesc.TextSize = 10
		wordDesc.TextXAlignment = Enum.TextXAlignment.Left
		wordDesc.TextTruncate = Enum.TextTruncate.AtEnd
		wordDesc.ZIndex = 303
		wordDesc.Parent = wordBtn

		wordBtn.MouseButton1Click:Connect(function()
			showWordHelp(wordInfo.word)
		end)

		return wordBtn
	end

	-- Function to show filtered words (for search)
	showFilteredWords = function(filter)
		-- Clear content
		for _, child in ipairs(helpContent:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		helpTitle.Text = "PYTHON HELP"
		backBtn.Visible = false
		searchBox.Visible = true

		local filterUpper = filter and string.upper(filter) or ""
		local totalHeight = 0
		local hasResults = false
		local layoutOrder = 0

		for _, category in ipairs(HelpDatabase.categories) do
			local words = HelpDatabase.getWordsInCategory(category)
			local matchingWords = {}

			-- Filter words if search is active
			for _, wordInfo in ipairs(words) do
				if filterUpper == "" or string.find(string.upper(wordInfo.word), filterUpper, 1, true)
					or string.find(string.upper(wordInfo.info.desc), filterUpper, 1, true) then
					table.insert(matchingWords, wordInfo)
				end
			end

			if #matchingWords > 0 then
				hasResults = true

				-- Category header
				local catHeader = Instance.new("TextLabel")
				catHeader.Size = UDim2.new(1, 0, 0, 22)
				catHeader.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
				catHeader.Text = "  " .. category .. " (" .. #matchingWords .. ")"
				catHeader.TextColor3 = Color3.fromRGB(100, 200, 255)
				catHeader.Font = Enum.Font.GothamBold
				catHeader.TextSize = 11
				catHeader.TextXAlignment = Enum.TextXAlignment.Left
				catHeader.ZIndex = 302
				catHeader.LayoutOrder = layoutOrder
				catHeader.Parent = helpContent
				totalHeight = totalHeight + 26
				layoutOrder = layoutOrder + 1

				local catCorner = Instance.new("UICorner")
				catCorner.CornerRadius = UDim.new(0, 4)
				catCorner.Parent = catHeader

				-- Words in this category (always expanded)
				for _, wordInfo in ipairs(matchingWords) do
					createWordRow(wordInfo, layoutOrder)
					totalHeight = totalHeight + 32
					layoutOrder = layoutOrder + 1
				end
			end
		end

		if not hasResults then
			local noResults = Instance.new("TextLabel")
			noResults.Size = UDim2.new(1, 0, 0, 40)
			noResults.BackgroundTransparency = 1
			noResults.Text = "No words found matching '" .. filter .. "'"
			noResults.TextColor3 = Color3.fromRGB(180, 150, 150)
			noResults.Font = Enum.Font.Gotham
			noResults.TextSize = 13
			noResults.ZIndex = 302
			noResults.LayoutOrder = 0
			noResults.Parent = helpContent
			totalHeight = 50
		end

		helpContent.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
	end

	-- Search box handler
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		showFilteredWords(searchBox.Text)
	end)

	-- Back button handler
	backBtn.MouseButton1Click:Connect(function()
		searchBox.Text = ""
		showFilteredWords("")
	end)

	-- Public API
	function popup.show(targetWord)
		helpPopup.Visible = true
		searchBox.Text = ""
		if targetWord then
			showWordHelp(targetWord)
		else
			showFilteredWords("")
		end
	end

	function popup.hide()
		helpPopup.Visible = false
	end

	function popup.isVisible()
		return helpPopup.Visible
	end

	popup.frame = helpPopup

	return popup
end

return HelpPopup
