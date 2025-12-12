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
		signature = "fire(ammo_type) -> bool",
		description = "Fire the weapon. ammo_type: BULLET, ROCKET, LASER, ICE, FREEZE",
		example = "fire(BULLET)\nfire(ROCKET)",
	},
	{
		word = "ammo()",
		category = "Golem Combat",
		signature = "ammo() -> int",
		description = "Get current ammo count",
		example = "if ammo() < 10:\n    print('Low ammo!')",
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
		signature = "BULLET = 1",
		description = "Fast, cheap ammo. Good for single targets.",
		example = "fire(BULLET)",
	},
	{
		word = "ROCKET",
		category = "Golem Combat",
		signature = "ROCKET = 2",
		description = "Slow, expensive. Has splash damage!",
		example = "if scan() > 3:\n    fire(ROCKET)",
	},
	{
		word = "LASER",
		category = "Golem Combat",
		signature = "LASER = 3",
		description = "High damage, fast fire rate.",
		example = "target(strongest())\nfire(LASER)",
	},
	{
		word = "ICE",
		category = "Golem Combat",
		signature = "ICE = 4",
		description = "Slows enemies by 60% for 4 seconds.",
		example = "fire(ICE)",
	},
	{
		word = "FREEZE",
		category = "Golem Combat",
		signature = "FREEZE = 5",
		description = "No damage, slows enemies. Cheap utility.",
		example = "fire(FREEZE)\nfire(ROCKET)",
	},

	--============================================================================
	-- BOT LOGISTICS FUNCTIONS
	--============================================================================
	{
		word = "scrap()",
		category = "Bot Logistics",
		signature = "scrap() -> (x, z) or (nil, nil)",
		description = "Get position of nearest scrap",
		example = "x, z = scrap()\nif x:\n    move(x, z)",
	},
	{
		word = "has_scrap()",
		category = "Bot Logistics",
		signature = "has_scrap() -> bool",
		description = "Check if there's scrap to collect",
		example = "if has_scrap():\n    move_to_scrap()",
	},
	{
		word = "my_scrap()",
		category = "Bot Logistics",
		signature = "my_scrap() -> int",
		description = "Get scrap in your inventory",
		example = "print('Carrying:', my_scrap())",
	},
	{
		word = "capacity()",
		category = "Bot Logistics",
		signature = "capacity() -> int",
		description = "Get max inventory capacity",
		example = "space = capacity() - my_scrap()",
	},
	{
		word = "bag_full()",
		category = "Bot Logistics",
		signature = "bag_full() -> bool",
		description = "Check if inventory is full",
		example = "if bag_full():\n    supply(1)",
	},
	{
		word = "move()",
		category = "Bot Logistics",
		signature = "move(x, z)",
		description = "Walk to position (blocking)",
		example = "move(150, 120)",
	},
	{
		word = "move_to_scrap()",
		category = "Bot Logistics",
		signature = "move_to_scrap()",
		description = "Walk to nearest scrap",
		example = "move_to_scrap()\ncollect()",
	},
	{
		word = "collect()",
		category = "Bot Logistics",
		signature = "collect() -> int",
		description = "Pick up scrap at current position",
		example = "amount = collect()",
	},
	{
		word = "golem()",
		category = "Bot Logistics",
		signature = "golem(spot_id) -> (x, z)",
		description = "Get position of turret by ID (1, 2, 3...)",
		example = "x, z = golem(1)",
	},
	{
		word = "move_to_golem()",
		category = "Bot Logistics",
		signature = "move_to_golem(spot_id)",
		description = "Walk to specified turret",
		example = "move_to_golem(1)\nsupply(1)",
	},
	{
		word = "supply()",
		category = "Bot Logistics",
		signature = "supply(spot_id) -> int",
		description = "Give scrap to turret as ammo",
		example = "supplied = supply(1)",
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
