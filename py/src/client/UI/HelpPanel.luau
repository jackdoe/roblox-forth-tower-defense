local HelpPanel = {}

local AMBER = Color3.fromRGB(255, 191, 0)
local AMBER_DIM = Color3.fromRGB(180, 140, 40)
local BG_COLOR = Color3.fromRGB(12, 12, 8)

local HELP_TEXT = [[
PYTHONTD(1)                      GAME MANUAL                      PYTHONTD(1)

NAME
       PythonTD - tower defense with programmable units

SYNOPSIS
       while True:
           enemies = self.scan()
           if len(enemies) > 0:
               self.set_target(nearest(enemies))
               self.fire(BULLET)

AMMO TYPES
       BULLET    Fast, cheap, reliable. Good for sustained damage.
       ROCKET    Explosive splash damage. Best vs groups.
       LASER     High damage single target. Pierces armor.
       ICE       Applies SLOW debuff. Reduces enemy speed 60%.
       FREEZE    Light slow effect. Low damage, fast fire rate.
       GRENADE   Arc trajectory, large splash. High damage.

DEBUFFS
       SLOW      Enemy moves slower. Duration 3-4s. Stacks with damage.
       OILED     Enemy is coated in oil. Lasts 5s. Amplifies SHOCK.
       BURNING   Damage over time. 5 dmg/tick for 3s. Spreads on death.

COMBOS
       SHOCK + OILED     = 2x damage + explosion visual
       SHOCK + BURNING   = 1.5x damage + chain lightning to 3 nearby
       SHOCK + SLOW      = bonus damage equal to slow amount
       ROCKET + FROZEN   = SHATTER: 1.5x damage, clears ice

BOT ABILITIES
       self.collect()           Pick up nearby scrap
       self.deposit()           Return scrap to core
       self.shock(enemy)        Electric attack, triggers combos
       self.teleport([x,z])     Instant move to position
       self.explode()           Sacrifice bot for AOE damage
       self.forward(n)          Move forward n units
       self.left(deg)           Turn left by degrees
       self.carrying()          Returns current cargo amount

GUNDAM ABILITIES
       self.fire(AMMO)          Fire selected ammo type
       self.scan()              Returns list of enemies in range
       self.set_target(enemy)   Aim at specific enemy
       self.set_range(n)        Set scan/attack range (max 60)
       self.pos                 Current [x, z] position

PLAYER ABILITIES
       self.fire(AMMO)          Fire from player position
       self.scan()              Scan for enemies
       self.collect()           Pick up nearby scrap
       self.teleport([x,z])     Move to position
       self.explode()           AOE attack using cargo

SELECTORS
       nearest(enemies)         Closest enemy to self
       furthest(enemies)        Farthest enemy from self
       weakest(enemies)         Lowest HP enemy
       strongest(enemies)       Highest HP enemy

GLOBAL VARIABLES
       CORE.hp                  Current core health
       CORE.position            Core [x, z] position
       G1, G2, ... G30          Access other gundams by ID
       B1, B2, B3, B4           Access bots by ID

ECONOMY
       Scrap drops from killed enemies. Bots collect and deposit.
       Gundams cost scrap to build. Upgrades cost scrap.
       Power upgrades increase all unit damage globally.

TIPS
       - ICE enemies before ROCKET for shatter bonus
       - SHOCK oiled enemies for massive damage
       - Bots can chain-collect with teleport
       - Higher CPU Hz = faster program execution
       - More RAM = longer programs allowed

                                                              PYTHONTD(1)
]]

function HelpPanel.create(parent, onClose)
	local panel = {}

	local overlay = Instance.new("Frame")
	overlay.Name = "HelpOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = parent

	local frame = Instance.new("Frame")
	frame.Name = "HelpPanel"
	frame.Size = UDim2.new(0.8, 0, 0.85, 0)
	frame.Position = UDim2.new(0.1, 0, 0.075, 0)
	frame.BackgroundColor3 = BG_COLOR
	frame.BorderSizePixel = 0
	frame.Parent = overlay

	local border = Instance.new("UIStroke")
	border.Color = AMBER_DIM
	border.Thickness = 2
	border.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.new(1, -20, 1, -50)
	scroll.Position = UDim2.new(0, 10, 0, 10)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = AMBER_DIM
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = frame

	local content = Instance.new("TextLabel")
	content.Name = "Content"
	content.Size = UDim2.new(1, -20, 0, 0)
	content.BackgroundTransparency = 1
	content.Text = HELP_TEXT
	content.TextColor3 = AMBER
	content.Font = Enum.Font.Code
	content.TextSize = 14
	content.TextXAlignment = Enum.TextXAlignment.Left
	content.TextYAlignment = Enum.TextYAlignment.Top
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.TextWrapped = false
	content.Parent = scroll

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 100, 0, 30)
	closeBtn.Position = UDim2.new(0.5, -50, 1, -40)
	closeBtn.BackgroundColor3 = AMBER_DIM
	closeBtn.Text = "[ESC] CLOSE"
	closeBtn.TextColor3 = BG_COLOR
	closeBtn.Font = Enum.Font.Code
	closeBtn.TextSize = 14
	closeBtn.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		panel.hide()
		if onClose then onClose() end
	end)

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = input.Position
			local framePos = frame.AbsolutePosition
			local frameSize = frame.AbsoluteSize
			if pos.X < framePos.X or pos.X > framePos.X + frameSize.X or
			   pos.Y < framePos.Y or pos.Y > framePos.Y + frameSize.Y then
				panel.hide()
				if onClose then onClose() end
			end
		end
	end)

	function panel.show()
		overlay.Visible = true
	end

	function panel.hide()
		overlay.Visible = false
	end

	function panel.toggle()
		overlay.Visible = not overlay.Visible
	end

	function panel.isVisible()
		return overlay.Visible
	end

	function panel.getFrame()
		return overlay
	end

	return panel
end

return HelpPanel
