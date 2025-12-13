local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PythonTD = ReplicatedStorage:WaitForChild("PythonTD")
local Config = require(PythonTD.Config)

local Pathfinding = {}

Pathfinding.GROUND_Y = Config.PLATFORM_Y
Pathfinding.PATH_RECOMPUTE_COOLDOWN = 0.15
Pathfinding.BLOCKED_THRESHOLD = 0.1

Pathfinding.BOT_RADIUS = 2
Pathfinding.TURRET_RADIUS = 3

Pathfinding.BOT_BLOCKER_SIZE = Vector3.new(4, 4, 4)
Pathfinding.TURRET_BLOCKER_SIZE = Vector3.new(6, 4, 6)

Pathfinding.CELL_SIZE = 3
Pathfinding.DIAGONAL_COST = 1.414

local obstacleGetters = {}

function Pathfinding.registerObstacleGetter(name, getter)
	obstacleGetters[name] = getter
end

function Pathfinding.unregisterObstacleGetter(name)
	obstacleGetters[name] = nil
end

local function isBlocked(x, z, selfId, goalX, goalZ)
	for _, getter in pairs(obstacleGetters) do
		local obstacles = getter()
		for _, obs in pairs(obstacles) do
			if obs.id ~= selfId then
				local dx = obs.x - x
				local dz = obs.z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < obs.radius then
					local toGoalDx = goalX - x
					local toGoalDz = goalZ - z
					local toGoalDist = math.sqrt(toGoalDx * toGoalDx + toGoalDz * toGoalDz)
					if toGoalDist < obs.radius then
						return false
					end
					return true
				end
			end
		end
	end
	return false
end

local function worldToGrid(x, z)
	return math.floor(x / Pathfinding.CELL_SIZE), math.floor(z / Pathfinding.CELL_SIZE)
end

local function gridToWorld(gx, gz)
	return (gx + 0.5) * Pathfinding.CELL_SIZE, (gz + 0.5) * Pathfinding.CELL_SIZE
end

local function heuristic(ax, az, bx, bz)
	local dx = math.abs(ax - bx)
	local dz = math.abs(az - bz)
	return math.sqrt(dx * dx + dz * dz)
end

local NEIGHBORS = {
	{dx = 1, dz = 0, cost = 1},
	{dx = -1, dz = 0, cost = 1},
	{dx = 0, dz = 1, cost = 1},
	{dx = 0, dz = -1, cost = 1},
	{dx = 1, dz = 1, cost = 1.414},
	{dx = -1, dz = 1, cost = 1.414},
	{dx = 1, dz = -1, cost = 1.414},
	{dx = -1, dz = -1, cost = 1.414},
}

local function astar(startGX, startGZ, goalGX, goalGZ, selfId, goalWorldX, goalWorldZ)
	local openSet = {}
	local openSetMap = {}
	local cameFrom = {}
	local gScore = {}
	local fScore = {}

	local function key(gx, gz)
		return gx .. "," .. gz
	end

	local startKey = key(startGX, startGZ)
	gScore[startKey] = 0
	fScore[startKey] = heuristic(startGX, startGZ, goalGX, goalGZ)

	table.insert(openSet, {gx = startGX, gz = startGZ, f = fScore[startKey]})
	openSetMap[startKey] = true

	local iterations = 0
	local maxIterations = 500

	while #openSet > 0 and iterations < maxIterations do
		iterations = iterations + 1

		table.sort(openSet, function(a, b) return a.f < b.f end)
		local current = table.remove(openSet, 1)
		local currentKey = key(current.gx, current.gz)
		openSetMap[currentKey] = nil

		if current.gx == goalGX and current.gz == goalGZ then
			local path = {}
			local k = currentKey
			while cameFrom[k] do
				local gx, gz = k:match("([^,]+),([^,]+)")
				gx, gz = tonumber(gx), tonumber(gz)
				local wx, wz = gridToWorld(gx, gz)
				table.insert(path, 1, {x = wx, z = wz})
				k = cameFrom[k]
			end
			if #path > 0 then
				path[#path] = {x = goalWorldX, z = goalWorldZ}
			end
			return path
		end

		for _, neighbor in ipairs(NEIGHBORS) do
			local nx = current.gx + neighbor.dx
			local nz = current.gz + neighbor.dz

			local wx, wz = gridToWorld(nx, nz)
			if not isBlocked(wx, wz, selfId, goalWorldX, goalWorldZ) then
				local neighborKey = key(nx, nz)
				local tentativeG = gScore[currentKey] + neighbor.cost

				if not gScore[neighborKey] or tentativeG < gScore[neighborKey] then
					cameFrom[neighborKey] = currentKey
					gScore[neighborKey] = tentativeG
					fScore[neighborKey] = tentativeG + heuristic(nx, nz, goalGX, goalGZ)

					if not openSetMap[neighborKey] then
						table.insert(openSet, {gx = nx, gz = nz, f = fScore[neighborKey]})
						openSetMap[neighborKey] = true
					end
				end
			end
		end
	end

	return nil
end

function Pathfinding.isPositionBlocked(x, z, selfId)
	for _, getter in pairs(obstacleGetters) do
		local obstacles = getter()
		for _, obs in pairs(obstacles) do
			if obs.id ~= selfId then
				local dx = obs.x - x
				local dz = obs.z - z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < obs.radius then
					return true
				end
			end
		end
	end
	return false
end

function Pathfinding.findFreePosition(targetX, targetZ, selfId)
	if not Pathfinding.isPositionBlocked(targetX, targetZ, selfId) then
		return targetX, targetZ
	end

	for radius = 3, 30, 3 do
		for attempt = 1, 16 do
			local angle = (attempt / 16) * math.pi * 2
			local testX = targetX + math.cos(angle) * radius
			local testZ = targetZ + math.sin(angle) * radius
			if not Pathfinding.isPositionBlocked(testX, testZ, selfId) then
				return testX, testZ
			end
		end
	end

	return targetX, targetZ
end

function Pathfinding.computePath(startPos, goalPos, agentRadius, selfId)
	local startGX, startGZ = worldToGrid(startPos.X, startPos.Z)
	local goalGX, goalGZ = worldToGrid(goalPos.X, goalPos.Z)

	if startGX == goalGX and startGZ == goalGZ then
		return {{x = goalPos.X, z = goalPos.Z}}
	end

	local path = astar(startGX, startGZ, goalGX, goalGZ, selfId, goalPos.X, goalPos.Z)

	if path and #path > 0 then
		return path
	end

	return {{x = goalPos.X, z = goalPos.Z}}
end

function Pathfinding.createPathBlocker(parent, position, size, label)
	size = size or Pathfinding.BOT_BLOCKER_SIZE
	label = label or "Obstacle"

	local pathBlocker = Instance.new("Part")
	pathBlocker.Name = "PathBlocker"
	pathBlocker.Size = size
	pathBlocker.Position = position
	pathBlocker.Anchored = true
	pathBlocker.CanCollide = true
	pathBlocker.Transparency = 1
	pathBlocker.Parent = parent

	local pathMod = Instance.new("PathfindingModifier")
	pathMod.Label = label
	pathMod.PassThrough = false
	pathMod.Parent = pathBlocker

	return pathBlocker
end

function Pathfinding.updatePathBlockerPosition(model, position)
	local pathBlocker = model:FindFirstChild("PathBlocker")
	if pathBlocker then
		pathBlocker.Position = position
	end
end

return Pathfinding
