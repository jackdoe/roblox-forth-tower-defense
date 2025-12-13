-- HelpDatabase.luau
-- Documentation for Python game functions

local HelpDatabase = {}

HelpDatabase.categories = {
	"Golem Combat",
	"Bot Logistics",
	"Player Movement",
	"Control Flow",
	"Built-in Functions",
}

HelpDatabase.entries = {
	--============================================================================
	-- GOLEM COMBAT FUNCTIONS
	--============================================================================
	{
		word = "scan()",
		category = "Golem Combat",
		signature = "scan() -> int",
		description = "Count enemies in range",
		example = "if scan() > 0:\n    # enemies nearby!",
	},
	{
		word = "nearest()",
		category = "Golem Combat",
		signature = "nearest() -> enemy_id",
		description = "Get the ID of the nearest enemy",
		example = "enemy = nearest()\ntarget(enemy)",
	},
	{
		word = "weakest()",
		category = "Golem Combat",
		signature = "weakest() -> enemy_id",
		description = "Get the ID of the enemy with lowest HP",
		example = "target(weakest())\nfire(BULLET)",
	},
	{
		word = "strongest()",
		category = "Golem Combat",
		signature = "strongest() -> enemy_id",
		description = "Get the ID of the enemy with highest HP",
		example = "target(strongest())\nfire(LASER)",
	},
	{
		word = "target()",
		category = "Golem Combat",
		signature = "target(enemy_id)",
		description = "Aim at the specified enemy",
		example = "target(nearest())",
	},
	{
		word = "fire()",
		category = "Golem Combat",
		signature = "self.fire(enemy, ammo_type) -> bool",
		description = "Fire at enemy. Ammo costs: BULLET=1, ROCKET=4, LASER=2, ICE=2, FREEZE=1",
		example = "self.fire(nearest(enemies), BULLET)",
	},
	{
		word = "ammo()",
		category = "Golem Combat",
		signature = "self.ammo() -> int",
		description = "Get current ammo count",
		example = "if self.ammo() < 50:\n    self.reload(100)",
	},
	{
		word = "reload()",
		category = "Golem Combat",
		signature = "self.reload(amount) -> int",
		description = "Reload ammo from core stockpile. Blocks until complete. Delay based on amount.",
		example = "if self.ammo() < 50:\n    self.reload(100)",
	},
	{
		word = "set_range()",
		category = "Golem Combat",
		signature = "set_range(range)",
		description = "Set turret range (10-60). Lower = more damage",
		example = "set_range(10)  # Shotgun mode\nset_range(50)  # Sniper mode",
	},
	{
		word = "get_range()",
		category = "Golem Combat",
		signature = "get_range() -> int",
		description = "Get current turret range",
		example = "current = get_range()",
	},

	--============================================================================
	-- AMMO TYPE CONSTANTS
	--============================================================================
	{
		word = "BULLET",
		category = "Golem Combat",
		signature = "BULLET = 1 (cost: 1)",
		description = "Fast, cheap. 15 damage, 0.2s fire rate.",
		example = "self.fire(enemy, BULLET)",
	},
	{
		word = "ROCKET",
		category = "Golem Combat",
		signature = "ROCKET = 2 (cost: 4)",
		description = "80 damage + splash + OILS enemy! Bot shock does 2x damage to oiled.",
		example = "self.fire(enemy, ROCKET)\nB1.shock(enemy)  # 2x damage!",
	},
	{
		word = "LASER",
		category = "Golem Combat",
		signature = "LASER = 3 (cost: 2)",
		description = "40 damage + BURNS enemy (DoT)! Shock chains lightning to nearby.",
		example = "self.fire(enemy, LASER)\nB1.shock(enemy)  # Chain lightning!",
	},
	{
		word = "ICE",
		category = "Golem Combat",
		signature = "ICE = 4 (cost: 2)",
		description = "20 damage, FREEZES 60% for 4s. Rocket SHATTERS for 1.5x damage!",
		example = "self.fire(enemy, ICE)\nself.fire(enemy, ROCKET)  # Shatter!",
	},
	{
		word = "FREEZE",
		category = "Golem Combat",
		signature = "FREEZE = 5 (cost: 1)",
		description = "No damage, slows 30%. Cheap. Can shatter with ROCKET.",
		example = "self.fire(enemy, FREEZE)",
	},

	--============================================================================
	-- BOT LOGISTICS FUNCTIONS
	--============================================================================
	{
		word = "scraps()",
		category = "Bot Logistics",
		signature = "self.scraps() -> [[x,z], ...]",
		description = "Get list of scrap positions sorted by distance",
		example = "s = self.scraps()\nif len(s) > 0:\n    self.collect(s[0])",
	},
	{
		word = "collect()",
		category = "Bot Logistics",
		signature = "self.collect([x,z])",
		description = "Go to position, pick up scrap, return to core. Blocking.",
		example = "s = self.scraps()\nif len(s) > 0:\n    self.collect(s[0])",
	},
	{
		word = "scrap()",
		category = "Bot Logistics",
		signature = "self.scrap() -> int",
		description = "Get scrap currently carried",
		example = "print('Carrying:', self.scrap())",
	},
	{
		word = "capacity()",
		category = "Bot Logistics",
		signature = "self.capacity() -> int",
		description = "Get max inventory capacity",
		example = "space = self.capacity() - self.scrap()",
	},
	{
		word = "is_full()",
		category = "Bot Logistics",
		signature = "self.is_full() -> bool",
		description = "Check if inventory is full",
		example = "if self.is_full():\n    self.go_home()",
	},
	{
		word = "go_home()",
		category = "Bot Logistics",
		signature = "self.go_home()",
		description = "Walk to the core (blocking)",
		example = "self.go_home()",
	},
	{
		word = "goto()",
		category = "Bot Logistics",
		signature = "self.goto(target)",
		description = "Walk to turret or position (blocking)",
		example = "self.goto(T1)",
	},
	{
		word = "say()",
		category = "Bot Logistics",
		signature = "self.say(message)",
		description = "Show chat bubble above bot",
		example = "self.say('Hello!')",
	},
	{
		word = "shock()",
		category = "Bot Logistics",
		signature = "self.shock(enemy_id) -> damage",
		description = "Electric attack! Must be close (10 studs). 2x if oiled, chains if burning. Blocks 2s.",
		example = "# Combo with turret!\n# T1 fires ROCKET (oils)\nself.shock(enemy)  # 2x dmg!",
	},

	--============================================================================
	-- PLAYER MOVEMENT FUNCTIONS
	--============================================================================
	{
		word = "forward()",
		category = "Player Movement",
		signature = "forward(distance)",
		description = "Move forward by distance studs",
		example = "forward(5)",
	},
	{
		word = "left()",
		category = "Player Movement",
		signature = "left(degrees)",
		description = "Turn left by degrees",
		example = "left(90)",
	},
	{
		word = "right()",
		category = "Player Movement",
		signature = "right(degrees)",
		description = "Turn right by degrees",
		example = "right(45)",
	},
	{
		word = "teleport()",
		category = "Player Movement",
		signature = "teleport(x, z)",
		description = "Instantly move to position",
		example = "teleport(150, 150)",
	},
	{
		word = "teleport_to_golem()",
		category = "Player Movement",
		signature = "teleport_to_golem(spot_id)",
		description = "Teleport to turret location",
		example = "teleport_to_golem(1)",
	},
	{
		word = "hit()",
		category = "Player Movement",
		signature = "hit() -> bool",
		description = "Melee attack nearby enemy",
		example = "while True:\n    hit()",
	},

	--============================================================================
	-- CONTROL FLOW
	--============================================================================
	{
		word = "while",
		category = "Control Flow",
		signature = "while condition:",
		description = "Loop while condition is true",
		example = "while True:\n    fire(BULLET)",
	},
	{
		word = "if",
		category = "Control Flow",
		signature = "if condition:",
		description = "Conditional execution",
		example = "if scan() > 0:\n    fire(BULLET)",
	},
	{
		word = "elif",
		category = "Control Flow",
		signature = "elif condition:",
		description = "Else-if branch",
		example = "if x > 10:\n    pass\nelif x > 5:\n    pass",
	},
	{
		word = "else",
		category = "Control Flow",
		signature = "else:",
		description = "Else branch",
		example = "if scan() > 0:\n    fire()\nelse:\n    wait(1)",
	},
	{
		word = "for",
		category = "Control Flow",
		signature = "for i in range(n):",
		description = "Loop n times",
		example = "for i in range(5):\n    fire(BULLET)",
	},
	{
		word = "def",
		category = "Control Flow",
		signature = "def name(args):",
		description = "Define a function",
		example = "def attack():\n    fire(BULLET)",
	},
	{
		word = "return",
		category = "Control Flow",
		signature = "return value",
		description = "Return from function",
		example = "def count():\n    return scan()",
	},

	--============================================================================
	-- BUILT-IN FUNCTIONS
	--============================================================================
	{
		word = "wait()",
		category = "Built-in Functions",
		signature = "wait(seconds)",
		description = "Pause execution for seconds",
		example = "wait(1)  # Wait 1 second",
	},
	{
		word = "print()",
		category = "Built-in Functions",
		signature = "print(value, ...)",
		description = "Output text to console",
		example = "print('Enemies:', scan())",
	},
	{
		word = "range()",
		category = "Built-in Functions",
		signature = "range(n) or range(start, end)",
		description = "Generate numbers for loops",
		example = "for i in range(3):\n    print(i)",
	},
	{
		word = "len()",
		category = "Built-in Functions",
		signature = "len(list) -> int",
		description = "Get length of list",
		example = "count = len([1, 2, 3])",
	},
	{
		word = "abs()",
		category = "Built-in Functions",
		signature = "abs(x) -> number",
		description = "Absolute value",
		example = "distance = abs(x - y)",
	},
	{
		word = "min()",
		category = "Built-in Functions",
		signature = "min(a, b, ...) -> number",
		description = "Minimum value",
		example = "smallest = min(1, 2, 3)",
	},
	{
		word = "max()",
		category = "Built-in Functions",
		signature = "max(a, b, ...) -> number",
		description = "Maximum value",
		example = "largest = max(1, 2, 3)",
	},
}

