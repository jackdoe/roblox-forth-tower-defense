local ClientState = require(script.Parent.ClientState)

local WeaponSystem = {}

WeaponSystem.RELOAD_DURATION = 2.0

WeaponSystem.PROGRAMS = {
	[0] = {
		name = "PASSIVE",
		color = Color3.fromRGB(120, 120, 140),
		fireRate = 0,
		source = [[# PASSIVE - Save scrap
c = 0
while True:
    c += 1
]]
	},
	[1] = {
		name = "BULLET",
		color = Color3.fromRGB(255, 255, 150),
		fireRate = 0.3,
		source = [[# BULLET - Fast single target
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), BULLET)
]]
	},
	[2] = {
		name = "ROCKET",
		color = Color3.fromRGB(255, 100, 50),
		fireRate = 1.0,
		source = [[# ROCKET - Explosive splash damage
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), ROCKET)
]]
	},
	[3] = {
		name = "LASER",
		color = Color3.fromRGB(255, 50, 50),
		fireRate = 0.5,
		source = [[# LASER - Burning damage over time
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), LASER)
]]
	},
	[4] = {
		name = "GRENADE",
		color = Color3.fromRGB(100, 255, 100),
		fireRate = 1.5,
		source = [[# GRENADE - Thrown AOE explosive
while True:
    enemies = self.scan()
    if len(enemies) > 0:
        self.fire(nearest(enemies), GRENADE)
]]
	},
}

function WeaponSystem.load(weaponIndex, editor, hud, runProgramEvent)
	if weaponIndex < 0 or weaponIndex > 4 then return end
	if ClientState.isReloading then return end
	if ClientState.currentWeapon == weaponIndex then return end

	ClientState.isReloading = true
	ClientState.reloadEndTime = tick() + WeaponSystem.RELOAD_DURATION

	local weaponData = WeaponSystem.PROGRAMS[weaponIndex]
	if not weaponData then return end

	hud.setCurrentWeapon(weaponIndex)
	hud.highlightWeapon(weaponIndex)
	hud.triggerReloadCooldown(WeaponSystem.RELOAD_DURATION, weaponIndex)

	if editor and editor:getMode() == "player" then
		editor:setTextFormatted(weaponData.source)
		editor:setWeaponName(weaponData.name)
	end

	runProgramEvent:FireServer(weaponData.source, { type = "player" })

	task.delay(WeaponSystem.RELOAD_DURATION, function()
		if hud.getCurrentWeapon() == weaponIndex then
			ClientState.currentWeapon = weaponIndex
			ClientState.isReloading = false
		end
	end)
end

function WeaponSystem.restoreCurrent(editor)
	local weaponData = WeaponSystem.PROGRAMS[ClientState.currentWeapon]
	if weaponData and editor then
		editor:setTextFormatted(weaponData.source)
		editor:setWeaponName(weaponData.name)
	end
end

return WeaponSystem
