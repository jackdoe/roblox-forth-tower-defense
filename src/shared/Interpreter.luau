-- Interpreter.luau
-- Forth interpreter with persistent word slots
-- Players have 3 word slots that persist across programs
-- User words execute at 2x speed!
--
-- NOTE: This module is in ReplicatedStorage so both Server and Client can use it.
-- For client-side tutorial/sandbox use, pass mock dependencies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Compiler = require(ReplicatedStorage.Forthy.Modules.Compiler)
local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)

-- Import OP enum from Compiler for fast numeric comparisons
local OP = Compiler.OP

-- Word modules are now in shared (ReplicatedStorage)
local StackWords = require(ReplicatedStorage.Forthy.Words.StackWords)
local MathWords = require(ReplicatedStorage.Forthy.Words.MathWords)

local Interpreter = {}
Interpreter.__index = Interpreter

local MAX_WORD_SLOTS = 3

function Interpreter.new(player, isMonster, deps)
	local self = setmetatable({}, Interpreter)

	self.id = game:GetService("HttpService"):GenerateGUID()
	self.isPlayer = not isMonster
	self.isMonster = isMonster or false
	self.player = not isMonster and player or nil
	self.character = nil

	self.hp = deps.Config.DEFAULT_HP
	self.maxHp = deps.Config.DEFAULT_HP
	self.memorySlots = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	self.sharedMemory = deps.GlobalMemory -- Reference to global shared memory

	-- Main program state
	-- Stack optimization: pre-allocated array with stack pointer
	self.maxStack = deps.Config.DEFAULT_MAX_STACK or 32
	self.stack = table.create(self.maxStack, 0)  -- Pre-allocate
	self.sp = 0  -- Stack pointer (0 = empty)
	self.code = {}
	self.tokens = {}
	self.tokenMap = {}
	self.hasLoop = false
	self.pc = 1
	self.status = "IDLE"
	self.error = nil
	self.output = ""

	-- Persistent word slots (survive across program loads!)
	self.wordSlots = {} -- Array of {name, tokens, code, tokenMap, hasLoop}

	-- Execution context
	self.execContext = "MAIN" -- "MAIN" or word name
	self.callStack = {}     -- Stack of {context, pc} for returning from words
	self.currentWordSlot = nil -- Index of currently executing word slot

	self.typeData = nil
	self.dict = {}
	self:buildDictionary(deps)

	return self
end

-- Find word slot by name
function Interpreter:findWordSlot(name)
	for i, slot in ipairs(self.wordSlots) do
		if slot and slot.name == name then
			return i, slot
		end
	end
	return nil, nil
end

-- Add or replace a word in slots
function Interpreter:addWordToSlots(definition)
	-- First, try to find existing slot with same name
	local existingIdx = self:findWordSlot(definition.name)
	if existingIdx then
		self.wordSlots[existingIdx] = definition
		return existingIdx
	end

	-- If we have empty slots, use the first one
	if #self.wordSlots < MAX_WORD_SLOTS then
		table.insert(self.wordSlots, definition)
		return #self.wordSlots
	end

	-- All slots full - kick out the last one, shift others down
	for i = MAX_WORD_SLOTS, 2, -1 do
		self.wordSlots[i] = self.wordSlots[i - 1]
	end
	self.wordSlots[1] = definition
	return 1
end

function Interpreter:buildDictionary(deps)
	-- Optimized stack operations using stack pointer (sp)
	-- Avoids table.insert/table.remove overhead
	local function push(v)
		if self.sp >= self.maxStack then
			self.error = "STACK OVERFLOW"
			self.status = "ERROR"
			return
		end
		self.sp = self.sp + 1
		self.stack[self.sp] = v
	end

	local function pop()
		if self.sp == 0 then
			self.error = "STACK UNDERFLOW"
			self.status = "ERROR"
			return nil
		end
		local v = self.stack[self.sp]
		self.sp = self.sp - 1
		return v
	end

	local function peek()
		if self.sp == 0 then return nil end
		return self.stack[self.sp]
	end

	local MAX_OUTPUT_LENGTH = 80
	local function trimOutput()
		if #self.output > MAX_OUTPUT_LENGTH then
			self.output = "..." .. string.sub(self.output, -(MAX_OUTPUT_LENGTH - 3))
		end
	end
	local function safeOutput(text)
		self.output = self.output .. text .. " "
		trimOutput()
	end
	self.trimOutput = trimOutput
	self.safeOutput = safeOutput

	-- Register core words (these are now in shared)
	StackWords.register(self.dict, push, pop, peek, self)
	MathWords.register(self.dict, push, pop, peek, self)

	-- Register game-specific words if provided in deps
	-- These are optional and only registered on the server
	if deps.GameWords then
		deps.GameWords.register(self.dict, push, pop, peek, self, deps)
	end
	if deps.SharedWords then
		deps.SharedWords.register(self.dict, push, pop, peek, self, deps)
	end
	if deps.GolemWords then
		deps.GolemWords.register(self.dict, push, pop, peek, self, deps)
	end
	if deps.LogisticsWords then
		deps.LogisticsWords.register(self.dict, push, pop, peek, self, deps)
	end

	self.dict["TRUE"] = function() push(-1) end
	self.dict["FALSE"] = function() push(0) end
	self.dict["DEPTH"] = function() push(self.sp) end  -- Use sp instead of #self.stack
	self.dict["STATUS"] = function() self.safeOutput("[" .. self.status .. "]") end
	self.dict["NOP"] = function() end
	self.dict["WAIT"] = function() end
