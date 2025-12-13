local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local SoundConfig = require(PythonTD.SoundConfig)

local EditorPanel = require(script.Parent.UI.EditorPanel)
local ProgramPanel = require(script.Parent.UI.ProgramPanel)
local BytecodePanel = require(script.Parent.UI.BytecodePanel)
local HUD = require(script.Parent.UI.HUD)
local HelpPopup = require(script.Parent.UI.HelpPopup)
local Effects = require(script.Parent.Effects)
local PlayerHpBillboard = require(script.Parent.PlayerHpBillboard)
local DragModule = require(script.Parent.UI.DragModule)
local GridNavigator = require(script.Parent.GridNavigator)

local ClientState = require(script.Parent.ClientState)
local WeaponSystem = require(script.Parent.WeaponSystem)
local PlacementSystem = require(script.Parent.PlacementSystem)
local MindMode = require(script.Parent.MindMode)
local Overlays = require(script.Parent.Overlays)

local runProgramEvent = PythonTD:WaitForChild("RunProgram")
local pauseProgramEvent = PythonTD:WaitForChild("PauseProgram")
local stepProgramEvent = PythonTD:WaitForChild("StepProgram")
local resetProgramEvent = PythonTD:WaitForChild("ResetProgram")
local stateUpdateEvent = PythonTD:WaitForChild("StateUpdate")
local attackHitEvent = PythonTD:WaitForChild("AttackHit")
local playerHurtEvent = PythonTD:WaitForChild("PlayerHurt")
local beepEvent = PythonTD:WaitForChild("Beep")
local playAnimationEvent = PythonTD:WaitForChild("PlayAnimation")
local manualAttackEvent = PythonTD:WaitForChild("ManualAttack")
local playerFireEvent = PythonTD:WaitForChild("PlayerFire")

local golemStateEvent = PythonTD:WaitForChild("GolemState")
local playerReadyEvent = PythonTD:WaitForChild("PlayerReady")
local skipBuildEvent = PythonTD:WaitForChild("SkipBuild")
local golemPlaceAtEvent = PythonTD:WaitForChild("GolemPlaceAt")
local golemSellEvent = PythonTD:WaitForChild("GolemSell")
local enterBuildModeEvent = PythonTD:WaitForChild("EnterBuildMode")
local playerTeleportEvent = PythonTD:WaitForChild("PlayerTeleport")
local playerMoveCompleteEvent = PythonTD:WaitForChild("PlayerMoveComplete")

local golemRegisterViewerEvent = PythonTD:WaitForChild("GolemRegisterViewer")
local golemUnregisterViewerEvent = PythonTD:WaitForChild("GolemUnregisterViewer")
local golemMoveEvent = PythonTD:WaitForChild("GolemMove")
local golemUpgradeEvent = PythonTD:WaitForChild("GolemUpgrade")
local golemAmmoChangeEvent = PythonTD:WaitForChild("GolemAmmoChange")
local golemFullStateEvent = PythonTD:WaitForChild("GolemFullState")

local requestStateEvent = PythonTD:WaitForChild("RequestState")

local botStateEvent = PythonTD:WaitForChild("BotState")
local botBuildEvent = PythonTD:WaitForChild("BotBuild")
local botSellEvent = PythonTD:WaitForChild("BotSell")
local botRegisterViewerEvent = PythonTD:WaitForChild("BotRegisterViewer")
local botUnregisterViewerEvent = PythonTD:WaitForChild("BotUnregisterViewer")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PythonTDGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local helpPopup = HelpPopup.create(screenGui, DragModule)

local editor, program, bytecodePanel, hud, hpBillboard

local function showBytecodePanel()
	if not ClientState.bytecodeUserOverride then
		ClientState.bytecodeVisible = true
		bytecodePanel:setVisible(true)
		program:setBytecodeVisible(true)
	end
end

local function loadWeapon(index)
	WeaponSystem.load(index, editor, hud, runProgramEvent)
end

