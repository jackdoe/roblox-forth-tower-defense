local ClientState = {}

ClientState.golemStates = {}
ClientState.golemStatesRaw = {}
ClientState.botStates = {}
ClientState.botStatesRaw = {}

ClientState.currentScrap = 0
ClientState.currentTurretCount = 0
ClientState.currentBotCount = 0
ClientState.nextTurretCost = 100

ClientState.MAX_TURRETS = 10
ClientState.MAX_BOTS = 5

ClientState.currentPhase = "LOBBY"

ClientState.currentInterpreterTarget = {
	type = "player",
	golemId = nil,
	botId = nil,
	spotId = nil,
}

ClientState.savedPlayerProgram = nil
ClientState.golemProgramLoaded = false
ClientState.playerProgramLoaded = false

ClientState.currentWeapon = 1
ClientState.isReloading = false
ClientState.reloadEndTime = 0

ClientState.placementMode = false
ClientState.botPlacementMode = false
ClientState.isPlacementValid = false
ClientState.isBotPlacementValid = false

ClientState.bytecodeVisible = false
ClientState.bytecodeUserOverride = false

return ClientState