-- Get entries by category
function HelpDatabase.getByCategory(category)
	local result = {}
	for _, entry in ipairs(HelpDatabase.entries) do
		if entry.category == category then
			table.insert(result, entry)
		end
	end
	return result
end

-- Search entries
function HelpDatabase.search(query)
	query = query:lower()
	local result = {}
	for _, entry in ipairs(HelpDatabase.entries) do
		if entry.word:lower():find(query, 1, true) or
		   entry.description:lower():find(query, 1, true) then
			table.insert(result, entry)
		end
	end
	return result
end

-- Get entry by word
function HelpDatabase.get(word)
	for _, entry in ipairs(HelpDatabase.entries) do
		if entry.word == word then
			return entry
		end
	end
	return nil
end

-- Alias for compatibility with client code
function HelpDatabase.getWordHelp(word)
	local entry = HelpDatabase.get(word)
	if entry then
		return {
			desc = entry.description,
			signature = entry.signature,
			example = entry.example,
		}
	end
	return nil
end

-- Get words in category (returns array of {word=, info=} for client)
function HelpDatabase.getWordsInCategory(category)
	local result = {}
	for _, entry in ipairs(HelpDatabase.entries) do
		if entry.category == category then
			table.insert(result, {
				word = entry.word,
				info = {
					desc = entry.description,
					signature = entry.signature,
					example = entry.example,
				}
			})
		end
	end
	return result
end

return HelpDatabase