local function enterGolemMind(golemId)
	return MindMode.enterGolem(golemId, ClientState.golemStates, editor, program, bytecodePanel, golemRegisterViewerEvent, golemUnregisterViewerEvent, botUnregisterViewerEvent)
end

local function exitGolemMind()
	MindMode.exitGolem(editor, program, bytecodePanel, golemUnregisterViewerEvent)
end

local function enterBotMind(botId)
	return MindMode.enterBot(botId, ClientState.botStates, editor, program, bytecodePanel, botRegisterViewerEvent, botUnregisterViewerEvent, golemUnregisterViewerEvent)
end

local function exitBotMind()
	MindMode.exitBot(editor, program, bytecodePanel, botUnregisterViewerEvent)
end

editor = EditorPanel.create(screenGui, {
	onLoad = function(source)
		runProgramEvent:FireServer(source, ClientState.currentInterpreterTarget)
	end,
	onStep = function(source)
		stepProgramEvent:FireServer(source, ClientState.currentInterpreterTarget)
		showBytecodePanel()
	end,
	onPause = function()
		pauseProgramEvent:FireServer(ClientState.currentInterpreterTarget)
	end,
	onReset = function()
		resetProgramEvent:FireServer()
	end,
	onHelp = function()
		helpPopup.show(nil)
	end,
})

program = ProgramPanel.create(screenGui)
bytecodePanel = BytecodePanel.create(screenGui)

bytecodePanel:setVisible(false)
program:setBytecodeVisible(false)

program.onBytecodeToggle = function()
	ClientState.bytecodeVisible = not ClientState.bytecodeVisible
	ClientState.bytecodeUserOverride = true
	bytecodePanel:setVisible(ClientState.bytecodeVisible)
	program:setBytecodeVisible(ClientState.bytecodeVisible)
end

hud = HUD.create(screenGui, {
	onBuildTurret = function()
		PlacementSystem.enterTurretMode(Overlays.showNotification)
	end,
	onBuildBot = function()
		PlacementSystem.enterBotMode(Overlays.showNotification)
	end,
	onEditCode = function(id, unitType)
		if unitType == "golem" then
			enterGolemMind(id)
		elseif unitType == "bot" then
			enterBotMind(id)
		end
	end,
	onMove = function(id, unitType)
		if unitType == "golem" then
			ClientState.isMovingGolem = true
			ClientState.movingGolemId = id
			hud.deselect()
		end
	end,
	onSell = function(id, unitType)
		if unitType == "golem" then
			golemSellEvent:FireServer(id)
		elseif unitType == "bot" then
			botSellEvent:FireServer(id)
		end
		hud.deselect()
	end,
	onUpgrade = function(id, unitType)
		if unitType == "golem" then
			golemUpgradeEvent:FireServer(id)
		end
	end,
	onAmmoChange = function(golemId, ammoType, ammoName)
		if golemId and ammoType then
			golemAmmoChangeEvent:FireServer(golemId, ammoType)
		end
	end,
	onReady = function()
		playerReadyEvent:FireServer()
	end,
	onSkipBuild = function()
		skipBuildEvent:FireServer()
	end,
	onLoadWeapon = function(weaponIndex)
		loadWeapon(weaponIndex)
	end,
	onBotSelect = function(slotNum)
		for botId, botData in pairs(ClientState.botStates) do
			if botData.spotId == slotNum then
				hud.select({
					id = botId,
					type = "bot",
					name = "BOT #" .. slotNum,
					spotId = slotNum,
					status = botData.status or "IDLE",
					cargo = botData.scrapInventory or 0,
				})
				enterBotMind(botId)
				return
			end
		end
	end,
})

Overlays.create(screenGui)

editor.onExitGolem = function()
	if ClientState.currentInterpreterTarget.type == "bot" then
		exitBotMind()
	elseif ClientState.currentInterpreterTarget.type == "golem" then
		exitGolemMind()
	end
end