end

function Interpreter:load(source)
	-- Clear word slots on each load (words are local to each program)
	self.wordSlots = {}

	-- Compile (no existing word slots since we cleared them)
	local code, tokens, tokenMap, hasLoop, newDefs, err = Compiler.compile(source, nil)

	if err then
		self.error = err
		self.status = "ERROR"
		return false
	end

	-- Add definitions to word slots
	if newDefs then
		for _, def in ipairs(newDefs) do
			self:addWordToSlots(def)
		end
	end

	-- Store main program
	self.code = code
	self.tokens = tokens
	self.tokenMap = tokenMap
	self.hasLoop = hasLoop

	-- Reset execution state
	self.pc = 1
	self.sp = 0  -- Reset stack pointer
	self.status = "READY"
	self.output = ""
	self.execContext = "MAIN"
	self.callStack = {}
	self.currentWordSlot = nil
	self.walkDir = nil
	self.lastWalkPos = nil

	return true
end

-- Get current code/tokenMap based on execution context
function Interpreter:getCurrentCode()
	if self.execContext == "MAIN" then
		return self.code, self.tokenMap, self.tokens
	else
		local _, slot = self:findWordSlot(self.execContext)
		if slot then
			return slot.code, slot.tokenMap, slot.tokens
		end
	end
	return self.code, self.tokenMap, self.tokens
end

-- Tick-consuming words
local TICK_WORDS = {
	["STOP"] = true,
	["HIT"] = true,
	["PAUSE"] = true,
	["BEEP"] = true,
	["TELEPORT"] = true,
	["AGAIN"] = true,
	["UNTIL"] = true,
	["REPEAT"] = true,
	["NOP"] = true,
	["WAIT"] = true,
	["TIMEOUT"] = true,
	["FORWARD"] = true,
	["FD"] = true,
	["F"] = true,
}

function Interpreter:step()
	if self.status == "ERROR" or self.status == "DONE" then
		return false, 0
	end
	if self.blocked then
		return true, 1
	end
	if self.chasingUntil and tick() < self.chasingUntil then
		return true, 1
	end

	local code, tokenMap, _ = self:getCurrentCode()

	-- Check if we've reached end of current context
	if self.pc > #code then
		-- If in a word, return to caller
		if #self.callStack > 0 then
			local returnInfo = table.remove(self.callStack)
			self.execContext = returnInfo.context
			self.pc = returnInfo.pc
			self.currentWordSlot = returnInfo.slotIdx
			return true, 0 -- Continue execution, no tick cost
		else
			self.status = "DONE"
			return false, 0
		end
	end

	local instr = code[self.pc]
	self.status = "RUNNING"
	local tickCost = 0

	-- Speed boost when inside user word
	local inUserWord = self.execContext ~= "MAIN"

	-- Use numeric OP comparisons (faster than string comparisons)
	local op = instr.op

	if op == OP.PUSH then
		if self.sp >= self.maxStack then
			self.error = "STACK OVERFLOW"
			self.status = "ERROR"
			return false, 0
		end
		self.sp = self.sp + 1
		self.stack[self.sp] = instr.value
		self.pc = self.pc + 1
	elseif op == OP.CALL_USER then
		-- Call user-defined word
		local slotIdx, slot = self:findWordSlot(instr.word)
		if not slot then
			self.error = "UNDEFINED WORD: " .. instr.word
			self.status = "ERROR"
			return false, 0
		end

		-- Push return info
		table.insert(self.callStack, {
			context = self.execContext,
			pc = self.pc + 1,
			slotIdx = self.currentWordSlot
		})

		-- Jump to word
		self.execContext = instr.word
		self.currentWordSlot = slotIdx
		self.pc = 1

		-- No tick cost for the call itself
	elseif op == OP.CALL then
		local word = self.dict[instr.word]
		if word then
			word()

			if TICK_WORDS[instr.word] then
				tickCost = inUserWord and 0.5 or 1 -- 2x speed in user words!
			end
		else
			self.error = "UNKNOWN WORD: " .. instr.word
			self.status = "ERROR"
			return false, 0
		end
		if self.status ~= "ERROR" then
			self.pc = self.pc + 1
		end
	elseif op == OP.JUMP then
		if instr.target <= self.pc then
			tickCost = inUserWord and 0.5 or 1
		end
		self.pc = instr.target
	elseif op == OP.JUMPZ then
		if self.sp == 0 then
			self.error = "STACK UNDERFLOW"
			self.status = "ERROR"
			return false, 0
		end
		local cond = self.stack[self.sp]
		self.sp = self.sp - 1
		if cond == 0 then
			self.pc = instr.target
		else
			self.pc = self.pc + 1
		end
	end

	return true, tickCost
