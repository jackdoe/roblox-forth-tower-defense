-- TaggedValue.luau
-- Shared module for tagged values (keys, morse symbols, letters, positions)
-- Uses {t=type, v=value} tables to avoid conflicts with negative numbers

local TaggedValue = {}

-- Type constants
TaggedValue.TYPE_KEY = "key"
TaggedValue.TYPE_MORSE = "morse"
TaggedValue.TYPE_POS = "pos"
TaggedValue.TYPE_LETTER = "letter"
TaggedValue.TYPE_DIST = "dist"
TaggedValue.TYPE_LOCAL_ADDR = "local_addr"   -- M0-M9 (per-interpreter memory)
TaggedValue.TYPE_SHARED_ADDR = "shared_addr" -- S0-S9 (global shared memory)
TaggedValue.TYPE_GOLEM = "golem"
TaggedValue.TYPE_AMMO = "ammo"               -- BULLET, ROCKET, LASER

-- Ammo type constants
TaggedValue.AMMO_BULLET = 1
TaggedValue.AMMO_ROCKET = 2
TaggedValue.AMMO_LASER = 3
TaggedValue.AMMO_ICE = 4
TaggedValue.AMMO_FREEZE = 5

-- Morse values
TaggedValue.MORSE_DIT = 0
TaggedValue.MORSE_DAH = 1

-- ============== CREATION FUNCTIONS ==============

-- Create a key token
function TaggedValue.createKey(colorId)
	return {t = TaggedValue.TYPE_KEY, v = colorId}
end

-- Create a morse dit (.)
function TaggedValue.createDit()
	return {t = TaggedValue.TYPE_MORSE, v = TaggedValue.MORSE_DIT}
end

-- Create a morse dah (-)
function TaggedValue.createDah()
	return {t = TaggedValue.TYPE_MORSE, v = TaggedValue.MORSE_DAH}
end

-- Create a position value (x and y combined)
function TaggedValue.createPos(x, y)
	-- Store as two 16-bit values in a 32-bit number
	-- Add offset to handle negative coords (-32768 to 32767 range)
	local ox = math.floor(x) + 32768
	local oy = math.floor(y) + 32768
	return {t = TaggedValue.TYPE_POS, v = bit32.bor(bit32.lshift(ox, 16), oy)}
end

-- Create a letter value from a character
function TaggedValue.createLetter(char)
	return {t = TaggedValue.TYPE_LETTER, v = char:upper()}
end

-- Create a distance value (rounded cells)
function TaggedValue.createDist(dist)
	return {t = TaggedValue.TYPE_DIST, v = math.floor(dist + 0.5)}
end

-- Create a local memory address (M0-M9, per-interpreter)
function TaggedValue.createLocalAddr(slot)
	return {t = TaggedValue.TYPE_LOCAL_ADDR, v = slot}
end

-- Create a shared memory address (S0-S9, global)
function TaggedValue.createSharedAddr(slot)
	return {t = TaggedValue.TYPE_SHARED_ADDR, v = slot}
end

-- Create a golem reference
function TaggedValue.createGolem(spotId)
	return {t = TaggedValue.TYPE_GOLEM, v = spotId}
end

-- Create ammo types
function TaggedValue.createBullet()
	return {t = TaggedValue.TYPE_AMMO, v = TaggedValue.AMMO_BULLET}
end

function TaggedValue.createRocket()
	return {t = TaggedValue.TYPE_AMMO, v = TaggedValue.AMMO_ROCKET}
end

function TaggedValue.createLaser()
	return {t = TaggedValue.TYPE_AMMO, v = TaggedValue.AMMO_LASER}
end

function TaggedValue.createIce()
	return {t = TaggedValue.TYPE_AMMO, v = TaggedValue.AMMO_ICE}
end

function TaggedValue.createFreeze()
	return {t = TaggedValue.TYPE_AMMO, v = TaggedValue.AMMO_FREEZE}
end

-- ============== TYPE CHECK FUNCTIONS ==============

-- Check if value is a tagged value (table with t field)
function TaggedValue.isTagged(value)
	return type(value) == "table" and value.t ~= nil
end