editor.onSellGolem = function()
	if ClientState.currentInterpreterTarget.type == "bot" and ClientState.currentInterpreterTarget.botId then
		botSellEvent:FireServer(ClientState.currentInterpreterTarget.botId)
	elseif ClientState.currentInterpreterTarget.type == "golem" and ClientState.currentInterpreterTarget.golemId then
		golemSellEvent:FireServer(ClientState.currentInterpreterTarget.golemId)
	end
end

editor.onMoveGolem = function()
	if ClientState.currentInterpreterTarget.type == "golem" and ClientState.currentInterpreterTarget.golemId then
		ClientState.isMovingGolem = true
		ClientState.movingGolemId = ClientState.currentInterpreterTarget.golemId
	end
end

local function setupHpBillboard()
	if hpBillboard then hpBillboard:destroy() end
	if player.Character then
		hpBillboard = PlayerHpBillboard.create(player.Character)
	end
end

player.CharacterAdded:Connect(setupHpBillboard)
if player.Character then setupHpBillboard() end

stateUpdateEvent.OnClientEvent:Connect(function(state)
	program:update(state)
	bytecodePanel:update(state)
	editor:setPaused(state.paused)

	local target = ClientState.currentInterpreterTarget
	local isTargetingGolem = (target.type == "golem")
	local isTargetingBot = (target.type == "bot")
	local isTargetingPlayer = (target.type == "player")

	if state.isGolem and isTargetingGolem and state.golemId == target.golemId and not ClientState.golemProgramLoaded and state.source then
		editor:setTextFormatted(state.source)
		ClientState.golemProgramLoaded = true
	end

	if state.isBot and isTargetingBot and state.botId == target.botId and not ClientState.golemProgramLoaded and state.source then
		editor:setTextFormatted(state.source)
		ClientState.golemProgramLoaded = true
	end

	if isTargetingPlayer and not state.isGolem and not state.isBot and not ClientState.playerProgramLoaded and state.source then
		editor:setTextFormatted(state.source)
		ClientState.playerProgramLoaded = true
	end

	if hpBillboard then
		hpBillboard:update(state.hp or 100, state.maxHp or 100)
	end

	if state.waveNumber then
		ClientState.currentPhase = state.phase or "LOBBY"

		hud.updateWave(state.waveNumber, state.wavePreview)
		hud.updateCore(state.coreHp or 0, state.coreMaxHp or 1000)

		local buildTimer = nil
		if state.buildTimeRemaining and state.buildTimeRemaining > 0 then
			buildTimer = math.ceil(state.buildTimeRemaining)
		end
		hud.updatePhase(state.phase or "LOBBY", buildTimer)

		if state.nextWavePreview and state.nextWaveNumber then
			hud.updateNextWave(state.nextWaveNumber, state.nextWavePreview)
		end

		ClientState.currentScrap = state.scrap or 0

		if state.scrapInventory then
			hud.updateCargo(state.scrapInventory, state.maxCapacity or 50)
		end

		Overlays.updateGameState(state.phase, state.restartTimeRemaining)
	end

	Overlays.updateDeath(state.dead, state.deathTimeRemaining)

	if state.dead then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		end
	else
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid.WalkSpeed == 0 then
				humanoid.WalkSpeed = Config.MANUAL_WALKING_SPEED
				humanoid.JumpPower = 50
			end
		end
	end
end)

