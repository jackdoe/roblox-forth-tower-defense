-- Interpreter.luau
-- Python interpreter wrapper for tower defense game
-- Bridges Python/Runtime to the game infrastructure

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Python = require(script.Parent.Python)

local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter.new(player, isMonster, deps)
	local self = setmetatable({}, Interpreter)

	self.id = game:GetService("HttpService"):GenerateGUID()
	self.isPlayer = not isMonster
	self.isMonster = isMonster or false
	self.player = not isMonster and player or nil
	self.character = nil

	-- Python runtime
	self.runtime = Python.createRuntime()
	self.source = ""
	self.lastProgram = ""

	-- State
	self.status = "IDLE"
	self.error = nil
	self.output = ""
	self.paused = false
	self.blocked = false

	-- Game environment (will be set by GolemRegistry/BotRegistry)
	self.gameEnv = {}
	self.deps = deps

	-- For golem-specific state
	self.ammo = 0
	self.maxAmmo = 0
	self.range = 40
	self.dynamicRange = 40
	self.target = nil
	self.lastFireTime = 0

	return self
end

-- Set game environment for Python code
function Interpreter:setGameEnvironment(env)
	self.gameEnv = env
	self.runtime:setEnvironment(env)
end

-- Load Python source code
function Interpreter:load(source)
	self.source = source
	self.lastProgram = source
	self.error = nil
	self.output = ""

	-- Parse Python source to AST
	local success, err = self.runtime:compile(source)

	if not success then
		self.error = err
		self.status = "ERROR"
		return false
	end

	-- Update runtime environment with current game state
	self.runtime:setEnvironment(self.gameEnv)

	-- Start execution
	local startSuccess, startErr = self.runtime:start()
	if not startSuccess then
		self.error = startErr or "Failed to start"
		self.status = "ERROR"
		return false
	end

	self.status = "READY"
	self.paused = false
	return true
end

-- Step execution (called each tick)
function Interpreter:step()
	if self.status == "ERROR" or self.status == "DONE" then
		return false, 0
	end

	if self.paused or self.blocked then
		return true, 1
	end

	-- Run one step of Python execution
	local running = self.runtime:step()

	-- Check for errors
	local state = self.runtime:getState()
	if state.error then
		self.error = state.error
		self.status = "ERROR"
		return false, 0
	end

	-- Update output
	if #state.output > 0 then
		self.output = table.concat(state.output, "\n")
	end

	if running then
		self.status = "RUNNING"
		return true, 1
	else
		self.status = "DONE"
		return false, 0
	end
end

-- Run for multiple ticks (API compatible)
function Interpreter:run(maxTicks, maxFreeSteps)
	maxTicks = maxTicks or 1

	local ticksConsumed = 0

	for _ = 1, maxTicks do
		local continue, tickCost = self:step()
		if not continue then break end
		ticksConsumed = ticksConsumed + tickCost
	end

	return self.status
end

-- Step once (execute single bytecode instruction - for debugger)
-- This steps through ONE instruction at a time, making the debugger
-- show exactly which bytecode is executing. More educational!
function Interpreter:stepOnce()
	if self.status == "ERROR" or self.status == "DONE" then
		return false
	end

	-- Run one bytecode instruction
	local running = false
	if self.runtime then
		running = self.runtime:stepOnce()
	end

	-- Check for errors
	if self.runtime then
		local state = self.runtime:getState()
		if state.error then
			self.error = state.error
			self.status = "ERROR"
			return false
		end

		-- Update output
		if #state.output > 0 then
			self.output = table.concat(state.output, "\n")
		end
	end

	if running then
		self.status = "RUNNING"  -- Still running
		return true
	else
		self.status = "DONE"
		return false
	end
end

-- Reset interpreter
function Interpreter:reset()
	self.runtime:stop()
	self.status = "READY"
	self.error = nil
	self.output = ""
	self.paused = false

	-- Reload the program if we have one
	if self.lastProgram and #self.lastProgram > 0 then
		self:load(self.lastProgram)
	end
end

-- Get current token index (for UI highlighting)
-- Derives from bytecode[ip].line - single source of truth
function Interpreter:getCurrentTokenIndex()
	if self.runtime then
		local state = self.runtime:getState()
		local bytecode = state.bytecode or {}
		local ip = state.vm and state.vm.ip or 1
		return bytecode[ip] and bytecode[ip].line or 0
	end
	return 0
end

-- Get state for client (API compatible)
function Interpreter:getState()
	local state = self:getDynamicState()
	local static = self:getStaticState()

	for k, v in pairs(static) do
		state[k] = v
	end

	return state
end

-- Dynamic state (changes frequently)
function Interpreter:getDynamicState()
	-- Trim output if too long
	local output = self.output
	if #output > 80 then
		output = "..." .. output:sub(-77)
	end

	-- Get Python variables from runtime (including nil values)
	-- Use special marker "__NIL__" for nil since Lua tables can't store nil
	local NIL_MARKER = "__NIL__"
	local variables = {}
	if self.runtime then
		-- First get all tracked variable names (includes nil values)
		if self.runtime.globalNames then
			for name in pairs(self.runtime.globalNames) do
				local value = self.runtime.globals[name]
				-- Skip internal function definitions
				if value == nil then
					variables[name] = NIL_MARKER
				elseif type(value) ~= "table" or not value._isFunction then
					variables[name] = value
				end
			end
		end
		-- Also include any untracked non-nil values
		if self.runtime.globals then
			for name, value in pairs(self.runtime.globals) do
				if variables[name] == nil then  -- Not already added
					if type(value) ~= "table" or not value._isFunction then
						variables[name] = value
					end
				end
			end
		end
	end

	-- Get VM state - client derives currentLine from bytecode[ip].line
	local vmState = nil
	local bytecode = {}
	if self.runtime then
		local runtimeState = self.runtime:getState()
		vmState = runtimeState.vm
		bytecode = runtimeState.bytecode or {}
	end

	return {
		vm = vmState,
		bytecode = bytecode,
		status = self.status,
		error = self.error,
		output = output,
		paused = self.paused,
		ammo = self.ammo,
		maxAmmo = self.maxAmmo,
		dynamicRange = self.dynamicRange,
		variables = variables,
	}
end

-- Static state (changes rarely)
function Interpreter:getStaticState()
	return {
		source = self.source,
		language = "Python",
	}
end

return Interpreter
