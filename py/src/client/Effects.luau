-- Effects.luau
-- Visual effects for combat, loot, etc.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("PythonTD"):WaitForChild("SoundConfig"))

local Effects = {}

--============================================================================
-- PART CACHE (Object Pooling to reduce GC)
-- Instead of creating/destroying parts, we recycle them
--============================================================================

local partCache = {}
local MAX_CACHE_SIZE = 200  -- Don't cache more than this

local function getPooledPart()
	if #partCache > 0 then
		local part = table.remove(partCache)
		part.Transparency = 0
		part.Parent = workspace
		return part
	else
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		return p
	end
end

local function recyclePart(part, delayTime)
	task.delay(delayTime, function()
		if part and part.Parent then
			part.Transparency = 1
			part.CFrame = CFrame.new(0, -1000, 0)  -- Move far away
			part.Parent = nil  -- Remove from workspace

			-- Only cache if we haven't exceeded max
			if #partCache < MAX_CACHE_SIZE then
				table.insert(partCache, part)
			else
				part:Destroy()  -- Actually destroy if cache is full
			end
		end
	end)
end

-- Play a player sound using SoundConfig (2D, for UI sounds)
local function playPlayerSound(soundName)
	local config = SoundConfig.Player
	if config and config[soundName] then
		SoundConfig.playSound(config[soundName], config[soundName .. "Volume"] or 0.5, workspace)
	end
end

-- Play a player sound at a specific 3D position (spatial, for combat)
local function playPlayerSoundAt(soundName, position)
	local config = SoundConfig.Player
	if config and config[soundName] and position then
		SoundConfig.playSpatialSound(config[soundName], position, config[soundName .. "Volume"] or 0.5)
	end
end