local previousTurretCount = 0
golemStateEvent.OnClientEvent:Connect(function(data)
	ClientState.golemStates = {}
	ClientState.golemStatesRaw = {}
	ClientState.currentTurretCount = 0

	if data and data.golems then
		ClientState.golemStatesRaw = data.golems
		for _, golem in ipairs(data.golems) do
			ClientState.golemStates[golem.id] = golem
			ClientState.currentTurretCount = ClientState.currentTurretCount + 1
		end
	end

	if data and data.nextTurretCost then
		ClientState.nextTurretCost = data.nextTurretCost
	end

	hud.updateEconomy(ClientState.currentScrap, ClientState.nextTurretCost, 75)

	if ClientState.currentTurretCount >= ClientState.MAX_TURRETS and previousTurretCount < ClientState.MAX_TURRETS then
		Overlays.showNotification("TURRET LIMIT REACHED", "Max " .. ClientState.MAX_TURRETS .. " turrets!", "Sell a turret to build more", 4)
	end
	previousTurretCount = ClientState.currentTurretCount

	MindMode.updateRangeRing(ClientState.golemStates)

	if hud.selection and hud.selection.type == "golem" then
		local golemData = ClientState.golemStates[hud.selection.id]
		if golemData then
			hud.select({
				id = golemData.id,
				type = "golem",
				spotId = golemData.spotId,
				ammo = golemData.ammo,
				maxAmmo = golemData.maxAmmo or 300,
				dynamicRange = golemData.dynamicRange or 40,
				status = golemData.paused and "PAUSED" or "ACTIVE",
				tier = golemData.tier or 1,
				tierName = golemData.tierName or "Basic",
				upgradeCost = golemData.upgradeCost,
			})
		end
	end
end)

botStateEvent.OnClientEvent:Connect(function(data)
	ClientState.botStates = {}
	ClientState.botStatesRaw = {}
	ClientState.currentBotCount = 0

	if data and data.bots then
		for _, bot in ipairs(data.bots) do
			ClientState.botStates[bot.id] = bot
			table.insert(ClientState.botStatesRaw, bot)
			ClientState.currentBotCount = ClientState.currentBotCount + 1
		end
	end

	if hud.selection and hud.selection.type == "bot" then
		local botData = ClientState.botStates[hud.selection.id]
		if botData then
			hud.select({
				id = botData.id,
				type = "bot",
				spotId = botData.spotId,
				ammo = botData.ammo or 0,
				maxAmmo = botData.maxAmmo or 100,
				dynamicRange = 20,
				status = botData.paused and "PAUSED" or "ACTIVE",
			})
		end
	end

	hud.updateBotParty(ClientState.botStates)
end)

golemPlaceAtEvent.OnClientEvent:Connect(function(success, result)
	if not success then
		Overlays.showNotification("BUILD FAILED", tostring(result), "", 3)
	end
end)

botBuildEvent.OnClientEvent:Connect(function(success, result)
	if not success then
		Overlays.showNotification("BUILD FAILED", tostring(result), "", 3)
	end
end)

attackHitEvent.OnClientEvent:Connect(function(data)
	Effects.attackHit(data)
end)

playerHurtEvent.OnClientEvent:Connect(function(data)
	Effects.playerHurt(data, workspace.CurrentCamera, screenGui)
	if hpBillboard and data.newHp and data.maxHp then
		hpBillboard:update(data.newHp, data.maxHp)
	end
end)

beepEvent.OnClientEvent:Connect(function()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9114074529"
	sound.Volume = 0.5
	sound.Parent = workspace
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end)

playAnimationEvent.OnClientEvent:Connect(function(animName, character)
	if animName == "AxeSwing" then
		Effects.playAxeSwing(character)
	end
end)