end

function Interpreter:run(maxTicks, maxFreeSteps)
	maxTicks = maxTicks or 1
	maxFreeSteps = maxFreeSteps or 500

	local ticksConsumed = 0
	local freeSteps = 0

	while ticksConsumed < maxTicks and freeSteps < maxFreeSteps do
		local continue, tickCost = self:step()

		if not continue then break end

		if tickCost > 0 then
			ticksConsumed = ticksConsumed + tickCost
		else
			freeSteps = freeSteps + 1
		end
	end

	return self.status
end

function Interpreter:reset()
	self.pc = 1
	self.sp = 0  -- Reset stack pointer (stack contents don't need clearing)
	self.status = "READY"
	self.error = nil
	self.output = ""
	self.execContext = "MAIN"
	self.callStack = {}
	self.currentWordSlot = nil
end

-- Clear a specific word slot
function Interpreter:clearWordSlot(slotIdx)
	if slotIdx >= 1 and slotIdx <= #self.wordSlots then
		table.remove(self.wordSlots, slotIdx)
	end
end

-- Clear all word slots
function Interpreter:clearAllWordSlots()
	self.wordSlots = {}
end

-- Update a word slot's code by name
function Interpreter:updateWordSlot(name, newTokens)
	local idx, slot = self:findWordSlot(name)
	if not slot then return false, "Word not found" end

	-- Build word lookup for compilation
	local wordLookup = {}
	for _, s in ipairs(self.wordSlots) do
		if s and s.name then
			wordLookup[s.name] = true
		end
	end

	-- Compile the new tokens
	local tokenTypes = {}
	for i = 1, #newTokens do
		tokenTypes[i] = "word"
	end

	local code, tokenMap, hasLoop, err = Compiler.compileTokens(newTokens, tokenTypes, wordLookup)
	if err then
		return false, err
	end

	-- Update the slot
	self.wordSlots[idx] = {
		name = name,
		tokens = newTokens,
		code = code,
		tokenMap = tokenMap,
		hasLoop = hasLoop
	}

	return true, nil
end

-- Update word slot from source string
function Interpreter:updateWordSlotFromSource(name, source)
	-- Tokenize the source
	local tokens = {}
	local inComment = false

	for word in string.gmatch(source:upper(), "%S+") do
		if word == "(" then
			inComment = true
		elseif word == ")" then
			inComment = false
		elseif not inComment then
			table.insert(tokens, word)
		end
	end

	return self:updateWordSlot(name, tokens)
end

local function formatValueForClient(value)
	if TaggedValue.isTagged(value) then
		return TaggedValue.format(value)
	end
	return value
end

local function formatStackForClient(stack, sp)
	if not stack then return {} end
	local formatted = {}
	-- Only format up to stack pointer (sp) to exclude ghost values
	local limit = sp or #stack
	for i = 1, limit do
		formatted[i] = formatValueForClient(stack[i])
	end
	return formatted
end

-- Dynamic state: Changes every tick, send frequently
function Interpreter:getDynamicState()
	if self.trimOutput then
		self.trimOutput()
	end

	-- Get current token index (just the index, not the whole table)
	local currentTokenIdx = self:getCurrentTokenIndex()

	return {
		stack = formatStackForClient(self.stack, self.sp),  -- Pass sp to format only valid values
		rstack = formatStackForClient(self.rstack or {}, nil),
		pc = self.pc,
		status = self.status,
		error = self.error,
		output = self.output,
		hp = self.hp,
		maxHp = self.maxHp,
		paused = self.paused,
		dead = self.dead,
		-- Include tokens (needed for UI display)
		tokens = self.tokens,
		currentTokenIdx = currentTokenIdx,
		-- Execution context (MAIN or word name)
		execContext = self.execContext,
		callStackDepth = #self.callStack,
		-- Memory
		memorySlots = formatStackForClient(self.memorySlots),
		sharedMemory = formatStackForClient(self.sharedMemory or {}),
	}
end

-- Static state: Only changes when program loads, send once
function Interpreter:getStaticState()
	return {
		tokens = self.tokens,
		source = table.concat(self.tokens or {}, " "),
	}
end

-- Full state: For backwards compatibility and initial sends
function Interpreter:getState()
	local dynamic = self:getDynamicState()
	local static = self:getStaticState()

	-- Merge static into dynamic
	for k, v in pairs(static) do
		dynamic[k] = v
	end

	return dynamic
end

function Interpreter:getCurrentTokenIndex()
	local code, tokenMap = self:getCurrentCode()
	if self.pc <= #code then
		return tokenMap[self.pc]
	end
	return nil
end

return Interpreter