-- Attack hit effect (AOE circle swing) - subtle version
function Effects.attackHit(data)
	if not data.targetPos then return end

	-- Play attack sound at the target position (spatial 3D sound)
	-- This uses distance falloff so sounds fade when far away
	local hitCount = data.hitCount or 0
	if hitCount > 0 then
		playPlayerSoundAt("AttackHit", data.targetPos)
	else
		playPlayerSoundAt("AttackMiss", data.targetPos)
	end

	-- Blood splatter when hitting (using object pool to reduce GC)
	if hitCount > 0 and data.targetPos then
		local bloodColors = {
			Color3.fromRGB(139, 0, 0),    -- Dark red
			Color3.fromRGB(180, 20, 20),  -- Medium red
			Color3.fromRGB(100, 0, 0),    -- Very dark red
		}

		-- Big blood spray particles (20-30 particles) - splatter outward
		local particleCount = 20 + math.random(10)
		for i = 1, particleCount do
			local blood = getPooledPart()
			blood.Name = "Blood"
			-- Varied sizes for more organic look
			local size = math.random() * 0.3 + 0.15
			blood.Size = Vector3.new(size, size, size)
			blood.Shape = Enum.PartType.Ball
			blood.CFrame = CFrame.new(data.targetPos + Vector3.new(
				(math.random() - 0.5) * 0.5,
				1.2 + (math.random() - 0.5) * 0.3,
				(math.random() - 0.5) * 0.5
			))
			blood.Material = Enum.Material.SmoothPlastic
			blood.Color = bloodColors[math.random(#bloodColors)]
			blood.Transparency = 0

			-- Splatter outward and slightly down - more horizontal spread
			local angle = math.random() * math.pi * 2
			local upward = math.random() * 0.8 - 0.4  -- Mostly flat, slight up/down
			local spread = math.random() * 4 + 2  -- More horizontal spread
			local targetPos = data.targetPos + Vector3.new(
				math.cos(angle) * spread,
				upward,
				math.sin(angle) * spread
			)

			-- Varied timing for organic feel
			local duration = 0.25 + math.random() * 0.15
			local bloodTween = TweenService:Create(blood, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(targetPos),
				Size = Vector3.new(0.08, 0.08, 0.08),
				Transparency = 1
			})
			bloodTween:Play()
			recyclePart(blood, duration + 0.1)
		end

		-- Blood splat on ground (keep using Debris for long-lived parts)
		local splat = Instance.new("Part")
		splat.Name = "BloodSplat"
		splat.Size = Vector3.new(2 + math.random() * 2, 0.05, 2 + math.random() * 2)
		splat.CFrame = CFrame.new(data.targetPos.X, 0.03, data.targetPos.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		splat.Anchored = true
		splat.CanCollide = false
		splat.Material = Enum.Material.SmoothPlastic
		splat.Color = Color3.fromRGB(100, 0, 0)
		splat.Transparency = 0.3
		splat.Parent = workspace

		-- Fade out the splat over time
		local splatTween = TweenService:Create(splat, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(splat.Size.X * 1.2, 0.05, splat.Size.Z * 1.2)
		})
		task.delay(2, function()
			splatTween:Play()
		end)
		Debris:AddItem(splat, 5)

		-- Extra burst of tiny droplets - fast outward spray (using pool)
		for i = 1, 15 do
			local droplet = getPooledPart()
			droplet.Name = "BloodDroplet"
			droplet.Size = Vector3.new(0.12, 0.12, 0.12)
			droplet.Shape = Enum.PartType.Ball
			droplet.CFrame = CFrame.new(data.targetPos + Vector3.new(0, 1.2, 0))
			droplet.Material = Enum.Material.Neon
			droplet.Color = Color3.fromRGB(200, 30, 30)
			droplet.Transparency = 0

			-- Fast outward spray with slight arc
			local angle = math.random() * math.pi * 2
			local spread = math.random() * 5 + 3  -- Far horizontal spread
			local landPos = data.targetPos + Vector3.new(
				math.cos(angle) * spread,
				0.05,
				math.sin(angle) * spread
			)

			-- Single outward arc motion
			local duration = 0.2 + math.random() * 0.15
			local dropTween = TweenService:Create(droplet, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(landPos),
				Size = Vector3.new(0.05, 0.05, 0.05),
				Transparency = 1
			})
			dropTween:Play()
			recyclePart(droplet, duration + 0.1)
		end
	end

	-- Floating damage number
	if hitCount > 0 then
		local damage = data.damage or 0
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		-- Random horizontal offset so numbers don't stack
		local offsetX = (math.random() - 0.5) * 1.5
		local offsetZ = (math.random() - 0.5) * 1.5
		anchor.CFrame = CFrame.new(data.targetPos + Vector3.new(offsetX, 2.5, offsetZ))
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Parent = workspace

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 80, 0, 40)
		billboard.StudsOffset = Vector3.new(0, 0, 0)
		billboard.Adornee = anchor
		billboard.AlwaysOnTop = true  -- Always visible
		billboard.Parent = anchor

		-- Color based on damage type or amount
		local textColor = Color3.fromRGB(255, 255, 100)  -- Default yellow
		local textSize = 18

		if data.isKill then
			textColor = Color3.fromRGB(255, 80, 80)  -- Red for kills
			textSize = 24
		elseif data.isCrit or damage >= 50 then
			textColor = Color3.fromRGB(255, 150, 50)  -- Orange for big hits
			textSize = 22
		elseif data.damageType == "ice" or data.damageType == "freeze" then
			textColor = Color3.fromRGB(100, 200, 255)  -- Cyan for ice
		elseif data.damageType == "laser" then
			textColor = Color3.fromRGB(255, 100, 100)  -- Red for laser
		elseif data.damageType == "rocket" or data.damageType == "grenade" then
			textColor = Color3.fromRGB(255, 150, 50)  -- Orange for explosives
		end

		local hitLabel = Instance.new("TextLabel")
		hitLabel.Size = UDim2.new(1, 0, 1, 0)
		hitLabel.BackgroundTransparency = 1
		hitLabel.Text = tostring(damage)
		hitLabel.TextColor3 = textColor
		hitLabel.TextStrokeTransparency = 0
		hitLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		hitLabel.Font = Enum.Font.GothamBlack
		hitLabel.TextSize = textSize
		hitLabel.TextScaled = false
		hitLabel.Parent = billboard

		-- Pop-up and float animation
		task.spawn(function()
			-- Initial pop (scale up quickly)
			local startSize = textSize
			hitLabel.TextSize = startSize * 0.5
			for i = 1, 4 do
				hitLabel.TextSize = startSize * (0.5 + i * 0.15)
				task.wait(0.02)
			end
			hitLabel.TextSize = startSize

			-- Float up and fade
			for j = 1, 20 do
				anchor.CFrame = anchor.CFrame + Vector3.new(0, 0.06, 0)
				hitLabel.TextTransparency = j / 20
				hitLabel.TextStrokeTransparency = j / 20
				task.wait(0.025)
			end
			anchor:Destroy()
		end)
	end

	-- Kill effect (using pool)
	if data.isKill then
		-- Burst particles
		for i = 1, 8 do
			local particle = getPooledPart()
			particle.Size = Vector3.new(0.3, 0.3, 0.3)
			particle.Shape = Enum.PartType.Ball
			particle.CFrame = CFrame.new(data.targetPos)
			particle.Material = Enum.Material.Neon
			particle.Color = Color3.fromRGB(255, 100, 100)
			particle.Transparency = 0

			local angle = (i / 8) * math.pi * 2
			local targetPos = data.targetPos + Vector3.new(math.cos(angle) * 3, 1, math.sin(angle) * 3)

			local particleTween = TweenService:Create(particle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(targetPos),
				Transparency = 1,
				Size = Vector3.new(0.1, 0.1, 0.1)
			})
			particleTween:Play()

			recyclePart(particle, 0.5)
		end
	end