playerTeleportEvent.OnClientEvent:Connect(function(x, z)
	local char = player.Character
	if not char then
		playerMoveCompleteEvent:FireServer()
		return
	end
	local humanoid = char:FindFirstChild("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		playerMoveCompleteEvent:FireServer()
		return
	end

	local startPos = hrp.Position
	local endPos = Vector3.new(x, startPos.Y, z)

	spawn(function()
		while humanoid.MoveDirection.Magnitude > 0 or (hrp.Position - endPos).Magnitude > 2 do
			local part = Instance.new("Part")
			part.Size = Vector3.new(0.3, 1.5, 0.3)
			part.Position = hrp.Position - Vector3.new(0, 1, 0)
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(100, 180, 255)
			part.Transparency = 0.5
			part.Parent = workspace

			spawn(function()
				for j = 1, 5 do
					part.Transparency = 0.5 + (j * 0.1)
					part.Size = part.Size * 0.8
					wait(0.03)
				end
				part:Destroy()
			end)

			wait(0.05)
			if (hrp.Position - endPos).Magnitude < 2 then break end
		end
	end)

	humanoid:MoveTo(endPos)
	humanoid.MoveToFinished:Once(function()
		playerMoveCompleteEvent:FireServer()
	end)
end)

golemMoveEvent.OnClientEvent:Connect(function(success, msg)
	ClientState.isMovingGolem = false
	ClientState.movingGolemId = nil
end)

golemSellEvent.OnClientEvent:Connect(function(success, result)
	if success then
		if ClientState.currentInterpreterTarget.type == "golem" then
			exitGolemMind()
		end
	end
end)

golemUpgradeEvent.OnClientEvent:Connect(function(success, result)
	if success then
		local tier = result.tier or 2
		local tierName = result.tierName or "Enhanced"

		local golemId = ClientState.currentInterpreterTarget.type == "golem" and ClientState.currentInterpreterTarget.golemId
		if golemId and ClientState.golemStates[golemId] then
			for _, model in ipairs(workspace:GetDescendants()) do
				if model:IsA("Model") and model:GetAttribute("GolemId") == golemId then
					local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
					if hrp then
						local tierColors = {
							[2] = Color3.fromRGB(255, 150, 0),
							[3] = Color3.fromRGB(255, 220, 50),
						}
						Effects.turretUpgrade(hrp.Position, tier, tierColors[tier])
					end
					break
				end
			end
		end

		if hud.selection and hud.selection.type == "golem" then
			local golemData = ClientState.golemStates[hud.selection.id]
			if golemData then
				hud.select({
					id = hud.selection.id,
					type = "golem",
					name = "TURRET #" .. (golemData.spotId or "?"),
					spotId = golemData.spotId,
					ammo = golemData.ammo,
					maxAmmo = golemData.maxAmmo,
					dynamicRange = golemData.dynamicRange,
					status = golemData.paused and "PAUSED" or "ACTIVE",
					tier = tier,
					tierName = tierName,
					upgradeCost = golemData.upgradeCost,
					unlockedAmmo = result.unlockedAmmo,
				})
			end
		end
	end
end)

golemFullStateEvent.OnClientEvent:Connect(function(state)
	if not state then return end

	if ClientState.currentInterpreterTarget.type == "golem" and state.golemId == ClientState.currentInterpreterTarget.golemId then
		if state.programSource and state.programSource ~= "" then
			editor:setTextFormatted(state.programSource)
		end

		if state.source then
			editor:setTextFormatted(state.source)
		end

		program:update(state)
		bytecodePanel:update(state)
	end
end)

botSellEvent.OnClientEvent:Connect(function(success, result)
	if success then
		if ClientState.currentInterpreterTarget.type == "bot" then
			exitBotMind()
		end
	end
end)

enterBuildModeEvent.OnClientEvent:Connect(function()
	PlacementSystem.enterTurretMode(Overlays.showNotification)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mouse = player:GetMouse()
		local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {player.Character}

		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)

		if ClientState.isMovingGolem and ClientState.movingGolemId and result then
			local hitPos = result.Position
			golemMoveEvent:FireServer(ClientState.movingGolemId, hitPos.X, hitPos.Z)
			return
		end

		if result and result.Instance then
			local hitPart = result.Instance
			local model = hitPart:FindFirstAncestorOfClass("Model")

			if model then
				local enemyId = model:GetAttribute("EnemyId")
				if enemyId then
					manualAttackEvent:FireServer()
					return
				end
			end

			if model then
				local golemId = model:GetAttribute("GolemId")
				local botId = model:GetAttribute("BotId")

				if golemId and ClientState.golemStates[golemId] then
					local golemData = ClientState.golemStates[golemId]
					hud.select({
						id = golemId,
						type = "golem",
						spotId = golemData.spotId,
						ammo = golemData.ammo,
						maxAmmo = golemData.maxAmmo or 300,
						dynamicRange = golemData.dynamicRange or 40,
						status = golemData.paused and "PAUSED" or "ACTIVE",
						tier = golemData.tier or 1,
						tierName = golemData.tierName or "Basic",
						upgradeCost = golemData.upgradeCost,
					})
					enterGolemMind(golemId)
					return
				elseif botId and ClientState.botStates[botId] then
					local botData = ClientState.botStates[botId]
					hud.select({
						id = botId,
						type = "bot",
						spotId = botData.spotId,
						ammo = botData.ammo or 0,
						maxAmmo = botData.maxAmmo or 100,
						dynamicRange = 20,
						status = botData.paused and "PAUSED" or "ACTIVE",
					})
					enterBotMind(botId)
					return
				end
			end

			hud.deselect()
			if ClientState.currentInterpreterTarget.type == "golem" then
				exitGolemMind()
			elseif ClientState.currentInterpreterTarget.type == "bot" then
				exitBotMind()
			end
		end
	end
end)

