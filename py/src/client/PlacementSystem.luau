local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)
local ClientState = require(script.Parent.ClientState)

local PlacementSystem = {}

local GROUND_Y = Config.PLATFORM_Y
local BOT_COST = 75

local ghostTurret = nil
local ghostBot = nil

local function createGhostTurret()
	local model = Instance.new("Model")
	model.Name = "GhostTurret"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 5, 5)
	base.Anchored = true
	base.CanCollide = false
	base.Material = Enum.Material.Neon
	base.Color = Color3.fromRGB(0, 255, 200)
	base.Transparency = 0.4
	base.Parent = model

	model.PrimaryPart = base
	return model
end

local function createGhostBot()
	local model = Instance.new("Model")
	model.Name = "GhostBot"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 4, 4)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.Neon
	body.Color = Color3.fromRGB(255, 180, 50)
	body.Transparency = 0.4
	body.Parent = model

	model.PrimaryPart = body
	return model
end

function PlacementSystem.updateGhostTurret(x, z)
	if not ghostTurret then return false end

	local hasScrap = ClientState.currentScrap >= ClientState.nextTurretCost

	local color = hasScrap and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)

	local base = ghostTurret:FindFirstChild("Base")
	if base then
		base.Position = Vector3.new(x, GROUND_Y + 2.5, z)
		base.Color = color
	end

	return hasScrap
end

function PlacementSystem.updateGhostBot(x, z)
	if not ghostBot then return false end

	local hasScrap = ClientState.currentScrap >= BOT_COST

	local color = hasScrap and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(255, 50, 50)

	local body = ghostBot:FindFirstChild("Body")
	if body then
		body.Position = Vector3.new(x, GROUND_Y + 2, z)
		body.Color = color
	end

	return hasScrap
end

function PlacementSystem.enterTurretMode(showNotification)
	if ClientState.placementMode then return end

	if ClientState.currentTurretCount >= ClientState.MAX_TURRETS then
		if showNotification then
			showNotification("TURRET LIMIT REACHED", "Max " .. ClientState.MAX_TURRETS .. " turrets!", "Sell a turret to build more", 4)
		end
		return
	end

	if ClientState.currentScrap < ClientState.nextTurretCost then
		return
	end

	ClientState.placementMode = true
	ghostTurret = createGhostTurret()
	ghostTurret.Parent = workspace
end

function PlacementSystem.exitTurretMode()
	if not ClientState.placementMode then return end
	ClientState.placementMode = false

	if ghostTurret then
		ghostTurret:Destroy()
		ghostTurret = nil
	end

	ClientState.isPlacementValid = false
end

function PlacementSystem.enterBotMode(showNotification)
	if ClientState.botPlacementMode then return end

	if ClientState.currentBotCount >= ClientState.MAX_BOTS then
		if showNotification then
			showNotification("BOT LIMIT REACHED", "Max " .. ClientState.MAX_BOTS .. " bots!", "Sell a bot to build more", 4)
		end
		return
	end

	if ClientState.currentScrap < BOT_COST then
		return
	end

	ClientState.botPlacementMode = true
	ghostBot = createGhostBot()
	ghostBot.Parent = workspace
end

function PlacementSystem.exitBotMode()
	if not ClientState.botPlacementMode then return end
	ClientState.botPlacementMode = false

	if ghostBot then
		ghostBot:Destroy()
		ghostBot = nil
	end

	ClientState.isBotPlacementValid = false
end

function PlacementSystem.tryPlaceTurret(mouse, golemPlaceAtEvent)
	if not ClientState.isPlacementValid then
		return false
	end

	local hitPos = mouse.Hit.Position
	local x = math.floor(hitPos.X + 0.5)
	local z = math.floor(hitPos.Z + 0.5)

	golemPlaceAtEvent:FireServer(x, z)

	local sfx = Instance.new("Sound", workspace)
	sfx.SoundId = "rbxassetid://9125699809"
	sfx.Volume = 0.7
	sfx.PlayOnRemove = true
	sfx:Destroy()

	if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		PlacementSystem.exitTurretMode()
	end

	return true
end

function PlacementSystem.tryPlaceBot(mouse, botBuildEvent)
	if not ClientState.isBotPlacementValid then
		return false
	end

	local hitPos = mouse.Hit.Position
	local x = math.floor(hitPos.X + 0.5)
	local z = math.floor(hitPos.Z + 0.5)

	botBuildEvent:FireServer(x, z)

	local sfx = Instance.new("Sound", workspace)
	sfx.SoundId = "rbxassetid://9125699809"
	sfx.Volume = 0.7
	sfx.PlayOnRemove = true
	sfx:Destroy()

	if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		PlacementSystem.exitBotMode()
	end

	return true
end

function PlacementSystem.playErrorSound()
	local sfx = Instance.new("Sound", workspace)
	sfx.SoundId = "rbxassetid://71764947817417"
	sfx.Volume = 0.5
	sfx.PlayOnRemove = true
	sfx:Destroy()
end

return PlacementSystem