end

-- Cooldown for hurt sound
local lastHurtSoundTime = 0
local HURT_SOUND_COOLDOWN = 10 -- seconds

-- Player hurt effect (screen flash and shake)
function Effects.playerHurt(data, camera, screenGui)
	-- Blood particles from player (using pool)
	local player = game:GetService("Players").LocalPlayer
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		for i = 1, 6 do
			local blood = getPooledPart()
			blood.Name = "Blood"
			blood.Size = Vector3.new(0.25, 0.25, 0.25)
			blood.Shape = Enum.PartType.Ball
			blood.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 0.5, 0))
			blood.Material = Enum.Material.SmoothPlastic
			blood.Color = Color3.fromRGB(139, 0, 0)  -- Dark red
			blood.Transparency = 0

			-- Random spray outward
			local angle = math.random() * math.pi * 2
			local upward = math.random() * 1.5
			local spread = math.random() * 1.5 + 0.5
			local targetPos = hrp.Position + Vector3.new(
				math.cos(angle) * spread,
				upward,
				math.sin(angle) * spread
			)

			local bloodTween = TweenService:Create(blood, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(targetPos),
				Size = Vector3.new(0.1, 0.1, 0.1),
				Transparency = 0.9
			})
			bloodTween:Play()
			recyclePart(blood, 0.5)
		end
	end

	-- Play hurt sound with cooldown
	local now = tick()
	if now - lastHurtSoundTime >= HURT_SOUND_COOLDOWN then
		playPlayerSound("Hurt")
		lastHurtSoundTime = now
	end

	-- Red screen halo effect (subtle vignette around edges)
	if screenGui then
		-- Create a full-screen frame with inner stroke for halo effect
		local halo = Instance.new("Frame")
		halo.Name = "HurtHalo"
		halo.Size = UDim2.new(1, 0, 1, 0)
		halo.Position = UDim2.new(0, 0, 0, 0)
		halo.BackgroundTransparency = 1  -- Transparent background
		halo.BorderSizePixel = 0
		halo.ZIndex = 100
		halo.Active = false  -- Don't block mouse input
		halo.Parent = screenGui

		-- Inner stroke creates the halo effect
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(180, 0, 0)
		stroke.Thickness = 60
		stroke.Transparency = 0.4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = halo

		-- Rounded corners for softer look
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.1, 0)
		corner.Parent = halo

		-- Fade out the stroke
		local strokeTween = TweenService:Create(stroke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1
		})
		strokeTween:Play()

		Debris:AddItem(halo, 0.5)
	end

	-- Camera shake
	if camera then
		local originalCFrame = camera.CFrame
		task.spawn(function()
			for i = 1, 5 do
				local shake = Vector3.new(
					(math.random() - 0.5) * 0.3,
					(math.random() - 0.5) * 0.3,
					0
				)
				camera.CFrame = originalCFrame * CFrame.new(shake)
				task.wait(0.03)
			end
			camera.CFrame = originalCFrame
		end)
	end

	-- Direction indicator (if attacker position provided)
	if data.attackerPos and screenGui then
		local dirIndicator = Instance.new("Frame")
		dirIndicator.Size = UDim2.new(0, 100, 0, 4)
		dirIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
		dirIndicator.Position = UDim2.new(0.5, 0, 0.5, 0)
		dirIndicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		dirIndicator.BorderSizePixel = 0
		dirIndicator.ZIndex = 99
		dirIndicator.Active = false  -- Don't block mouse input

		-- Calculate rotation based on attacker direction
		if camera then
			local camPos = camera.CFrame.Position
			local toAttacker = (data.attackerPos - camPos).Unit
			local camLook = camera.CFrame.LookVector
			local angle = math.atan2(toAttacker.X * camLook.Z - toAttacker.Z * camLook.X,
				toAttacker.X * camLook.X + toAttacker.Z * camLook.Z)
			dirIndicator.Rotation = math.deg(angle)
		end

		dirIndicator.Parent = screenGui

		local dirTween = TweenService:Create(dirIndicator, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		})
		dirTween:Play()

		Debris:AddItem(dirIndicator, 0.6)
	end