local mouse = player:GetMouse()

RunService.RenderStepped:Connect(function(dt)
	local mouseTarget = mouse.Hit
	if not mouseTarget then return end

	local x = math.floor(mouseTarget.Position.X + 0.5)
	local z = math.floor(mouseTarget.Position.Z + 0.5)

	if ClientState.placementMode then
		ClientState.isPlacementValid = PlacementSystem.updateGhostTurret(x, z)
	end

	if ClientState.botPlacementMode then
		ClientState.isBotPlacementValid = PlacementSystem.updateGhostBot(x, z)
	end
end)

local botAnimStates = {}
RunService.RenderStepped:Connect(function(dt)
	for _, obj in ipairs(workspace:GetDescendants()) do
		local botId = obj:GetAttribute("BotId")
		if not botId or not obj:IsA("Model") then continue end

		local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
		if not hrp then continue end

		if not botAnimStates[botId] then
			botAnimStates[botId] = { animSpeed = 0, walkCycle = 0 }
		end
		local animState = botAnimStates[botId]

		local isMoving = obj:GetAttribute("IsMoving") or false
		local emoteType = obj:GetAttribute("EmoteType") or ""
		local emoteEndTime = obj:GetAttribute("EmoteEndTime") or 0
		local baseY = obj:GetAttribute("BaseY") or 2.5
		local facingAngle = obj:GetAttribute("FacingAngle") or 0

		local targetSpeed = isMoving and 12 or 0
		animState.animSpeed = animState.animSpeed + (targetSpeed - animState.animSpeed) * 5 * dt

		animState.walkCycle = animState.walkCycle + animState.animSpeed * dt

		local bounce = math.abs(math.sin(animState.walkCycle)) * 0.25
		local tilt = math.sin(animState.walkCycle * 0.5) * 0.12
		local lean = isMoving and -0.08 or 0

		local emoteRotation = 0
		local emoteYOffset = 0
		local emoteTilt = 0

		if emoteType ~= "" and tick() < emoteEndTime then
			local emoteDuration = 2
			local emoteProgress = 1 - ((emoteEndTime - tick()) / emoteDuration)

			if emoteType == "spin" then
				emoteRotation = emoteProgress * math.pi * 8
			elseif emoteType == "jump" then
				emoteYOffset = math.sin(emoteProgress * math.pi) * 3
			elseif emoteType == "shake" then
				emoteTilt = math.sin(tick() * 30) * 0.3
			end
		end

		local serverPos = hrp.Position
		hrp.CFrame = CFrame.new(serverPos.X, baseY + bounce + emoteYOffset, serverPos.Z)
			* CFrame.Angles(0, facingAngle + emoteRotation, 0)
			* CFrame.Angles(lean, emoteTilt, -tilt)
	end
end)

mouse.Button2Down:Connect(function()
	if ClientState.placementMode then
		PlacementSystem.exitTurretMode()
	end
	if ClientState.botPlacementMode then
		PlacementSystem.exitBotMode()
	end
end)

