-- TutorialPanel.luau
-- Interactive step-by-step Forth tutorial with stack visualization
-- Runs a client-side "sandbox" interpreter for safe, offline learning

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Forthy = ReplicatedStorage:WaitForChild("Forthy")
local TutorialData = require(Forthy:WaitForChild("TutorialData"))
local Interpreter = require(Forthy:WaitForChild("Interpreter"))
local Config = require(Forthy:WaitForChild("Config"))
local DragModule = require(script.Parent.DragModule)

local TutorialPanel = {}

function TutorialPanel.create(parent)
    local panel = {}
    local currentLessonIndex = 1
    local localInterp = nil

    -- Mock dependencies for the sandbox interpreter (no server access needed)
    local mockDeps = {
        Config = {
            DEFAULT_HP = 100,
            DEFAULT_MAX_STACK = 32,
        },
        GlobalMemory = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        -- No game words - tutorial only needs stack/math ops
    }

    -- 1. UI Construction
    local frame = Instance.new("Frame")
    frame.Name = "TutorialPanel"
    frame.Size = UDim2.new(0, 600, 0, 480)
    frame.Position = UDim2.new(0.5, -300, 0.5, -240)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 500
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 2
    stroke.Parent = frame

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    header.BorderSizePixel = 0
    header.Parent = frame
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 10)
    headerCorner.Parent = header

    DragModule.makeDraggable(frame, header)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "FORTH ACADEMY"
    titleLabel.Size = UDim2.new(1, 0, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.ZIndex = 501
    titleLabel.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "X"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.ZIndex = 502
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)

    -- Lesson Navigation
    local navFrame = Instance.new("Frame")
    navFrame.Name = "Navigation"
    navFrame.Size = UDim2.new(1, -20, 0, 40)
    navFrame.Position = UDim2.new(0, 10, 0, 50)
    navFrame.BackgroundTransparency = 1
    navFrame.Parent = frame

    local prevBtn = Instance.new("TextButton")
    prevBtn.Text = "< PREV"
    prevBtn.Size = UDim2.new(0, 80, 1, 0)
    prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    prevBtn.TextColor3 = Color3.new(1,1,1)
    prevBtn.Font = Enum.Font.GothamBold
    prevBtn.TextSize = 12
    prevBtn.ZIndex = 501
    prevBtn.Parent = navFrame
    Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 6)

    local nextBtn = Instance.new("TextButton")
    nextBtn.Text = "NEXT >"
    nextBtn.Size = UDim2.new(0, 80, 1, 0)
    nextBtn.Position = UDim2.new(1, -80, 0, 0)
    nextBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    nextBtn.TextColor3 = Color3.new(1,1,1)
    nextBtn.Font = Enum.Font.GothamBold
    nextBtn.TextSize = 12
    nextBtn.ZIndex = 501
    nextBtn.Parent = navFrame
    Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 6)

    local lessonTitle = Instance.new("TextLabel")
    lessonTitle.Name = "LessonTitle"
    lessonTitle.Size = UDim2.new(1, -180, 1, 0)
    lessonTitle.Position = UDim2.new(0, 90, 0, 0)
    lessonTitle.BackgroundTransparency = 1
    lessonTitle.TextColor3 = Color3.fromRGB(100, 220, 255)
    lessonTitle.Font = Enum.Font.GothamBold
    lessonTitle.TextSize = 16
    lessonTitle.ZIndex = 501
    lessonTitle.Parent = navFrame

    -- Content Area
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Size = UDim2.new(1, -20, 1, -170)
    contentFrame.Position = UDim2.new(0, 10, 0, 100)
    contentFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    contentFrame.ZIndex = 501
    contentFrame.Parent = frame
    Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 8)

    -- Description Text
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Size = UDim2.new(1, -20, 0, 70)
    descLabel.Position = UDim2.new(0, 10, 0, 10)
    descLabel.BackgroundTransparency = 1
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 13
    descLabel.TextWrapped = true
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.ZIndex = 502
    descLabel.Parent = contentFrame

    -- Code Visualizer (Token Strip)
    local codeContainer = Instance.new("ScrollingFrame")
    codeContainer.Name = "CodeStrip"
    codeContainer.Size = UDim2.new(1, -20, 0, 50)
    codeContainer.Position = UDim2.new(0, 10, 0, 85)
    codeContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    codeContainer.ScrollBarThickness = 4
    codeContainer.CanvasSize = UDim2.new(0,0,0,0)
    codeContainer.ZIndex = 502
    codeContainer.Parent = contentFrame
    Instance.new("UICorner", codeContainer).CornerRadius = UDim.new(0, 6)

    local codeLayout = Instance.new("UIListLayout")
    codeLayout.FillDirection = Enum.FillDirection.Horizontal
    codeLayout.Padding = UDim.new(0, 5)
    codeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    codeLayout.Parent = codeContainer

    local codePadding = Instance.new("UIPadding")
    codePadding.PaddingLeft = UDim.new(0, 10)
    codePadding.Parent = codeContainer

    -- Stack Visualizer
    local stackLabel = Instance.new("TextLabel")
    stackLabel.Text = "DATA STACK:"
    stackLabel.Size = UDim2.new(1, 0, 0, 20)
    stackLabel.Position = UDim2.new(0, 10, 0, 145)
    stackLabel.BackgroundTransparency = 1
    stackLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    stackLabel.Font = Enum.Font.Code
    stackLabel.TextSize = 12
    stackLabel.TextXAlignment = Enum.TextXAlignment.Left
    stackLabel.ZIndex = 502
    stackLabel.Parent = contentFrame

    local stackContainer = Instance.new("Frame")
    stackContainer.Name = "StackContainer"
    stackContainer.Size = UDim2.new(1, -20, 0, 60)
    stackContainer.Position = UDim2.new(0, 10, 0, 168)
    stackContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    stackContainer.ZIndex = 502
    stackContainer.Parent = contentFrame
    Instance.new("UICorner", stackContainer).CornerRadius = UDim.new(0, 6)

    local stackLayout = Instance.new("UIListLayout")
    stackLayout.FillDirection = Enum.FillDirection.Horizontal
    stackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    stackLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    stackLayout.Padding = UDim.new(0, 5)
    stackLayout.Parent = stackContainer

    local stackPadding = Instance.new("UIPadding")
    stackPadding.PaddingLeft = UDim.new(0, 10)
    stackPadding.Parent = stackContainer

    -- Output Display (for "." word)
    local outputLabel = Instance.new("TextLabel")
    outputLabel.Name = "OutputLabel"
    outputLabel.Text = "OUTPUT:"
    outputLabel.Size = UDim2.new(0, 60, 0, 20)
    outputLabel.Position = UDim2.new(0, 10, 0, 235)
    outputLabel.BackgroundTransparency = 1
    outputLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    outputLabel.Font = Enum.Font.Code
    outputLabel.TextSize = 12
    outputLabel.TextXAlignment = Enum.TextXAlignment.Left
    outputLabel.ZIndex = 502
    outputLabel.Parent = contentFrame

    local outputDisplay = Instance.new("TextLabel")
    outputDisplay.Name = "OutputDisplay"
    outputDisplay.Size = UDim2.new(1, -90, 0, 20)
    outputDisplay.Position = UDim2.new(0, 70, 0, 235)
    outputDisplay.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
    outputDisplay.Text = ""
    outputDisplay.TextColor3 = Color3.fromRGB(100, 255, 100)
    outputDisplay.Font = Enum.Font.Code
    outputDisplay.TextSize = 12
    outputDisplay.TextXAlignment = Enum.TextXAlignment.Left
    outputDisplay.ZIndex = 502
    outputDisplay.Parent = contentFrame
    Instance.new("UICorner", outputDisplay).CornerRadius = UDim.new(0, 4)
    local outputPadding = Instance.new("UIPadding")
    outputPadding.PaddingLeft = UDim.new(0, 6)
    outputPadding.Parent = outputDisplay

    -- Hint Text
    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "Hint"
    hintLabel.Size = UDim2.new(1, -20, 0, 40)
    hintLabel.Position = UDim2.new(0, 10, 1, -50)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.TextSize = 12
    hintLabel.TextWrapped = true
    hintLabel.TextXAlignment = Enum.TextXAlignment.Left
    hintLabel.ZIndex = 502
    hintLabel.Parent = contentFrame

    -- Bottom Controls (Step / Reset)
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "Controls"
    controlsFrame.Size = UDim2.new(1, -20, 0, 40)
    controlsFrame.Position = UDim2.new(0, 10, 1, -50)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.Parent = frame

    local stepBtn = Instance.new("TextButton")
    stepBtn.Name = "StepButton"
    stepBtn.Text = "STEP (Run 1 Word)"
    stepBtn.Size = UDim2.new(0.6, 0, 1, 0)
    stepBtn.Position = UDim2.new(0.2, 0, 0, 0)
    stepBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    stepBtn.TextColor3 = Color3.new(1,1,1)
    stepBtn.Font = Enum.Font.GothamBold
    stepBtn.TextSize = 14
    stepBtn.ZIndex = 501
    stepBtn.Parent = controlsFrame
    Instance.new("UICorner", stepBtn).CornerRadius = UDim.new(0, 6)

    local resetBtn = Instance.new("TextButton")
    resetBtn.Name = "ResetButton"
    resetBtn.Text = "RESET"
    resetBtn.Size = UDim2.new(0.18, 0, 1, 0)
    resetBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    resetBtn.TextColor3 = Color3.new(1,1,1)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 14
    resetBtn.ZIndex = 501
    resetBtn.Parent = controlsFrame
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

    -- 2. Logic Functions
    local previousStackSize = 0

    local function renderStack()
        -- Clear current visual stack
        for _, c in pairs(stackContainer:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        if not localInterp then return end

        local stackSize = localInterp.sp or 0

        -- Render new stack
        for i = 1, stackSize do
            local val = localInterp.stack[i]
            local box = Instance.new("Frame")
            box.Name = "StackItem" .. i
            box.Size = UDim2.new(0, 50, 0, 40)
            box.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            box.ZIndex = 503
            box.Parent = stackContainer
            Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1,0,1,0)
            txt.BackgroundTransparency = 1
            txt.Text = tostring(val)
            txt.TextColor3 = Color3.new(1,1,1)
            txt.Font = Enum.Font.Code
            txt.TextSize = 14
            txt.ZIndex = 504
            txt.Parent = box

            -- Animate new items appearing (stack grew)
            if i > previousStackSize then
                box.Size = UDim2.new(0, 0, 0, 0)
                TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = UDim2.new(0,50,0,40)}):Play()
            end
        end

        previousStackSize = stackSize

        -- Update output display
        outputDisplay.Text = localInterp.output or ""
    end

    local function renderTokens(tokens, currentIdx)
        -- Clear
        for _, c in pairs(codeContainer:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end

        if not tokens then return end

        local totalWidth = 0

        for i, token in ipairs(tokens) do
            local lbl = Instance.new("TextLabel")
            lbl.Name = "Token" .. i
            lbl.Text = token
            lbl.Font = Enum.Font.Code
            lbl.TextSize = 16
            lbl.AutomaticSize = Enum.AutomaticSize.X
            lbl.Size = UDim2.new(0, 0, 0, 30)
            lbl.BackgroundTransparency = 0.5
            lbl.ZIndex = 503
            lbl.Parent = codeContainer

            local lblPadding = Instance.new("UIPadding")
            lblPadding.PaddingLeft = UDim.new(0, 8)
            lblPadding.PaddingRight = UDim.new(0, 8)
            lblPadding.Parent = lbl

            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)

            -- Highlight current token
            if i == currentIdx then
                lbl.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                lbl.TextColor3 = Color3.new(0,0,0)
            elseif currentIdx and i < currentIdx then
                -- Completed tokens
                lbl.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
                lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
            else
                -- Future tokens
                lbl.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                lbl.TextColor3 = Color3.new(1,1,1)
            end

            totalWidth = totalWidth + 60 -- Approximate token width
        end

        codeContainer.CanvasSize = UDim2.new(0, totalWidth + 20, 0, 0)

        -- Scroll to keep active token in view
        if currentIdx then
            local scrollPos = math.max(0, (currentIdx - 2) * 60)
            codeContainer.CanvasPosition = Vector2.new(scrollPos, 0)
        end
    end

    local function loadLesson(index)
        currentLessonIndex = math.clamp(index, 1, #TutorialData.Lessons)
        local data = TutorialData.Lessons[currentLessonIndex]

        -- Update UI Text
        lessonTitle.Text = data.title
        descLabel.Text = data.desc
        hintLabel.Text = "HINT: " .. (data.hint or "")

        -- Initialize local interpreter with mock deps
        localInterp = Interpreter.new(nil, false, mockDeps)
        localInterp:load(data.code)

        -- Reset stack tracking
        previousStackSize = 0

        -- Initial Render
        renderStack()
        renderTokens(localInterp.tokens, 1)

        -- Button states
        prevBtn.Active = currentLessonIndex > 1
        prevBtn.BackgroundColor3 = prevBtn.Active and Color3.fromRGB(60,60,80) or Color3.fromRGB(40,40,40)

        if currentLessonIndex == #TutorialData.Lessons then
            nextBtn.Text = "FINISH"
            nextBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        else
            nextBtn.Text = "NEXT >"
            nextBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        end

        -- Reset step button
        stepBtn.Text = "STEP (Run 1 Word)"
        stepBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    end

    -- 3. Controls Wiring

    stepBtn.MouseButton1Click:Connect(function()
        if not localInterp then return end
        if localInterp.status == "DONE" or localInterp.status == "ERROR" then
            return -- Already done, click reset
        end

        -- Step the interpreter
        localInterp:step()

        renderStack()

        local currentTokenIdx = localInterp:getCurrentTokenIndex()
        if localInterp.status == "DONE" then
            -- Show all tokens as completed
            renderTokens(localInterp.tokens, #localInterp.tokens + 1)
        else
            renderTokens(localInterp.tokens, currentTokenIdx)
        end

        if localInterp.status == "DONE" then
            stepBtn.Text = "DONE! (Click Reset)"
            stepBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        elseif localInterp.status == "ERROR" then
            stepBtn.Text = "ERROR: " .. (localInterp.error or "?")
            stepBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end)

    resetBtn.MouseButton1Click:Connect(function()
        loadLesson(currentLessonIndex)
    end)

    prevBtn.MouseButton1Click:Connect(function()
        if currentLessonIndex > 1 then
            loadLesson(currentLessonIndex - 1)
        end
    end)

    nextBtn.MouseButton1Click:Connect(function()
        if currentLessonIndex == #TutorialData.Lessons then
            frame.Visible = false
        else
            loadLesson(currentLessonIndex + 1)
        end
    end)

    -- Public Interface
    function panel:open()
        frame.Visible = true
        loadLesson(currentLessonIndex)
    end

    function panel:close()
        frame.Visible = false
    end

    function panel:isVisible()
        return frame.Visible
    end

    panel.frame = frame

    return panel
end

return TutorialPanel