end

-- Helper to create impact particles
local function createImpactParticles(parent)
	local emitter = parent:FindFirstChild("ImpactEmitter")
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "ImpactEmitter"
		emitter.Texture = "rbxassetid://243098098" -- Sparkle/Flash
		emitter.LightEmission = 1
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255))
		})
		emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
		emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
		emitter.Lifetime = NumberRange.new(0.3, 0.5)
		emitter.Speed = NumberRange.new(10, 25)
		emitter.SpreadAngle = Vector2.new(360, 360) -- Explosion
		emitter.Rate = 0
		emitter.Enabled = false
		emitter.Parent = parent
	end
	return emitter
end

-- Track animation state per character to prevent overlap
local animatingCharacters = {}

-- Procedural "Cyber-Headbutt" / Lunge animation
function Effects.playAxeSwing(character)
	if not character then return end

	-- Prevent overlapping animations
	if animatingCharacters[character] then return end

	-- 1. Find the Root Joint (Connects Torso to HRP)
	-- This works for both R6 and R15 usually
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end

	local rootJoint = rootPart:FindFirstChild("RootJoint")
	if not rootJoint and character:FindFirstChild("LowerTorso") then
		rootJoint = character.LowerTorso:FindFirstChild("Root")
	end

	if not rootJoint then return end

	-- Lock this character
	animatingCharacters[character] = true

	local originalC0 = rootJoint.C0

	-- 2. ANIMATION POSES (subtle)
	-- Windup: Small lean back
	local windupC0 = originalC0 * CFrame.new(0, -0.1, 0.2) * CFrame.Angles(math.rad(8), 0, 0)

	-- Strike: Quick jab forward (not too far)
	local strikeC0 = originalC0 * CFrame.new(0, -0.15, -0.5) * CFrame.Angles(math.rad(-20), 0, 0)

	-- 3. VISUALS: Forward arc shockwave (using pool)
	local function spawnShockwave()
		-- Create a forward-facing arc/wedge effect
		local wave = getPooledPart()
		wave.Name = "Shockwave"
		wave.Size = Vector3.new(4, 0.3, 2) -- Wide, thin, shallow
		wave.Shape = Enum.PartType.Block  -- Reset shape in case it was ball
		wave.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3) -- In front of player
		wave.Material = Enum.Material.Neon
		wave.Color = Color3.fromRGB(100, 255, 255)
		wave.Transparency = 0.3

		-- Expand forward and fade
		local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(wave, tweenInfo, {
			Size = Vector3.new(8, 0.1, 6),
			CFrame = rootPart.CFrame * CFrame.new(0, 0, -5),
			Transparency = 1
		})
		tween:Play()
		recyclePart(wave, 0.3)
	end

	-- 4. EXECUTION

	-- A. Windup (0.06s - quick)
	local t1 = TweenService:Create(rootJoint, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {C0 = windupC0})
	t1:Play()

	t1.Completed:Once(function()
		-- B. Strike (0.06s - SNAP)
		local t2 = TweenService:Create(rootJoint, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = strikeC0})
		t2:Play()

		-- Spawn particles
		local particles = createImpactParticles(rootPart)
		particles:Emit(8)

		-- CAMERA IMPACT (Local Player Only) - subtle
		local Players = game:GetService("Players")
		if character == Players.LocalPlayer.Character then
			local cam = workspace.CurrentCamera
			local baseFOV = cam.FieldOfView
			-- CHANGED: Reduced from +2 to +0.5. Just a tiny bump.
			local fovTween = TweenService:Create(cam, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = baseFOV + 0.5})
			fovTween:Play()

			-- Reset FOV
			task.delay(0.08, function()
				local fovReset = TweenService:Create(cam, TweenInfo.new(0.15), {FieldOfView = baseFOV})
				fovReset:Play()
			end)
		end

		-- C. Recovery (0.15s - snap back to normal)
		t2.Completed:Once(function()
			local t3 = TweenService:Create(rootJoint, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {C0 = originalC0})
			t3:Play()
			t3.Completed:Once(function()
				animatingCharacters[character] = nil
			end)
		end)
	end)
end

return Effects