-- Check if value is a key token
function TaggedValue.isKey(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_KEY
end

-- Check if value is a morse symbol
function TaggedValue.isMorse(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_MORSE
end

-- Check if value is a dit
function TaggedValue.isDit(value)
	return TaggedValue.isMorse(value) and value.v == TaggedValue.MORSE_DIT
end

-- Check if value is a dah
function TaggedValue.isDah(value)
	return TaggedValue.isMorse(value) and value.v == TaggedValue.MORSE_DAH
end

-- Check if value is a position
function TaggedValue.isPos(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_POS
end

-- Check if value is a letter token
function TaggedValue.isLetter(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_LETTER
end

-- Check if value is a distance
function TaggedValue.isDist(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_DIST
end

-- Check if value is a local memory address (M0-M9)
function TaggedValue.isLocalAddr(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_LOCAL_ADDR
end

-- Check if value is a shared memory address (S0-S9)
function TaggedValue.isSharedAddr(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_SHARED_ADDR
end

-- Check if value is any memory address (local or shared)
function TaggedValue.isAddr(value)
	return TaggedValue.isLocalAddr(value) or TaggedValue.isSharedAddr(value)
end

-- Check if value is a golem reference
function TaggedValue.isGolem(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_GOLEM
end

-- Check if value is an ammo type
function TaggedValue.isAmmo(value)
	return type(value) == "table" and value.t == TaggedValue.TYPE_AMMO
end

-- ============== GETTER FUNCTIONS ==============

-- Get the color ID from a key token
function TaggedValue.getKeyColor(value)
	if not TaggedValue.isKey(value) then return nil end
	return value.v
end

-- Get X coordinate from position
function TaggedValue.getPosX(value)
	if not TaggedValue.isPos(value) then return nil end
	local ox = bit32.rshift(value.v, 16)
	return ox - 32768
end

-- Get Y coordinate from position
function TaggedValue.getPosY(value)
	if not TaggedValue.isPos(value) then return nil end
	local oy = bit32.band(value.v, 0xFFFF)
	return oy - 32768
end

-- Get both coordinates from position
function TaggedValue.getPos(value)
	if not TaggedValue.isPos(value) then return nil, nil end
	local ox = bit32.rshift(value.v, 16)
	local oy = bit32.band(value.v, 0xFFFF)
	return ox - 32768, oy - 32768
end

-- Get the character from a letter value
function TaggedValue.getLetterChar(value)
	if not TaggedValue.isLetter(value) then return nil end
	return value.v
end

-- Get the distance value
function TaggedValue.getDist(value)
	if not TaggedValue.isDist(value) then return nil end
	return value.v
end

-- Get the slot index from an address (1-10)
function TaggedValue.getAddrSlot(value)
	if not TaggedValue.isAddr(value) then return nil end
	return value.v
end

-- Get the spot ID from a golem reference
function TaggedValue.getGolemSpotId(value)
	if not TaggedValue.isGolem(value) then return nil end
	return value.v
end

-- Get the ammo type (1=BULLET, 2=ROCKET, 3=LASER)
function TaggedValue.getAmmoType(value)
	if not TaggedValue.isAmmo(value) then return nil end
	return value.v
end

-- ============== FORMAT FUNCTIONS ==============

-- Key color names (for display)
TaggedValue.COLOR_NAMES = {
	[1] = "PINK",
	[2] = "BLUE",
	[3] = "GREEN",
	[4] = "YELLOW",
	[5] = "RED",
	[6] = "PURPLE",
}

-- Key color RGB values
TaggedValue.COLOR_RGB = {
	[1] = Color3.fromRGB(255, 150, 200),  -- PINK
	[2] = Color3.fromRGB(100, 150, 255),  -- BLUE
	[3] = Color3.fromRGB(100, 255, 100),  -- GREEN
	[4] = Color3.fromRGB(255, 255, 100),  -- YELLOW
	[5] = Color3.fromRGB(255, 100, 100),  -- RED
	[6] = Color3.fromRGB(200, 100, 255),  -- PURPLE
}

-- Format any tagged value for display (short, readable form)
function TaggedValue.format(value)
	if not TaggedValue.isTagged(value) then
		return tostring(value)
	end

	local t = value.t
	local v = value.v

	if t == TaggedValue.TYPE_KEY then
		local colorName = TaggedValue.COLOR_NAMES[v] or "?"
		return colorName
	elseif t == TaggedValue.TYPE_MORSE then
		return v == TaggedValue.MORSE_DIT and "." or "-"
	elseif t == TaggedValue.TYPE_POS then
		local x, y = TaggedValue.getPos(value)
		return x .. "," .. y
	elseif t == TaggedValue.TYPE_LETTER then
		return v
	elseif t == TaggedValue.TYPE_DIST then
		return v .. "m"
	elseif t == TaggedValue.TYPE_LOCAL_ADDR then
		return "&M" .. (v - 1)
	elseif t == TaggedValue.TYPE_SHARED_ADDR then
		return "&S" .. (v - 1)
	elseif t == TaggedValue.TYPE_GOLEM then
		return "G" .. v
	elseif t == TaggedValue.TYPE_AMMO then
		local names = {[1] = "BULLET", [2] = "ROCKET", [3] = "LASER", [4] = "ICE", [5] = "FREEZE"}
		return names[v] or "AMMO?"
	end

	return tostring(v)
end

-- ============== COMPARISON ==============

-- Compare two tagged values for equality
function TaggedValue.equals(a, b)
	-- Both must be tables
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	-- Same type?
	if a.t ~= b.t then return false end
	-- Compare values
	return a.v == b.v
end

return TaggedValue
