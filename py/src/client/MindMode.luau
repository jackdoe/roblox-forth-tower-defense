local ClientState = require(script.Parent.ClientState)
local WeaponSystem = require(script.Parent.WeaponSystem)

local MindMode = {}

local rangeRing = nil

local function createRangeRing(position, range)
	local ring = Instance.new("Part")
	ring.Name = "GolemMindRangeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, range * 2, range * 2)
	ring.CFrame = CFrame.new(position.X, 0.3, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(100, 200, 255)
	ring.Transparency = 0.7
	ring.Parent = workspace
	return ring
end

local function destroyRangeRing()
	if rangeRing then
		rangeRing:Destroy()
		rangeRing = nil
	end
end

function MindMode.enterGolem(golemId, golemStates, editor, program, bytecodePanel, golemRegisterViewerEvent, golemUnregisterViewerEvent, botUnregisterViewerEvent)
	local golemData = golemStates[golemId]
	if not golemData then return false end

	if ClientState.currentInterpreterTarget.type == "bot" then
		botUnregisterViewerEvent:FireServer(ClientState.currentInterpreterTarget.botId)
	elseif ClientState.currentInterpreterTarget.type == "golem" and ClientState.currentInterpreterTarget.golemId ~= golemId then
		golemUnregisterViewerEvent:FireServer(ClientState.currentInterpreterTarget.golemId)
	end

	if ClientState.currentInterpreterTarget.type == "player" then
		ClientState.savedPlayerProgram = editor:getText()
	end
	ClientState.golemProgramLoaded = false

	ClientState.currentInterpreterTarget = {
		type = "golem",
		golemId = golemId,
		spotId = golemData.spotId
	}

	golemRegisterViewerEvent:FireServer(golemId)

	editor:setMode("golem", golemData.spotId, golemData.maxBytecode)
	program:setTheme("golem")
	bytecodePanel:setTheme("golem")

	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("GolemId") == golemId then
			local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if hrp then
				destroyRangeRing()
				rangeRing = createRangeRing(hrp.Position, golemData.dynamicRange or 40)
			end
			break
		end
	end

	return true
end

function MindMode.exitGolem(editor, program, bytecodePanel, golemUnregisterViewerEvent)
	if ClientState.currentInterpreterTarget.type ~= "golem" then return end

	local golemId = ClientState.currentInterpreterTarget.golemId

	ClientState.currentInterpreterTarget = {
		type = "player",
		golemId = nil,
		spotId = nil,
	}

	golemUnregisterViewerEvent:FireServer(golemId)

	editor:setMode("player")
	program:setTheme("player")
	bytecodePanel:setTheme("player")

	destroyRangeRing()

	WeaponSystem.restoreCurrent(editor)
	ClientState.golemProgramLoaded = false
end

function MindMode.enterBot(botId, botStates, editor, program, bytecodePanel, botRegisterViewerEvent, botUnregisterViewerEvent, golemUnregisterViewerEvent)
	local botData = botStates[botId]
	if not botData then return false end

	if ClientState.currentInterpreterTarget.type == "golem" then
		MindMode.exitGolem(editor, program, bytecodePanel, golemUnregisterViewerEvent)
	elseif ClientState.currentInterpreterTarget.type == "bot" and ClientState.currentInterpreterTarget.botId ~= botId then
		botUnregisterViewerEvent:FireServer(ClientState.currentInterpreterTarget.botId)
	end

	if ClientState.currentInterpreterTarget.type == "player" then
		ClientState.savedPlayerProgram = editor:getText()
	end
	ClientState.golemProgramLoaded = false

	ClientState.currentInterpreterTarget = {
		type = "bot",
		golemId = nil,
		botId = botId,
		spotId = botData.spotId,
	}

	botRegisterViewerEvent:FireServer(botId)

	editor:setMode("bot", botData.spotId, botData.maxBytecode)
	program:setTheme("bot")
	bytecodePanel:setTheme("bot")

	return true
end

function MindMode.exitBot(editor, program, bytecodePanel, botUnregisterViewerEvent)
	if ClientState.currentInterpreterTarget.type ~= "bot" then return end

	local botId = ClientState.currentInterpreterTarget.botId

	ClientState.currentInterpreterTarget = {
		type = "player",
		golemId = nil,
		botId = nil,
		spotId = nil,
	}

	botUnregisterViewerEvent:FireServer(botId)

	editor:setMode("player")
	program:setTheme("player")
	bytecodePanel:setTheme("player")

	WeaponSystem.restoreCurrent(editor)
	ClientState.golemProgramLoaded = false
end

function MindMode.updateRangeRing(golemStates)
	if ClientState.currentInterpreterTarget.type ~= "golem" or not rangeRing then return end

	local golemId = ClientState.currentInterpreterTarget.golemId
	local golemData = golemStates[golemId]
	if not golemData then return end

	local currentRange = golemData.dynamicRange or 40
	rangeRing.Size = Vector3.new(0.5, currentRange * 2, currentRange * 2)

	local powerMultiplier = 40 / currentRange
	if powerMultiplier >= 2 then
		rangeRing.Color = Color3.fromRGB(255, 100, 100)
	elseif powerMultiplier >= 1 then
		rangeRing.Color = Color3.fromRGB(255, 200, 100)
	else
		rangeRing.Color = Color3.fromRGB(100, 200, 255)
	end
end

function MindMode.getRangeRing()
	return rangeRing
end

return MindMode
