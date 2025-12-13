local Players = game:GetService("Players")

local UnitSpawning = {}

local spawnedGolems = {}
local spawnedBots = {}
local nextGolemSpotId = 1
local nextBotSpotId = 1

local GolemRegistry = nil
local BotRegistry = nil
local arenaMap = nil

function UnitSpawning.init(golemReg, botReg, map)
	GolemRegistry = golemReg
	BotRegistry = botReg
	arenaMap = map
end

function UnitSpawning.spawnForPlayer(player, waveNumber)
	local userId = player.UserId
	local golemsSpawned = 0
	local botsSpawned = 0

	if arenaMap.initialGolems then
		for i, pos in ipairs(arenaMap.initialGolems) do
			local unlockWave = pos.unlockWave or 1
			local key = userId .. "_golem_" .. i
			if unlockWave <= waveNumber and not spawnedGolems[key] then
				local playerIndex = 0
				for idx, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then
						playerIndex = idx - 1
						break
					end
				end
				local offsetX = (playerIndex % 3) * 12 - 12
				local offsetZ = math.floor(playerIndex / 3) * 12

				local id = GolemRegistry.create(pos.x + offsetX, pos.z + offsetZ)
				if id then
					local golem = GolemRegistry.get(id)
					if golem then
						golem.spotId = nextGolemSpotId
						golem.ownerId = userId
						nextGolemSpotId = nextGolemSpotId + 1
						spawnedGolems[key] = id
						golemsSpawned = golemsSpawned + 1
						GolemRegistry.setGolemAttribute(golem)
					end
				end
			end
		end
	end

	if arenaMap.initialBots then
		for i, pos in ipairs(arenaMap.initialBots) do
			local unlockWave = pos.unlockWave or 1
			local key = userId .. "_bot_" .. i
			if unlockWave <= waveNumber and not spawnedBots[key] then
				local playerIndex = 0
				for idx, p in ipairs(Players:GetPlayers()) do
					if p.UserId == userId then
						playerIndex = idx - 1
						break
					end
				end
				local offsetX = (playerIndex % 3) * 10 - 10
				local offsetZ = math.floor(playerIndex / 3) * 10

				local id = BotRegistry.create(pos.x + offsetX, pos.z + offsetZ)
				if id then
					local bot = BotRegistry.get(id)
					if bot then
						bot.spotId = nextBotSpotId
						bot.ownerId = userId
						nextBotSpotId = nextBotSpotId + 1
						spawnedBots[key] = id
						botsSpawned = botsSpawned + 1
					end
				end
			end
		end
	end

	return golemsSpawned, botsSpawned
end

function UnitSpawning.spawnForWave(waveNumber)
	local totalGolems = 0
	local totalBots = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local g, b = UnitSpawning.spawnForPlayer(player, waveNumber)
		totalGolems = totalGolems + g
		totalBots = totalBots + b
	end

	if totalGolems > 0 or totalBots > 0 then
		GolemRegistry.broadcastState()
		BotRegistry.broadcastState()
	end
end

function UnitSpawning.removePlayerUnits(userId)
	for key, golemId in pairs(spawnedGolems) do
		if string.match(key, "^" .. userId .. "_golem_") then
			GolemRegistry.destroy(golemId)
			spawnedGolems[key] = nil
		end
	end

	for key, botId in pairs(spawnedBots) do
		if string.match(key, "^" .. userId .. "_bot_") then
			BotRegistry.destroy(botId)
			spawnedBots[key] = nil
		end
	end
end

function UnitSpawning.reset()
	spawnedGolems = {}
	spawnedBots = {}
	nextGolemSpotId = 1
	nextBotSpotId = 1
	UnitSpawning.spawnForWave(1)
	GolemRegistry.broadcastState()
	BotRegistry.broadcastState()
end

return UnitSpawning
