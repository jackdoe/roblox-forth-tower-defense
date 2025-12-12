-- DayNightCycle.luau
-- Handles day/night cycle with smooth transitions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.PythonTD.Config)

local DayNightCycle = {}

local running = false
local currentTime = 0  -- In hours (0-24)

-- Get time period (dawn, day, dusk, night)
local function getTimePeriod(hour)
	if hour >= 5 and hour < 7 then
		return "dawn"
	elseif hour >= 7 and hour < 18 then
		return "day"
	elseif hour >= 18 and hour < 20 then
		return "dusk"
	else
		return "night"
	end
end

-- Get brightness multiplier for current time
local function getBrightnessMultiplier(hour)
	local cycle = Config.DAY_NIGHT_CYCLE
	local period = getTimePeriod(hour)

	if period == "dawn" then
		-- Transition from night to day (5:00 - 7:00)
		local t = (hour - 5) / 2  -- 0 to 1
		return cycle.NIGHT_BRIGHTNESS + t * (cycle.DAY_BRIGHTNESS - cycle.NIGHT_BRIGHTNESS)
	elseif period == "day" then
		return cycle.DAY_BRIGHTNESS
	elseif period == "dusk" then
		-- Transition from day to night (18:00 - 20:00)
		local t = (hour - 18) / 2  -- 0 to 1
		return cycle.DAY_BRIGHTNESS + t * (cycle.NIGHT_BRIGHTNESS - cycle.DAY_BRIGHTNESS)
	else
		return cycle.NIGHT_BRIGHTNESS
	end
end

-- Get ambient color for current time
local function getAmbientColor(hour)
	local cycle = Config.DAY_NIGHT_CYCLE
	local period = getTimePeriod(hour)

	if period == "dawn" then
		local t = (hour - 5) / 2
		return cycle.NIGHT_AMBIENT:Lerp(cycle.DAY_AMBIENT, t)
	elseif period == "day" then
		return cycle.DAY_AMBIENT
	elseif period == "dusk" then
		local t = (hour - 18) / 2
		return cycle.DAY_AMBIENT:Lerp(cycle.NIGHT_AMBIENT, t)
	else
		return cycle.NIGHT_AMBIENT
	end
end

-- Update lighting based on current time
local function updateLighting()
	local lightConfig = Config.LIGHTING
	local brightnessMultiplier = getBrightnessMultiplier(currentTime)
	local ambientColor = getAmbientColor(currentTime)

	Lighting.ClockTime = currentTime
	Lighting.Brightness = lightConfig.BRIGHTNESS * brightnessMultiplier
	Lighting.Ambient = ambientColor
	Lighting.OutdoorAmbient = ambientColor

	-- Adjust fog based on time (denser at night)
	local fogMultiplier = 1 + (1 - brightnessMultiplier) * 0.5  -- Fog gets denser at night
	Lighting.FogEnd = lightConfig.FOG_END / fogMultiplier
end

function DayNightCycle.start()
	if running then return end

	local cycle = Config.DAY_NIGHT_CYCLE
	if not cycle.ENABLED then
		print("DayNightCycle: Disabled in config")
		return
	end

	running = true
	currentTime = Config.LIGHTING.START_TIME

	print("DayNightCycle: Started at " .. string.format("%02d:00", math.floor(currentTime)))

	task.spawn(function()
		local lastUpdate = tick()

		while running do
			local now = tick()
			local delta = now - lastUpdate
			lastUpdate = now

			-- Advance time
			-- SECONDS_PER_HOUR real seconds = 1 in-game hour
			local hoursPerSecond = 1 / cycle.SECONDS_PER_HOUR
			currentTime = currentTime + delta * hoursPerSecond

			-- Wrap around at 24
			if currentTime >= 24 then
				currentTime = currentTime - 24
			end

			-- Update lighting
			updateLighting()

			task.wait(0.1)  -- Update 10 times per second for smooth transitions
		end
	end)
end

function DayNightCycle.getTimeString()
	local hours = math.floor(currentTime)
	local minutes = math.floor((currentTime - hours) * 60)
	return string.format("%02d:%02d", hours, minutes)
end

return DayNightCycle