mouse.Button1Down:Connect(function()
	if ClientState.placementMode then
		if ClientState.isPlacementValid then
			PlacementSystem.tryPlaceTurret(mouse, golemPlaceAtEvent)
		else
			PlacementSystem.playErrorSound()
		end
		return
	end

	if ClientState.botPlacementMode then
		if ClientState.isBotPlacementValid then
			PlacementSystem.tryPlaceBot(mouse, botBuildEvent)
		else
			PlacementSystem.playErrorSound()
		end
		return
	end

	local guiObjects = playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
	for _, obj in ipairs(guiObjects) do
		if obj:IsDescendantOf(editor.frame) or obj:IsDescendantOf(program.frame) then
			return
		end
		if obj.Active or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("TextBox") then
			return
		end
	end

	local target = mouse.Target
	if target then
		local model = target:FindFirstAncestorOfClass("Model")
		if model then
			local golemId = model:GetAttribute("GolemId")
			if golemId and ClientState.golemStates[golemId] then
				enterGolemMind(golemId)
				return
			end

			local botId = model:GetAttribute("BotId")
			if botId and ClientState.botStates[botId] then
				enterBotMind(botId)
				return
			end
		end
	end

	if ClientState.currentInterpreterTarget.type == "golem" then
		exitGolemMind()
		return
	end

	if ClientState.currentInterpreterTarget.type == "bot" then
		exitBotMind()
		return
	end

	manualAttackEvent:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

	if ctrl then
		if input.KeyCode == Enum.KeyCode.Q then
			if UserInputService:GetFocusedTextBox() then
				UserInputService:GetFocusedTextBox():ReleaseFocus()
			end
			if ClientState.currentInterpreterTarget.type == "golem" then
				exitGolemMind()
			elseif ClientState.currentInterpreterTarget.type == "bot" then
				exitBotMind()
			end
			return
		elseif input.KeyCode == Enum.KeyCode.One then
			local source = editor:getText()
			runProgramEvent:FireServer(source, ClientState.currentInterpreterTarget)
			return
		elseif input.KeyCode == Enum.KeyCode.Two then
			pauseProgramEvent:FireServer(ClientState.currentInterpreterTarget)
			return
		elseif input.KeyCode == Enum.KeyCode.Three then
			local source = editor:getText()
			stepProgramEvent:FireServer(source, ClientState.currentInterpreterTarget)
			return
		end
	end

	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Zero then
		loadWeapon(0)
	elseif input.KeyCode == Enum.KeyCode.One then
		loadWeapon(1)
	elseif input.KeyCode == Enum.KeyCode.Two then
		loadWeapon(2)
	elseif input.KeyCode == Enum.KeyCode.Three then
		loadWeapon(3)
	elseif input.KeyCode == Enum.KeyCode.Four then
		loadWeapon(4)
	elseif input.KeyCode == Enum.KeyCode.Five then
		if ClientState.placementMode then PlacementSystem.exitTurretMode() end
		if ClientState.botPlacementMode then
			PlacementSystem.exitBotMode()
		else
			PlacementSystem.enterBotMode(Overlays.showNotification)
		end
	elseif input.KeyCode == Enum.KeyCode.Six then
		if ClientState.botPlacementMode then PlacementSystem.exitBotMode() end
		if ClientState.placementMode then
			PlacementSystem.exitTurretMode()
		else
			PlacementSystem.enterTurretMode(Overlays.showNotification)
		end
	elseif input.KeyCode == Enum.KeyCode.Tab then
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local playerPos = hrp.Position
				local lookDir = hrp.CFrame.LookVector

				local nearestId, nearestType, nearestDist = nil, nil, math.huge

				for id, golem in pairs(ClientState.golemStates) do
					for _, obj in pairs(workspace:GetDescendants()) do
						if obj:GetAttribute("GolemId") == id then
							local objPos = obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Position or obj:IsA("BasePart") and obj.Position
							if objPos then
								local toObj = (objPos - playerPos)
								local dist = toObj.Magnitude
								local dot = lookDir:Dot(toObj.Unit)
								if dot > 0 and dist < nearestDist then
									nearestDist = dist
									nearestId = id
									nearestType = "golem"
								end
							end
							break
						end
					end
				end

				for id, bot in pairs(ClientState.botStates) do
					for _, obj in pairs(workspace:GetDescendants()) do
						if obj:GetAttribute("BotId") == id then
							local objPos = obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Position or obj:IsA("BasePart") and obj.Position
							if objPos then
								local toObj = (objPos - playerPos)
								local dist = toObj.Magnitude
								local dot = lookDir:Dot(toObj.Unit)
								if dot > 0 and dist < nearestDist then
									nearestDist = dist
									nearestId = id
									nearestType = "bot"
								end
							end
							break
						end
					end
				end

				if nearestId then
					if nearestType == "golem" then
						local golemData = ClientState.golemStates[nearestId]
						hud.select({
							id = nearestId,
							type = "golem",
							spotId = golemData.spotId,
							ammo = golemData.ammo,
							maxAmmo = golemData.maxAmmo or 300,
							dynamicRange = golemData.dynamicRange or 40,
							status = golemData.paused and "PAUSED" or "ACTIVE",
							tier = golemData.tier or 1,
							tierName = golemData.tierName or "Basic",
							upgradeCost = golemData.upgradeCost,
						})
						enterGolemMind(nearestId)
					elseif nearestType == "bot" then
						local botData = ClientState.botStates[nearestId]
						hud.select({
							id = nearestId,
							type = "bot",
							spotId = botData.spotId,
							ammo = botData.ammo or 0,
							maxAmmo = botData.maxAmmo or 100,
							dynamicRange = 20,
							status = botData.paused and "PAUSED" or "ACTIVE",
						})
						enterBotMind(nearestId)
					end
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.B then
		if ClientState.botPlacementMode then PlacementSystem.exitBotMode() end
		if ClientState.placementMode then
			PlacementSystem.exitTurretMode()
		else
			PlacementSystem.enterTurretMode(Overlays.showNotification)
		end
	elseif input.KeyCode == Enum.KeyCode.N then
		if ClientState.placementMode then PlacementSystem.exitTurretMode() end
		if ClientState.botPlacementMode then
			PlacementSystem.exitBotMode()
		else
			PlacementSystem.enterBotMode(Overlays.showNotification)
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if ClientState.placementMode then
			PlacementSystem.exitTurretMode()
			return
		end
		if ClientState.botPlacementMode then
			PlacementSystem.exitBotMode()
			return
		end
		if ClientState.currentInterpreterTarget.type == "golem" then
			exitGolemMind()
		elseif ClientState.currentInterpreterTarget.type == "bot" then
			exitBotMind()
		end
	end
end)

