local ClientState = require(script.Parent.ClientState)

local WeaponSystem = {}

WeaponSystem.RELOAD_DURATION = 2.0

WeaponSystem.DEFAULTS = {
	[0] = {
		name = "PASSIVE",
		color = Color3.fromRGB(120, 120, 140),
		fireRate = 0,
		source = [[
while True:
    self.collect()
]]
	},
	[1] = {
		name = "BULLET",
		color = Color3.fromRGB(255, 255, 150),
		fireRate = 0.3,
		source = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(BULLET)
]]
	},
	[2] = {
		name = "ROCKET",
		color = Color3.fromRGB(255, 100, 50),
		fireRate = 1.0,
		source = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(ROCKET)
]]
	},
	[3] = {
		name = "LASER",
		color = Color3.fromRGB(255, 50, 50),
		fireRate = 0.5,
		source = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(LASER)
]]
	},
	[4] = {
		name = "GRENADE",
		color = Color3.fromRGB(100, 255, 100),
		fireRate = 1.5,
		source = [[
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.set_target(nearest(enemies))
        self.fire(GRENADE)
]]
	},
}

function WeaponSystem.getProgram(weaponIndex)
	local draft = ClientState.getDraft("player", weaponIndex)
	if draft then return draft end
	local default = WeaponSystem.DEFAULTS[weaponIndex]
	return default and default.source or ""
end

function WeaponSystem.getDefault(weaponIndex)
	local default = WeaponSystem.DEFAULTS[weaponIndex]
	return default and default.source or ""
end

function WeaponSystem.load(weaponIndex, editor, hud, runProgramEvent)
	if weaponIndex < 0 or weaponIndex > 4 then return end
	if ClientState.isReloading then return end
	if ClientState.currentWeapon == weaponIndex then return end

	if editor and editor:getMode() == "player" then
		ClientState.saveDraft("player", ClientState.currentWeapon, editor:getText())
	end

	ClientState.isReloading = true
	ClientState.reloadEndTime = tick() + WeaponSystem.RELOAD_DURATION

	local weaponData = WeaponSystem.DEFAULTS[weaponIndex]
	if not weaponData then return end

	hud.setCurrentWeapon(weaponIndex)
	hud.highlightWeapon(weaponIndex)
	hud.triggerReloadCooldown(WeaponSystem.RELOAD_DURATION, weaponIndex)

	local programSource = WeaponSystem.getProgram(weaponIndex)

	if editor and editor:getMode() == "player" then
		editor:setTextFormatted(programSource)
		editor:setWeaponName(weaponData.name)
	end

	runProgramEvent:FireServer(programSource, { type = "player" })

	task.delay(WeaponSystem.RELOAD_DURATION, function()
		if hud.getCurrentWeapon() == weaponIndex then
			ClientState.currentWeapon = weaponIndex
			ClientState.isReloading = false
		end
	end)
end

function WeaponSystem.restoreCurrent(editor)
	local weaponIndex = ClientState.currentWeapon
	local weaponData = WeaponSystem.DEFAULTS[weaponIndex]
	if weaponData and editor then
		local programSource = WeaponSystem.getProgram(weaponIndex)
		editor:setTextFormatted(programSource)
		editor:setWeaponName(weaponData.name)
	end
end

function WeaponSystem.resetCurrent(editor, runProgramEvent)
	local weaponIndex = ClientState.currentWeapon
	ClientState.clearDraft("player", weaponIndex)
	local defaultSource = WeaponSystem.getDefault(weaponIndex)
	if editor then
		editor:setTextFormatted(defaultSource)
	end
	if runProgramEvent then
		runProgramEvent:FireServer(defaultSource, { type = "player" })
	end
end

return WeaponSystem
