-- ProgramLibrary.luau
-- Collection of example programs for Forthy
-- Organized by category with descriptions

local ProgramLibrary = {}

ProgramLibrary.categories = {
	"Golem Programs",
	"Player Automation",
	"Combat",
	"Utility",
}

ProgramLibrary.programs = {
	--============================================================================
	-- GOLEM PROGRAMS (for turrets)
	--============================================================================
	{
		name = "Basic Defense",
		category = "Golem Programs",
		desc = "Simple: shoot nearest enemy",
		code = [[
: DEFEND
  BEGIN
    SCAN 0 > IF
      NEAREST TARGET
      BULLET FIRE
    THEN
  AGAIN
;
DEFEND
]],
	},
	{
		name = "Focus Weak",
		category = "Golem Programs",
		desc = "Target lowest HP enemy first",
		code = [[
: FOCUS-WEAK
  BEGIN
    SCAN 0 > IF
      WEAKEST TARGET
      BULLET FIRE
    THEN
  AGAIN
;
FOCUS-WEAK
]],
	},
	{
		name = "Ice Slayer",
		category = "Golem Programs",
		desc = "Slow enemies with ICE ammo",
		code = [[
: ICE-SLAYER
  BEGIN
    SCAN 0 > IF
      NEAREST TARGET
      ICE FIRE
    THEN
  AGAIN
;
ICE-SLAYER
]],
	},
	{
		name = "Rocket Barrage",
		category = "Golem Programs",
		desc = "AOE damage with rockets",
		code = [[
: BARRAGE
  BEGIN
    SCAN 2 > IF
      NEAREST TARGET
      ROCKET FIRE
    ELSE
      SCAN 0 > IF
        NEAREST TARGET
        BULLET FIRE
      THEN
    THEN
  AGAIN
;
BARRAGE
]],
	},
	{
		name = "Double Tap",
		category = "Golem Programs",
		desc = "Two bullets per target (wave 3+)",
		code = [[
: DOUBLE-TAP
  BEGIN
    SCAN 0 > IF
      NEAREST TARGET
      BULLET BULLET 2FIRE
    THEN
  AGAIN
;
DOUBLE-TAP
]],
	},
	{
		name = "Triple Threat",
		category = "Golem Programs",
		desc = "Three bullets per target (wave 6+)",
		code = [[
: TRIPLE-THREAT
  BEGIN
    SCAN 0 > IF
      NEAREST TARGET
      BULLET BULLET BULLET 3FIRE
    THEN
  AGAIN
;
TRIPLE-THREAT
]],
	},
	{
		name = "Smart Ammo",
		category = "Golem Programs",
		desc = "Switch ammo based on enemy count",
		code = [[
: SMART-AMMO
  BEGIN
    SCAN DUP 3 > IF
      DROP NEAREST TARGET ROCKET FIRE
    ELSE
      0 > IF
        WEAKEST TARGET BULLET FIRE
      THEN
    THEN
  AGAIN
;
SMART-AMMO
]],
	},
	{
		name = "Shotgun Mode",
		category = "Golem Programs",
		desc = "Close range (10), 4x Damage",
		code = [[
: SHOTGUN
  BEGIN
    SCAN 0 > IF
      NEAREST TARGET
      BULLET FIRE
    THEN
  AGAIN
;
10 SET-RANGE SHOTGUN
]],
	},
	{
		name = "Sniper Mode",
		category = "Golem Programs",
		desc = "Long range (60), reduced damage",
		code = [[
: SNIPER
  BEGIN
    SCAN 0 > IF
      STRONGEST TARGET
      LASER FIRE
    THEN
  AGAIN
;
50 SET-RANGE SNIPER
]],
	},
	{
		name = "Frost Mage",
		category = "Golem Programs",
		desc = "Freeze enemies, finish with Rockets",
		code = [[
: FROST
  BEGIN
    SCAN 0 > IF
      NEAREST TARGET
      FREEZE ROCKET 2FIRE
    THEN
  AGAIN
;
40 SET-RANGE FROST
]],
	},

	--============================================================================
	-- PLAYER AUTOMATION (logistics)
	--============================================================================
	{
		name = "Mass Reload",
		category = "Player Automation",
		desc = "Visit and reload all golems",
		code = [[
: RELOAD-ALL
  BEGIN
    LOWEST-AMMO DUP IF
      GOLEM DUP TELEPORT RELOAD
    ELSE
      DROP
    THEN
  AGAIN
;
RELOAD-ALL
]],
	},

	--============================================================================
	-- COMBAT (player fighting)
	--============================================================================
	{
		name = "Spin Attack",
		category = "Combat",
		desc = "Spin and attack everything",
		code = [[
: SPIN-ATTACK
  BEGIN
    10 LEFT
    2 FORWARD
    BEGIN
      HIT?
    WHILE
    REPEAT
  AGAIN
;
SPIN-ATTACK
]],
	},

	{
		name = "Walk Attack",
		category = "Combat",
		desc = "Attack non stop",
		code = [[
: ATTACK
  BEGIN
    HIT
  AGAIN
;
ATTACK
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
