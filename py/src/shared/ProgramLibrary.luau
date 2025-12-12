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
	-- TURRET PROGRAMS - use self.scan(), self.fire(), etc.
	--============================================================================
	{
		name = "Basic Turret",
		targetType = "golem",
		category = "Turret",
		desc = "Shoot nearest enemy",
		code = [[
# Shoot the nearest enemy
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies))
]],
	},
	{
		name = "Focus Weak",
		targetType = "golem",
		category = "Turret",
		desc = "Target lowest HP first",
		code = [[
# Target weakest enemies
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(weakest(enemies))
]],
	},

	--============================================================================
	-- BOT PROGRAMS - use self.collect(), self.supply(), etc.
	--============================================================================
	{
		name = "Worker Bot",
		targetType = "bot",
		category = "Bot",
		desc = "Collect and supply T1",
		code = [[
# Collect scrap, supply turret
while True:
    if self.is_full():
        self.supply(T1)
    else:
        self.collect_nearest()
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
self.color("cyan")
while True:
    if self.is_full():
        self.say("Delivering!")
        self.supply(T1)
    else:
        self.say("Working...")
        self.collect_nearest()
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
    if B1.is_full():
        B1.supply(T1)
    else:
        B1.collect_nearest()
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
    enemies = T1.scan()
    if len(enemies) > 0:
        T1.fire(enemies[0])
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