local function setupAmbientSound()
	local ambientGroup = Instance.new("SoundGroup")
	ambientGroup.Name = "AmbientGroup"
	ambientGroup.Volume = 1
	ambientGroup.Parent = SoundService

	local tracks = SoundConfig.Ambient and SoundConfig.Ambient.Tracks
	if tracks and #tracks > 0 then
		local volume = SoundConfig.Ambient.Volume or 0.3

		local ambientSound = Instance.new("Sound")
		ambientSound.Name = "AmbientSound"
		ambientSound.Volume = volume
		ambientSound.Looped = false
		ambientSound.SoundGroup = ambientGroup
		ambientSound.Parent = SoundService

		local function playRandomTrack()
			local trackId = tracks[math.random(1, #tracks)]
			ambientSound.SoundId = trackId
			if not ambientSound.IsLoaded then
				ambientSound.Loaded:Wait()
			end
			ambientSound:Play()
		end

		ambientSound.Ended:Connect(function()
			task.wait(1)
			playRandomTrack()
		end)

		playRandomTrack()
	end
end

GridNavigator.enable()
setupAmbientSound()

task.defer(function()
	if editor then
		editor:setMode("player")
	end
	loadWeapon(1)
	ClientState.isReloading = false
end)

requestStateEvent:FireServer()
