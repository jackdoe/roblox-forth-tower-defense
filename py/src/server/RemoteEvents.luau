local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")

local RemoteEvents = {}

local function create(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = PythonTD
	return event
end

RemoteEvents.runProgram = create("RunProgram")
RemoteEvents.pauseProgram = create("PauseProgram")
RemoteEvents.stepProgram = create("StepProgram")
RemoteEvents.resetProgram = create("ResetProgram")
RemoteEvents.stateUpdate = create("StateUpdate")
RemoteEvents.attackHit = create("AttackHit")
RemoteEvents.playerFire = create("PlayerFire")
RemoteEvents.requestState = create("RequestState")
RemoteEvents.enterBuildMode = create("EnterBuildMode")
RemoteEvents.playerReady = create("PlayerReady")
RemoteEvents.waveState = create("WaveState")
RemoteEvents.playerTeleport = create("PlayerTeleport")
RemoteEvents.playerMoveComplete = create("PlayerMoveComplete")
RemoteEvents.golemPlaceAt = create("GolemPlaceAt")
RemoteEvents.golemSell = create("GolemSell")
RemoteEvents.golemUpgrade = create("GolemUpgrade")
RemoteEvents.botBuild = create("BotBuild")
RemoteEvents.botSell = create("BotSell")

return RemoteEvents
