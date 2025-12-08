-- HelpDatabase.luau
-- Documentation for all Forth words in Forthy
-- Used by HELP command and ? button

local HelpDatabase = {}

-- Word categories for organization
HelpDatabase.categories = {
	"Stack",
	"Math",
	"Logic",
	"Memory",
	"Control Flow",
	"Golem Combat",
	"Player Logistics",
	"Game State",
	"I/O",
}

-- Word documentation
-- Format: { stack = "( before -- after )", desc = "description", example = "code", category = "category" }
HelpDatabase.words = {
	--============================================================================
	-- STACK OPERATIONS
	--============================================================================
	["DUP"] = {
		stack = "( n -- n n )",
		desc = "Duplicate the top value on the stack",
		example = "5 DUP . .  \\ prints 5 5",
		category = "Stack",
	},
	["DROP"] = {
		stack = "( n -- )",
		desc = "Remove the top value from the stack",
		example = "1 2 3 DROP . .  \\ prints 2 1",
		category = "Stack",
	},
	["SWAP"] = {
		stack = "( a b -- b a )",
		desc = "Swap the top two values",
		example = "1 2 SWAP . .  \\ prints 1 2",
		category = "Stack",
	},
	["OVER"] = {
		stack = "( a b -- a b a )",
		desc = "Copy the second value to the top",
		example = "1 2 OVER . . .  \\ prints 1 2 1",
		category = "Stack",
	},
	["ROT"] = {
		stack = "( a b c -- b c a )",
		desc = "Rotate the top three values",
		example = "1 2 3 ROT . . .  \\ prints 1 3 2",
		category = "Stack",
	},
	["NIP"] = {
		stack = "( a b -- b )",
		desc = "Remove the second value",
		example = "1 2 NIP .  \\ prints 2",
		category = "Stack",
	},
	["TUCK"] = {
		stack = "( a b -- b a b )",
		desc = "Copy top value below second",
		example = "1 2 TUCK . . .  \\ prints 2 1 2",
		category = "Stack",
	},
	[">R"] = {
		stack = "( n -- ) R:( -- n )",
		desc = "Move value from data stack to return stack",
		example = "5 >R ... R>  \\ temporarily stash 5",
		category = "Stack",
	},
	["R>"] = {
		stack = "( -- n ) R:( n -- )",
		desc = "Move value from return stack to data stack",
		example = "5 >R 10 20 + R> .  \\ prints 5",
		category = "Stack",
	},
	["R@"] = {
		stack = "( -- n ) R:( n -- n )",
		desc = "Copy top of return stack (non-destructive)",
		example = "5 >R R@ . R> DROP  \\ prints 5",
		category = "Stack",
	},
	["#R"] = {
		stack = "( -- count )",
		desc = "Push count of items on return stack",
		example = "1 >R 2 >R #R .  \\ prints 2",
		category = "Stack",
	},
	["#R@"] = {
		stack = "( -- items... )",
		desc = "Copy ALL return stack items to data stack",
		example = "1 >R 2 >R #R@ .S  \\ shows 1 2",
		category = "Stack",
	},
	["NR@"] = {
		stack = "( n -- items... )",
		desc = "Copy top N items from return stack",
		example = "1 >R 2 >R 3 >R 2 NR@  \\ copies top 2",
		category = "Stack",
	},

	--============================================================================
	-- MATH
	--============================================================================
	["+"] = {
		stack = "( a b -- sum )",
		desc = "Add two numbers",
		example = "3 4 + .  \\ prints 7",
		category = "Math",
	},
	["-"] = {
		stack = "( a b -- diff )",
		desc = "Subtract b from a",
		example = "10 3 - .  \\ prints 7",
		category = "Math",
	},
	["*"] = {
		stack = "( a b -- product )",
		desc = "Multiply two numbers",
		example = "3 4 * .  \\ prints 12",
		category = "Math",
	},
	["/"] = {
		stack = "( a b -- quotient )",
		desc = "Divide a by b",
		example = "12 4 / .  \\ prints 3",
		category = "Math",
	},
	["MOD"] = {
		stack = "( a b -- remainder )",
		desc = "Remainder of a divided by b",
		example = "17 5 MOD .  \\ prints 2",
		category = "Math",
	},
	["ABS"] = {
		stack = "( n -- |n| )",
		desc = "Absolute value",
		example = "-5 ABS .  \\ prints 5",
		category = "Math",
	},
	["MIN"] = {
		stack = "( a b -- min )",
		desc = "Smaller of two numbers",
		example = "3 7 MIN .  \\ prints 3",
		category = "Math",
	},
	["MAX"] = {
		stack = "( a b -- max )",
		desc = "Larger of two numbers",
		example = "3 7 MAX .  \\ prints 7",
		category = "Math",
	},
	["NEGATE"] = {
		stack = "( n -- -n )",
		desc = "Negate a number",
		example = "5 NEGATE .  \\ prints -5",
		category = "Math",
	},

	--============================================================================
	-- LOGIC / COMPARISON
	--============================================================================
	["="] = {
		stack = "( a b -- flag )",
		desc = "True (-1) if equal, false (0) otherwise",
		example = "5 5 = .  \\ prints -1 (true)",
		category = "Logic",
	},
	["<>"] = {
		stack = "( a b -- flag )",
		desc = "True if not equal",
		example = "5 3 <> .  \\ prints -1 (true)",
		category = "Logic",
	},
	["<"] = {
		stack = "( a b -- flag )",
		desc = "True if a < b",
		example = "3 5 < .  \\ prints -1 (true)",
		category = "Logic",
	},
	[">"] = {
		stack = "( a b -- flag )",
		desc = "True if a > b",
		example = "5 3 > .  \\ prints -1 (true)",
		category = "Logic",
	},
	["<="] = {
		stack = "( a b -- flag )",
		desc = "True if a <= b",
		example = "3 3 <= .  \\ prints -1 (true)",
		category = "Logic",
	},
	[">="] = {
		stack = "( a b -- flag )",
		desc = "True if a >= b",
		example = "5 3 >= .  \\ prints -1 (true)",
		category = "Logic",
	},
	["AND"] = {
		stack = "( a b -- a&b )",
		desc = "Bitwise AND",
		example = "-1 -1 AND .  \\ prints -1",
		category = "Logic",
	},
	["OR"] = {
		stack = "( a b -- a|b )",
		desc = "Bitwise OR",
		example = "0 -1 OR .  \\ prints -1",
		category = "Logic",
	},
	["NOT"] = {
		stack = "( n -- ~n )",
		desc = "Bitwise NOT (invert all bits)",
		example = "0 NOT .  \\ prints -1",
		category = "Logic",
	},

	--============================================================================
	-- MEMORY
	-- M0-M9 are LOCAL to each interpreter (player or golem)
	-- S0-S9 are SHARED between all players and golems (for co-op)
	--============================================================================
	["!"] = {
		stack = "( value addr -- )",
		desc = "Store value at memory address",
		example = "42 M0 !  \\ store 42 in M0",
		category = "Memory",
	},
	["@"] = {
		stack = "( addr -- value )",
		desc = "Fetch value from memory address",
		example = "M0 @  \\ get value from M0",
		category = "Memory",
	},
	["M0"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 0. Private to this interpreter",
		example = "100 M0 !  M0 @ .  \\ prints 100",
		category = "Memory",
	},
	["M1"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 1. Private to this interpreter",
		example = "M1 @ 1 + M1 !  \\ increment M1",
		category = "Memory",
	},
	["M2"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 2. Private to this interpreter",
		example = "0 M2 !  \\ reset M2 to 0",
		category = "Memory",
	},
	["M3"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 3. Private to this interpreter",
		example = "M3 @ .  \\ print M3 value",
		category = "Memory",
	},
	["M4"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 4. Private to this interpreter",
		example = "WAVE M4 !  \\ remember current wave",
		category = "Memory",
	},
	["M5"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 5. Private to this interpreter",
		example = "See M0",
		category = "Memory",
	},
	["M6"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 6. Private to this interpreter",
		example = "See M0",
		category = "Memory",
	},
	["M7"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 7. Private to this interpreter",
		example = "See M0",
		category = "Memory",
	},
	["M8"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 8. Private to this interpreter",
		example = "See M0",
		category = "Memory",
	},
	["M9"] = {
		stack = "( -- addr )",
		desc = "Local memory slot 9. Private to this interpreter",
		example = "See M0",
		category = "Memory",
	},
	["S0"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 0. Visible to ALL players/golems!",
		example = "1 S0 !  \\ signal other golems",
		category = "Memory",
	},
	["S1"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 1. Visible to ALL players/golems!",
		example = "S1 @ 0 > IF ... THEN  \\ check signal",
		category = "Memory",
	},
	["S2"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 2. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S3"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 3. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S4"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 4. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S5"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 5. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S6"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 6. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S7"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 7. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S8"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 8. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},
	["S9"] = {
		stack = "( -- addr )",
		desc = "Shared memory slot 9. Visible to ALL players/golems!",
		example = "See S0",
		category = "Memory",
	},

	["TIMEOUT"] = {
		stack = "( delay value addr -- )",
		desc = "Set a memory slot to a value after a delay",
		example = "60 0 S1 TIMEOUT  (after 60 seconds, set S1 to 0)",
		category = "Memory",
	},

	--============================================================================
	-- CONTROL FLOW
	--============================================================================
	["IF"] = {
		stack = "( flag -- )",
		desc = "If flag is true, execute code until THEN (or ELSE)",
		example = "5 3 > IF .\" big\" THEN",
		category = "Control Flow",
	},
	["ELSE"] = {
		stack = "( -- )",
		desc = "Code after ELSE runs if IF was false",
		example = "2 5 > IF .\" big\" ELSE .\" small\" THEN",
		category = "Control Flow",
	},
	["THEN"] = {
		stack = "( -- )",
		desc = "Ends an IF or IF...ELSE block",
		example = "See IF example",
		category = "Control Flow",
	},
	["BEGIN"] = {
		stack = "( -- )",
		desc = "Start a loop",
		example = "BEGIN ... AGAIN  \\ infinite loop\nBEGIN ... flag UNTIL  \\ loop until true",
		category = "Control Flow",
	},
	["AGAIN"] = {
		stack = "( -- )",
		desc = "Jump back to BEGIN (infinite loop)",
		example = "BEGIN SCAN 0 > IF FIRE THEN AGAIN",
		category = "Control Flow",
	},
	["UNTIL"] = {
		stack = "( flag -- )",
		desc = "Jump back to BEGIN if flag is false",
		example = "BEGIN AMMO? 0 = UNTIL  \\ loop until out of ammo",
		category = "Control Flow",
	},
	["WHILE"] = {
		stack = "( flag -- )",
		desc = "Continue loop while flag is true, exit to REPEAT",
		example = "BEGIN SCAN WHILE NEAREST FIRE REPEAT",
		category = "Control Flow",
	},
	["REPEAT"] = {
		stack = "( -- )",
		desc = "End of BEGIN...WHILE loop, jumps back to BEGIN",
		example = "See WHILE example",
		category = "Control Flow",
	},
	[":"] = {
		stack = "( -- )",
		desc = "Define a new word",
		example = ": DOUBLE DUP + ;\n5 DOUBLE .  \\ prints 10",
		category = "Control Flow",
	},
	[";"] = {
		stack = "( -- )",
		desc = "End word definition",
		example = "See : example",
		category = "Control Flow",
	},

	--============================================================================
	-- GOLEM COMBAT WORDS
	--============================================================================
	["SCAN"] = {
		stack = "( -- count )",
		desc = "Count enemies in range",
		example = "SCAN 0 > IF FIRE THEN",
		category = "Golem Combat",
	},
	["NEAREST"] = {
		stack = "( -- enemyId )",
		desc = "Get the closest enemy",
		example = "NEAREST TARGET FIRE",
		category = "Golem Combat",
	},
	["WEAKEST"] = {
		stack = "( -- enemyId )",
		desc = "Get the enemy with lowest HP",
		example = "WEAKEST TARGET FIRE",
		category = "Golem Combat",
	},
	["STRONGEST"] = {
		stack = "( -- enemyId )",
		desc = "Get the enemy with highest HP",
		example = "STRONGEST TARGET FIRE",
		category = "Golem Combat",
	},
	["TARGET"] = {
		stack = "( enemyId -- )",
		desc = "Aim at an enemy",
		example = "NEAREST TARGET",
		category = "Golem Combat",
	},
	["FIRE"] = {
		stack = "( ammoType -- )",
		desc = "Fire at current target using ammo type",
		example = "BULLET FIRE",
		category = "Golem Combat",
	},
	["2FIRE"] = {
		stack = "( ammo1 ammo2 -- )",
		desc = "Fire two shots rapidly (unlocked wave 3)",
		example = "BULLET BULLET 2FIRE",
		category = "Golem Combat",
	},
	["3FIRE"] = {
		stack = "( ammo1 ammo2 ammo3 -- )",
		desc = "Fire three shots rapidly (unlocked wave 6)",
		example = "BULLET BULLET BULLET 3FIRE",
		category = "Golem Combat",
	},
	["AMMO?"] = {
		stack = "( -- count )",
		desc = "Check ammo remaining",
		example = "AMMO? 10 < IF .\" LOW AMMO\" THEN",
		category = "Golem Combat",
	},
	["BULLET"] = {
		stack = "( -- ammoType )",
		desc = "Standard ammo - fast, cheap, 10 damage",
		example = "BULLET FIRE",
		category = "Golem Combat",
	},
	["ROCKET"] = {
		stack = "( -- ammoType )",
		desc = "Explosive ammo - AOE damage, 50 damage",
		example = "ROCKET FIRE",
		category = "Golem Combat",
	},
	["LASER"] = {
		stack = "( -- ammoType )",
		desc = "Precision ammo - long range, 25 damage",
		example = "LASER FIRE",
		category = "Golem Combat",
	},
	["ICE"] = {
		stack = "( -- ammoType )",
		desc = "Slowing ammo - slows enemy 50% for 3s",
		example = "ICE FIRE",
		category = "Golem Combat",
	},
	["FREEZE"] = {
		stack = "( -- ammoType )",
		desc = "No damage, but slows enemy to 70% speed.",
		example = "FREEZE FIRE",
		category = "Golem Combat",
	},
	["SET-RANGE"] = {
		stack = "( n -- )",
		desc = "Set range (10-60). Lower range = Higher damage.",
		example = "10 SET-RANGE (4x Dmg) / 60 SET-RANGE (0.66x Dmg)",
		category = "Golem Combat",
	},
	["RANGE"] = {
		stack = "( -- n )",
		desc = "Get current dynamic range setting.",
		example = "RANGE 20 < IF .\" Close range\" THEN",
		category = "Golem Combat",
	},

	--============================================================================
	-- PLAYER LOGISTICS WORDS
	--============================================================================
	["MACHINES"] = {
		stack = "( -- count )",
		desc = "How many golems are placed?",
		example = "MACHINES .  \\ prints golem count",
		category = "Player Logistics",
	},
	["GOLEM"] = {
		stack = "( n -- golemRef )",
		desc = "Get reference to golem #n",
		example = "1 GOLEM TELEPORT",
		category = "Player Logistics",
	},
	["TELEPORT"] = {
		stack = "( golemRef -- )",
		desc = "Warp to a golem's location",
		example = "1 GOLEM TELEPORT",
		category = "Player Logistics",
	},
	["RELOAD"] = {
		stack = "( -- )",
		desc = "Refill ammo of nearby golem (uses scrap, converts it to ammo)",
		example = "1 GOLEM TELEPORT RELOAD",
		category = "Player Logistics",
	},
	["LOWEST-AMMO"] = {
		stack = "( -- golemRef )",
		desc = "Get golem with lowest ammo percentage, 0 if none",
		example = "LOWEST-AMMO TELEPORT RELOAD",
		category = "Player Logistics",
	},
	["GOLEM-AMMO"] = {
		stack = "( golemRef -- ammo )",
		desc = "Get ammo count of a golem",
		example = "1 GOLEM GOLEM-AMMO .",
		category = "Player Logistics",
	},
	["BUILD"] = {
		stack = "( -- )",
		desc = "Enter placement mode to build a golem",
		example = "BUILD  \\ then click to place",
		category = "Player Logistics",
	},
	["FORWARD"] = {
		stack = "( n --  )",
		desc = "Move forward N steps, Alias: F",
		example = "10 forward",
		category = "Player Combat",
	},
	["LEFT"] = {
		stack = "( n --  )",
		desc = "Turn left N degrees, Alias: L",
		example = "30 left",
		category = "Player Combat",
	},
	["RIGHT"] = {
		stack = "( n --  )",
		desc = "Turn right N degrees, Alias: R",
		example = "20 right",
		category = "Player Combat",
	},

	["HIT"] = {
		stack = "( -- )",
		desc = "HIT whatever is infront",
		example = "BEGIN HIT AGAIN",
		category = "Player Combat",
	},

	["HIT?"] = {
		stack = "( -- f )",
		desc = "HIT whatever is infront and leave a flag on the stack if it was a hit or miss",
		example = "BEGIN HIT? WHILE REPEAT",
		category = "Player Combat",
	},

	--============================================================================
	-- GAME STATE WORDS
	--============================================================================
	["WAVE"] = {
		stack = "( -- n )",
		desc = "Current wave number",
		example = "WAVE .  \\ prints wave number",
		category = "Game State",
	},
	["CORE-HP"] = {
		stack = "( -- hp )",
		desc = "Current Core HP",
		example = "CORE-HP 500 < IF .\" DANGER\" THEN",
		category = "Game State",
	},
	["ENEMIES-LEFT"] = {
		stack = "( -- n )",
		desc = "Enemies remaining in wave",
		example = "ENEMIES-LEFT 0 = IF .\" CLEAR\" THEN",
		category = "Game State",
	},
	["BUILDING?"] = {
		stack = "( -- flag )",
		desc = "True if in build phase",
		example = "BUILDING? IF BUILD THEN",
		category = "Game State",
	},
	["FIGHTING?"] = {
		stack = "( -- flag )",
		desc = "True if in combat phase",
		example = "FIGHTING? IF .\" BATTLE\" THEN",
		category = "Game State",
	},

	--============================================================================
	-- I/O WORDS
	--============================================================================
	["."] = {
		stack = "( n -- )",
		desc = "Print top of stack",
		example = "5 3 + .  \\ prints 8",
		category = "I/O",
	},
	[".S"] = {
		stack = "( -- )",
		desc = "Print entire stack (non-destructive)",
		example = "1 2 3 .S  \\ prints <3> 1 2 3",
		category = "I/O",
	},
	["CR"] = {
		stack = "( -- )",
		desc = "Print newline",
		example = ".\" Hello\" CR .\" World\"",
		category = "I/O",
	},
	["EMIT"] = {
		stack = "( char -- )",
		desc = "Print character by ASCII code",
		example = "65 EMIT  \\ prints A",
		category = "I/O",
	},
	["BEEP"] = {
		stack = "( -- )",
		desc = "Play a beep sound",
		example = "AMMO? 0 = IF BEEP THEN",
		category = "I/O",
	},
}

-- Get help for a specific word
function HelpDatabase.getWordHelp(word)
	local upper = string.upper(word)
	return HelpDatabase.words[upper]
end

-- Get all words in a category
function HelpDatabase.getWordsInCategory(category)
	local result = {}
	for word, info in pairs(HelpDatabase.words) do
		if info.category == category then
			table.insert(result, { word = word, info = info })
		end
	end
	table.sort(result, function(a, b) return a.word < b.word end)
	return result
end

-- Get all word names
function HelpDatabase.getAllWords()
	local result = {}
	for word, _ in pairs(HelpDatabase.words) do
		table.insert(result, word)
	end
	table.sort(result)
	return result
end

return HelpDatabase
