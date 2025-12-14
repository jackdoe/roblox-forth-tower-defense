local ClientState = {}

ClientState.currentScrap = 0
ClientState.nextTurretCost = 100

ClientState.currentTurretCount = 0
ClientState.currentBotCount = 0
ClientState.MAX_TURRETS = 10
ClientState.MAX_BOTS = 5

ClientState.currentPhase = "LOBBY"

ClientState.placementMode = false
ClientState.botPlacementMode = false
ClientState.isPlacementValid = false
ClientState.isBotPlacementValid = false

return ClientState
