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

	-- Single winding path for enemies
	-- Enemies spawn at entrance and follow waypoints to core
	enemyPath = {
		{ x = 30,  z = 150 },   -- Entrance (west edge)
		{ x = 60,  z = 150 },   -- Turn 1 (into first corridor)
		{ x = 60,  z = 80 },    -- Turn 2 (north)
		{ x = 120, z = 80 },    -- Turn 3 (east)
		{ x = 120, z = 220 },   -- Turn 4 (south, long stretch)
		{ x = 180, z = 220 },   -- Turn 5 (east)
		{ x = 180, z = 120 },   -- Turn 6 (north)
		{ x = 150, z = 120 },   -- Turn 7 (west, approach core)
		{ x = 150, z = 150 },   -- Core position (final destination)
	},

	-- Single spawn gate (entrance to the path)
	spawnGates = {
		{ x = 30,  z = 150, name = "Entrance", direction = "east", unlockWave = 1 },
	},

	golemMinDistance = 8,

	-- Restricted zones (winding path layout)
	restrictedZones = {
		-- Core protection zone (circular)
		{ type = "circle",   x = 150,     z = 150,            radius = 20, reason = "core" },

		-- Winding snake path segments (matching enemyPath waypoints)
		-- Segment 1: Entrance (30,150) to (60,150) - horizontal
		{ type = "rect",     x1 = 20,     z1 = 140,           x2 = 70,     z2 = 160,       reason = "path" },
		-- Segment 2: (60,150) to (60,80) - vertical north
		{ type = "rect",     x1 = 50,     z1 = 70,            x2 = 70,     z2 = 160,       reason = "path" },
		-- Segment 3: (60,80) to (120,80) - horizontal east
		{ type = "rect",     x1 = 50,     z1 = 70,            x2 = 130,    z2 = 90,        reason = "path" },
		-- Segment 4: (120,80) to (120,220) - vertical south (long)
		{ type = "rect",     x1 = 110,    z1 = 70,            x2 = 130,    z2 = 230,       reason = "path" },
		-- Segment 5: (120,220) to (180,220) - horizontal east
		{ type = "rect",     x1 = 110,    z1 = 210,           x2 = 190,    z2 = 230,       reason = "path" },
		-- Segment 6: (180,220) to (180,120) - vertical north
		{ type = "rect",     x1 = 170,    z1 = 110,           x2 = 190,    z2 = 230,       reason = "path" },
		-- Segment 7: (180,120) to (150,120) - horizontal west to core approach
		{ type = "rect",     x1 = 140,    z1 = 110,           x2 = 190,    z2 = 130,       reason = "path" },

		-- Entrance gate spawn area
		{ type = "circle",   x = 30,      z = 150,            radius = 15, reason = "gate" },

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

	-- No auto-spawned units - players build everything themselves

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
STATUS ( id -- ammo ) Check golem
TELEPORT ( id -- ) Warp to golem
REFILL ( -- ) Give ammo to nearby golem

Automate your supply runs!
			]],
		},
	},
}
