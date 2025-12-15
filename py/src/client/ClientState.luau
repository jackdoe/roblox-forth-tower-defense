local ClientState = {}

ClientState.currentScrap = 0
ClientState.nextTurretCost = 100
ClientState.nextBotCost = 75
ClientState.nextPowerCost = 100
ClientState.currentPower = 1

ClientState.currentTurretCount = 0
ClientState.currentBotCount = 0
ClientState.MAX_TURRETS = 10
ClientState.MAX_BOTS = 5

ClientState.TURRET_BASE_COST = 100
ClientState.TURRET_COST_MULTIPLIER = 1.5
ClientState.BOT_BASE_COST = 75
ClientState.BOT_COST_MULTIPLIER = 1.3
ClientState.POWER_COSTS = {100, 200, 400, 800, 1600, 3200}

function ClientState.calculateTurretCost()
	return math.floor(ClientState.TURRET_BASE_COST * (ClientState.TURRET_COST_MULTIPLIER ^ ClientState.currentTurretCount))
end

function ClientState.calculateBotCost()
	return math.floor(ClientState.BOT_BASE_COST * (ClientState.BOT_COST_MULTIPLIER ^ ClientState.currentBotCount))
end

function ClientState.calculatePowerCost()
	return ClientState.POWER_COSTS[ClientState.currentPower] or (ClientState.currentPower * 1000)
end

ClientState.currentPhase = "LOBBY"

ClientState.placementMode = false
ClientState.botPlacementMode = false
ClientState.isPlacementValid = false
ClientState.isBotPlacementValid = false

return ClientState
