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

ClientState.drafts = {}

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

function ClientState.getDraftKey(entityType, entityId)
	if entityType == "player" then
		return "player_" .. (entityId or 0)
	elseif entityType == "bot" then
		return "bot_" .. entityId
	elseif entityType == "golem" then
		return "golem_" .. entityId
	end
	return nil
end

function ClientState.saveDraft(entityType, entityId, source)
	local key = ClientState.getDraftKey(entityType, entityId)
	if key then
		ClientState.drafts[key] = source
	end
end

function ClientState.getDraft(entityType, entityId)
	local key = ClientState.getDraftKey(entityType, entityId)
	return key and ClientState.drafts[key]
end

function ClientState.clearDraft(entityType, entityId)
	local key = ClientState.getDraftKey(entityType, entityId)
	if key then
		ClientState.drafts[key] = nil
	end
end

return ClientState
