-- GameWords.luau
-- Player action words for Tower Defense
-- Movement, combat, and basic sensing

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameWords = {}

local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)

function GameWords.register(dict, push, pop, peek, self, deps)
	local Config = deps.Config
	local attackHitEvent = deps.attackHitEvent
	local beepEvent = deps.beepEvent
	local playAnimationEvent = deps.playAnimationEvent

	-- Helper to refresh character reference
	local function refreshCharacter()
		if self.player and self.player.Character then
			self.character = self.player.Character
		end
	end

	--============================================================================
	-- POSITION WORDS
	--============================================================================

	-- ME: Push my current position (tagged)
	dict["ME"] = function()
		refreshCharacter()
		if self.character and self.character:FindFirstChild("HumanoidRootPart") then
			local hrp = self.character.HumanoidRootPart
			push(TaggedValue.createPos(hrp.Position.X, hrp.Position.Z))
		else
			push(TaggedValue.createPos(0, 0))
		end
	end

	-- DISTANCE: Calculate distance between two positions
	dict["DISTANCE"] = function()
		local pos2 = pop(); if pos2 == nil then return end
		local pos1 = pop(); if pos1 == nil then return end

		if not TaggedValue.isPos(pos1) or not TaggedValue.isPos(pos2) then
			self.error = "DISTANCE: needs two positions"
			self.status = "ERROR"
			return
		end

		local x1, z1 = TaggedValue.getPos(pos1)
		local x2, z2 = TaggedValue.getPos(pos2)

		local dx = x2 - x1
		local dz = z2 - z1
		local dist = math.sqrt(dx * dx + dz * dz)

		push(math.floor(dist))
	end

	--============================================================================
	-- TURTLE MOVEMENT WORDS
	--============================================================================

	local function getFacingAngle()
		if self.facingAngle then return self.facingAngle end
		refreshCharacter()
		if self.character then
			local hrp = self.character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local _, y, _ = hrp.CFrame:ToEulerAnglesYXZ()
				self.facingAngle = math.deg(y)
			end
		end
		return self.facingAngle or 0
	end

	local function applyFacingAngle()
		refreshCharacter()
		if not self.character then return end
		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local pos = hrp.Position
			hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(self.facingAngle or 0), 0)
		end
	end

	-- FORWARD: Dash forward with effects
	local DASH_WALK_SPEED = 40

	dict["FORWARD"] = function()
		local studs = pop(); if studs == nil then return end
		if type(studs) ~= "number" then return end
		studs = math.floor(studs)
		if studs == 0 then return end

		refreshCharacter()
		if not self.character then return end
		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		local humanoid = self.character:FindFirstChild("Humanoid")
		if not hrp or not humanoid then return end

		self.blocked = true

		local startPos = hrp.Position
		local startX, startZ = startPos.X, startPos.Z
		local startY = startPos.Y

		local look = hrp.CFrame.LookVector
		local dx, dz = look.X, look.Z
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0 then dx, dz = dx / len, dz / len end

		local sign = studs > 0 and 1 or -1
		local totalDist = math.abs(studs)

		local targetX = startX + dx * totalDist * sign
		local targetZ = startZ + dz * totalDist * sign
		local finalX, finalZ = targetX, targetZ

		local moveDist = math.sqrt((finalX - startX) ^ 2 + (finalZ - startZ) ^ 2)
		if moveDist < 1 then
			self.blocked = false
			return
		end

		local duration = moveDist / DASH_WALK_SPEED
		local rotation = hrp.CFrame - hrp.CFrame.Position
		local targetCF = CFrame.new(finalX, startY, finalZ) * rotation

		humanoid.WalkSpeed = 0
		humanoid:Move(Vector3.new(0, 0, 0))
		hrp.Anchored = true

		local moveTween = TweenService:Create(hrp,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = targetCF }
		)

		-- Trail effect
		task.spawn(function()
			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 1.5, 0)
			a1.Position = Vector3.new(0, -1.5, 0)
			a0.Parent = hrp
			a1.Parent = hrp

			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.12
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.5, 0.5),
				NumberSequenceKeypoint.new(1, 1)
			})
			trail.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
			trail.Parent = hrp

			task.wait(duration + 0.3)
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)

		moveTween:Play()
		moveTween.Completed:Wait()

		hrp.Anchored = false
		humanoid.WalkSpeed = Config.MANUAL_WALKING_SPEED
		self.blocked = false
	end
	dict["FD"] = dict["FORWARD"]
	dict["F"] = dict["FORWARD"]

	-- LEFT: Rotate left by degrees
	dict["LEFT"] = function()
		local degrees = pop(); if degrees == nil then return end
		if type(degrees) ~= "number" then return end
		self.facingAngle = (getFacingAngle() + degrees) % 360
		applyFacingAngle()
	end
	dict["LT"] = dict["LEFT"]
	dict["L"] = dict["LEFT"]

	-- RIGHT: Rotate right by degrees
	dict["RIGHT"] = function()
		local degrees = pop(); if degrees == nil then return end
		if type(degrees) ~= "number" then return end
		self.facingAngle = (getFacingAngle() - degrees) % 360
		applyFacingAngle()
	end
	dict["RT"] = dict["RIGHT"]
	dict["R"] = dict["RIGHT"]

	-- ANGLE?: Push current facing angle
	dict["ANGLE?"] = function()
		push(getFacingAngle())
	end

	-- ANGLE: Set facing angle directly
	dict["ANGLE"] = function()
		local degrees = pop(); if degrees == nil then return end
		if type(degrees) ~= "number" then return end
		self.facingAngle = degrees % 360
		applyFacingAngle()
	end

	-- STOP: Stop walking
	dict["STOP"] = function()
		refreshCharacter()
		if not self.character then return end
		local humanoid = self.character:FindFirstChild("Humanoid")
		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp then
			humanoid:MoveTo(hrp.Position)
		end
	end

	--============================================================================
	-- COMBAT WORDS
	--============================================================================

	-- HIT: Attack enemies in front
	local function hitImpl()
		refreshCharacter()
		if not self.character then
			push(0)
			return 0
		end
		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			push(0)
			return 0
		end

		local myX, myZ = hrp.Position.X, hrp.Position.Z
		local attackRange = Config.ATTACK_RANGE or 6
		local damage = Config.ATTACK_DAMAGE or 30

		local lookVector = hrp.CFrame.LookVector
		local facingX, facingZ = lookVector.X, lookVector.Z
		local facingLen = math.sqrt(facingX * facingX + facingZ * facingZ)
		if facingLen > 0 then
			facingX, facingZ = facingX / facingLen, facingZ / facingLen
		end

		local MIN_DOT = 0
		local hitCount = 0

		-- Hit enemies (from EnemyManager)
		local EnemyManager = deps.EnemyManager
		if EnemyManager then
			for id, enemy in pairs(EnemyManager.getAll()) do
				if enemy.hp > 0 and enemy.character then
					local enemyHrp = enemy.character:FindFirstChild("HumanoidRootPart")
					if enemyHrp then
						local ex, ez = enemyHrp.Position.X, enemyHrp.Position.Z
						local dist = math.sqrt((myX - ex) ^ 2 + (myZ - ez) ^ 2)

						if dist <= attackRange then
							local toEnemyX = ex - myX
							local toEnemyZ = ez - myZ
							local toEnemyLen = math.sqrt(toEnemyX * toEnemyX + toEnemyZ * toEnemyZ)
							if toEnemyLen > 0 then
								toEnemyX, toEnemyZ = toEnemyX / toEnemyLen, toEnemyZ / toEnemyLen
							end

							local dot = facingX * toEnemyX + facingZ * toEnemyZ
							if dot >= MIN_DOT then
								EnemyManager.damage(id, damage, nil)
								hitCount = hitCount + 1
							end
						end
					end
				end
			end
		end

		-- Play client-side Cyber-Headbutt animation
		if playAnimationEvent and self.player then
			playAnimationEvent:FireClient(self.player, "AxeSwing", self.character)
		end

		-- Visual feedback
		if attackHitEvent then
			local Players = game:GetService("Players")
			for _, p in ipairs(Players:GetPlayers()) do
				attackHitEvent:FireClient(p, {
					targetPos = hrp.Position,
					damage = damage * hitCount,
					hitCount = hitCount,
					range = attackRange,
					lookVector = lookVector,
				})
			end
		end

		return hitCount
	end

	dict["HIT"] = function()
		hitImpl()
	end

	dict["HIT?"] = function()
		local hitCount = hitImpl()
		if hitCount > 0 then
			self.safeOutput("HIT(x" .. hitCount .. ")")
			push(-1)
		else
			push(0)
			self.safeOutput("MISS")
		end
	end

	-- RANGE?: Check if any enemy is in attack range
	dict["RANGE?"] = function()
		refreshCharacter()
		if not self.character then
			push(0)
			return
		end
		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			push(0)
			return
		end

		local myX, myZ = hrp.Position.X, hrp.Position.Z
		local attackRange = Config.ATTACK_RANGE or 6

		local EnemyManager = deps.EnemyManager
		if EnemyManager then
			for _, enemy in pairs(EnemyManager.getAll()) do
				if enemy.hp > 0 and enemy.character then
					local enemyHrp = enemy.character:FindFirstChild("HumanoidRootPart")
					if enemyHrp then
						local dist = math.sqrt((myX - enemyHrp.Position.X) ^ 2 + (myZ - enemyHrp.Position.Z) ^ 2)
						if dist <= attackRange then
							push(-1)
							return
						end
					end
				end
			end
		end
		push(0)
	end

	-- ENEMY?: Check if any enemy is visible
	dict["ENEMY?"] = function()
		refreshCharacter()
		if not self.character then
			push(0)
			return
		end
		local hrp = self.character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			push(0)
			return
		end

		local myX, myZ = hrp.Position.X, hrp.Position.Z
		local senseRange = Config.SENSE_RANGE or 50

		local EnemyManager = deps.EnemyManager
		if EnemyManager then
			for _, enemy in pairs(EnemyManager.getAll()) do
				if enemy.hp > 0 and enemy.character then
					local enemyHrp = enemy.character:FindFirstChild("HumanoidRootPart")
					if enemyHrp then
						local dist = math.sqrt((myX - enemyHrp.Position.X) ^ 2 + (myZ - enemyHrp.Position.Z) ^ 2)
						if dist <= senseRange then
							push(-1)
							return
						end
					end
				end
			end
		end
		push(0)
	end


	--============================================================================
	-- UTILITY WORDS
	--============================================================================

	dict["BEEP"] = function()
		if self.isPlayer and self.player and beepEvent then
			beepEvent:FireClient(self.player)
		end
		self.safeOutput("BEEP!")
	end

	dict["PAUSE"] = function()
		self.paused = true
		self.status = "PAUSED"

		refreshCharacter()
		if self.character then
			local humanoid = self.character:FindFirstChild("Humanoid")
			if humanoid then
				local hrp = self.character:FindFirstChild("HumanoidRootPart")
				if hrp then
					humanoid:MoveTo(hrp.Position)
				end
			end
		end

		self.safeOutput("PAUSED")
	end

	-- WAIT: Do nothing (consumes a tick)
	dict["WAIT"] = function()
		-- Just consumes time
	end

	-- NOP: No operation
	dict["NOP"] = function() end
end

return GameWords
