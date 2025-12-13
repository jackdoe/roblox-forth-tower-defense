-- ProgramLibrary.luau
-- Simple example programs for learning

local ProgramLibrary = {}

ProgramLibrary.categories = {
	"Turret",
	"Bot",
	"Player",
}

ProgramLibrary.programs = {
	--============================================================================
	-- TURRET PROGRAMS - use self.scan(), self.fire(), self.reload(), etc.
	--============================================================================
	{
		name = "Basic Turret",
		targetType = "golem",
		category = "Turret",
		desc = "Shoot nearest, auto-reload",
		code = [[
# Shoot nearest, reload when low
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]],
	},
	{
		name = "Focus Weak",
		targetType = "golem",
		category = "Turret",
		desc = "Target lowest HP first",
		code = [[
# Target weakest, reload when low
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(weakest(enemies), BULLET)
]],
	},
	{
		name = "Rocket Turret",
		targetType = "golem",
		category = "Turret",
		desc = "Rockets for groups",
		code = [[
# Use rockets when enemies group up
while True:
    if self.ammo() < 30:
        self.reload(50)
    enemies = self.scan()
    if len(enemies) >= 3:
        self.fire(nearest(enemies), ROCKET)
    elif len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]],
	},
	{
		name = "Laser Sniper",
		targetType = "golem",
		category = "Turret",
		desc = "High damage laser",
		code = [[
# Laser the strongest enemy
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(strongest(enemies), LASER)
]],
	},
	{
		name = "Ice Support",
		targetType = "golem",
		category = "Turret",
		desc = "Slow enemies down",
		code = [[
# Freeze enemies for other turrets
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), ICE)
]],
	},
	{
		name = "Combo Master",
		targetType = "golem",
		category = "Turret",
		desc = "ICE->ROCKET shatter combo",
		code = [[
# Freeze then shatter for 1.5x damage!
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        e = nearest(enemies)
        self.fire(e, ICE)     # Freeze!
        self.fire(e, ROCKET)  # Shatter!
]],
	},
	{
		name = "Oil Striker",
		targetType = "golem",
		category = "Turret",
		desc = "ROCKET oils for bot shock",
		code = [[
# Oil enemies for bot to shock (2x damage!)
while True:
    if self.ammo() < 50:
        self.reload(100)
    enemies = self.scan()
    if len(enemies) > 0:
        e = nearest(enemies)
        self.fire(e, ROCKET)  # Oils enemy
        B1.shock(e)           # 2x damage!
]],
	},

	--============================================================================
	-- BOT PROGRAMS - use self.collect(), self.scraps(), etc.
	-- collect() auto-returns to core to deposit
	--============================================================================
	{
		name = "Worker Bot",
		targetType = "bot",
		category = "Bot",
		desc = "Collect scrap for core",
		code = [[
# Collect scrap and bring to core
while True:
    s = self.scraps()
    if len(s) > 0:
        self.collect(s[0])
]],
	},
	{
		name = "Chatty Bot",
		targetType = "bot",
		category = "Bot",
		desc = "Shows personality",
		code = [[
# Bot with personality
self.say("Hello!")
while True:
    s = self.scraps()
    if len(s) > 0:
        self.say("Found scrap!")
        self.collect(s[0])
        self.say("Delivered!")
]],
	},

	--============================================================================
	-- PLAYER PROGRAMS - control bots and turrets
	--============================================================================
	{
		name = "Machinist",
		targetType = "player",
		category = "Player",
		desc = "Control B1 from player",
		code = [[
# Control bot from player
while True:
    s = B1.scraps()
    if len(s) > 0:
        B1.collect(s[0])
]],
	},
	{
		name = "Turret Control",
		targetType = "player",
		category = "Player",
		desc = "Fire turrets manually",
		code = [[
# Control turrets from player
while True:
    if T1.ammo() < 50:
        T1.reload(100)
    enemies = T1.scan()
    if len(enemies) > 0:
        T1.fire(enemies[0], BULLET)
]],
	},
}

-- Get programs by category
function ProgramLibrary.getByCategory(category)
	local result = {}
	for _, prog in ipairs(ProgramLibrary.programs) do
		if prog.category == category then
			table.insert(result, prog)
		end
	end
	return result
end

-- Get programs by target type
function ProgramLibrary.getByTarget(targetType)
	local result = {}
	for _, prog in ipairs(ProgramLibrary.programs) do
		if prog.targetType == targetType then
			table.insert(result, prog)
		end
	end
	return result
end

-- Get all programs
function ProgramLibrary.getAll()
	return ProgramLibrary.programs
end

-- Find program by name
function ProgramLibrary.find(name)
	for _, prog in ipairs(ProgramLibrary.programs) do
		if prog.name == name then
			return prog
		end
	end
	return nil
end

return ProgramLibrary
