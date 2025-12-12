-- Arena.luau
-- Tower Defense map with central Core and 8 spawn gates
-- UPDATED: Paths extended to overlap Core and Gates for seamless visuals

return {
	version = 4,
	name = "The Arena",
	gameMode = "TowerDefense",

	-- Map dimensions
	width = 50,
	height = 50,

	-- The Core (center 150, 150)
	core = {
		x = 150,
		z = 150,
		hp = 1000,
	},

	-- Player spawn point
	playerSpawn = {
		x = 150,
		z = 160,
		facingAngle = 0,
	},

	-- Enemy spawn gates
	spawnGates = {
		-- Cardinal gates
		{ x = 150, z = 30,  name = "North",     direction = "south",     unlockWave = 1 },
		{ x = 150, z = 270, name = "South",     direction = "north",     unlockWave = 2 },
		{ x = 30,  z = 150, name = "West",      direction = "east",      unlockWave = 3 },
		{ x = 270, z = 150, name = "East",      direction = "west",      unlockWave = 4 },
		-- Diagonal gates
		{ x = 50,  z = 50,  name = "NorthWest", direction = "southeast", unlockWave = 5 },
		{ x = 250, z = 50,  name = "NorthEast", direction = "southwest", unlockWave = 6 },
		{ x = 50,  z = 250, name = "SouthWest", direction = "northeast", unlockWave = 7 },
		{ x = 250, z = 250, name = "SouthEast", direction = "northwest", unlockWave = 8 },
	},

	golemMinDistance = 8,

	-- Restricted zones
	-- UPDATED: Coordinates pushed closer to 150 (Core) to ensure overlap
	restrictedZones = {
		-- Core protection zone (circular)
		{ type = "circle",   x = 150,     z = 150,            radius = 25, reason = "core" },

		-- Monster paths (rectangular lanes)
		-- VISUAL FIX: Extended Z/X values to penetrate the Core circle (125 -> 140, 175 -> 160)

		-- North path (ends deeper at z=140)
		{ type = "rect",     x1 = 140,    z1 = 0,             x2 = 160,    z2 = 140,       reason = "path" },

		-- South path (starts deeper at z=160)
		{ type = "rect",     x1 = 140,    z1 = 160,           x2 = 160,    z2 = 300,       reason = "path" },

		-- West path (ends deeper at x=140)
		{ type = "rect",     x1 = 0,      z1 = 140,           x2 = 140,    z2 = 160,       reason = "path" },

		-- East path (starts deeper at x=160)
		{ type = "rect",     x1 = 160,    z1 = 140,           x2 = 300,    z2 = 160,       reason = "path" },

		-- Diagonal paths
		-- VISUAL FIX: Extended to reach 140/160 to touch core, extended outwards to cover gates
		{ type = "line",     x1 = 40,     z1 = 40,            x2 = 140,    z2 = 140,       width = 15,     reason = "path" }, -- NW
		{ type = "line",     x1 = 260,    z1 = 40,            x2 = 160,    z2 = 140,       width = 15,     reason = "path" }, -- NE
		{ type = "line",     x1 = 40,     z1 = 260,           x2 = 140,    z2 = 160,       width = 15,     reason = "path" }, -- SW
		{ type = "line",     x1 = 260,    z1 = 260,           x2 = 160,    z2 = 160,       width = 15,     reason = "path" }, -- SE

		-- Gate spawn areas
		{ type = "circle",   x = 150,     z = 30,             radius = 15, reason = "gate" },
		{ type = "circle",   x = 150,     z = 270,            radius = 15, reason = "gate" },
		{ type = "circle",   x = 30,      z = 150,            radius = 15, reason = "gate" },
		{ type = "circle",   x = 270,     z = 150,            radius = 15, reason = "gate" },
		{ type = "circle",   x = 50,      z = 50,             radius = 15, reason = "gate" },
		{ type = "circle",   x = 250,     z = 50,             radius = 15, reason = "gate" },
		{ type = "circle",   x = 50,      z = 250,            radius = 15, reason = "gate" },
		{ type = "circle",   x = 250,     z = 250,            radius = 15, reason = "gate" },

		-- Map boundaries
		{ type = "boundary", margin = 15, reason = "boundary" },
	},

	grid = {},

	decorations = {},

	settings = {
		buildTime = 30,
		startingScrap = 300,
		golemBaseCost = 100,
	},

	-- PROGRESSIVE UNLOCKS: Start small, grow as gates open
	-- Wave 1: 2 golems, 1 bot (starter)
	-- By Wave 8: 8 golems, 4 bots (full army)
	initialGolems = {
		-- Starter turrets (Wave 1)
		{ x = 150, z = 120, unlockWave = 1 }, -- #1 North path
		{ x = 150, z = 180, unlockWave = 1 }, -- #2 South path
		-- Wave 2-4: Cardinal directions
		{ x = 120, z = 150, unlockWave = 3 }, -- #3 West path
		{ x = 180, z = 150, unlockWave = 4 }, -- #4 East path
		-- Wave 5-8: Diagonal corners
		{ x = 125, z = 125, unlockWave = 5 }, -- #5 NW diagonal
		{ x = 175, z = 125, unlockWave = 6 }, -- #6 NE diagonal
		{ x = 125, z = 175, unlockWave = 7 }, -- #7 SW diagonal
		{ x = 175, z = 175, unlockWave = 8 }, -- #8 SE diagonal
	},

	-- Bots unlock progressively too
	initialBots = {
		{ x = 145, z = 145, unlockWave = 1 }, -- #1 Starter bot
		{ x = 155, z = 145, unlockWave = 3 }, -- #2 Unlocks with West gate
		{ x = 145, z = 155, unlockWave = 5 }, -- #3 Unlocks with NW diagonal
		{ x = 155, z = 155, unlockWave = 7 }, -- #4 Unlocks with SW diagonal
	},

	-- Help tokens for teaching (adjusted for larger map)
	helpTokens = {
		{
			x = 140,
			z = 150,
			title = "Welcome, Commander!",
			text = [[
Defend the CORE from enemy waves!

CONTROLS:
- Click to attack enemies
- F2: Run your code
- F3: Pause/Resume

BUILD PHASE:
Place Golems (turrets) at the marked spots.
Each Golem runs YOUR code!
			]],
		},
		{
			x = 160,
			z = 150,
			title = "Programming Golems",
			text = [[
Golems are programmable turrets.
They start with basic code:

  SCAN 0 > IF
    NEAREST TARGET FIRE
  THEN

You can write BETTER code!
Try: WEAKEST TARGET FIRE
			]],
		},
		{
			x = 150,
			z = 130,
			title = "Golem Words",
			text = [[
SCAN   ( -- n )  Count enemies in range
NEAREST ( -- id ) Get closest enemy
WEAKEST ( -- id ) Get lowest HP enemy
TARGET  ( id -- ) Aim at enemy
FIRE    ( -- )    Shoot! (uses ammo)
AMMO?   ( -- n )  Check ammo left
			]],
		},
		{
			x = 150,
			z = 170,
			title = "Automation",
			text = [[
YOU can be programmed too!

MACHINES ( -- n )  How many golems?
STATUS ( id -- ammo hp ) Check golem
TELEPORT ( id -- ) Warp to golem
REFILL ( -- ) Give ammo to nearby golem

Automate your supply runs!
			]],
		},
	},
}
