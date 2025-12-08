-- StackWords.luau
-- Stack manipulation words for Forth
-- NOTE: This module is in ReplicatedStorage for both Server and Client access

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)

local StackWords = {}

function StackWords.register(dict, push, pop, peek, self)
	dict["DUP"] = function()
		local v = peek()
		if v == nil then
			self.error = "STACK UNDERFLOW"
			self.status = "ERROR"
			return
		end
		push(v)
	end

	dict["DROP"] = function()
		pop()
	end

	dict["SWAP"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(a); push(b)
	end

	dict["OVER"] = function()
		if self.sp < 2 then
			self.error = "STACK UNDERFLOW"
			self.status = "ERROR"
			return
		end
		push(self.stack[self.sp - 1])
	end

	dict["ROT"] = function()
		if self.sp < 3 then
			self.error = "STACK UNDERFLOW"
			self.status = "ERROR"
			return
		end
		local c = pop()
		local b = pop()
		local a = pop()
		push(b); push(c); push(a)
	end

	dict["CLEAR"] = function()
		self.sp = 0
	end

	-- Local memory slots M0-M9 (per-interpreter)
	for i = 0, 9 do
		local slotName = "M" .. i
		local slotIndex = i + 1  -- Lua 1-indexed
		local addr = TaggedValue.createLocalAddr(slotIndex)
		dict[slotName] = function()
			push(addr)
		end
	end

	-- Shared memory slots S0-S9 (global across all interpreters)
	for i = 0, 9 do
		local slotName = "S" .. i
		local slotIndex = i + 1  -- Lua 1-indexed
		local addr = TaggedValue.createSharedAddr(slotIndex)
		dict[slotName] = function()
			push(addr)
		end
	end

	-- ! (store) - ( value addr -- ) stores value at address
	dict["!"] = function()
		local addr = pop(); if addr == nil then return end
		local value = pop(); if value == nil then return end

		local slot = TaggedValue.getAddrSlot(addr)
		if not slot then
			self.error = "INVALID ADDR"
			self.status = "ERROR"
			return
		end

		if TaggedValue.isLocalAddr(addr) then
			self.memorySlots[slot] = value
		elseif TaggedValue.isSharedAddr(addr) then
			if self.sharedMemory then
				self.sharedMemory[slot] = value
			end
		end
	end

	-- @ (fetch) - ( addr -- value ) fetches value from address
	dict["@"] = function()
		local addr = pop(); if addr == nil then return end

		local slot = TaggedValue.getAddrSlot(addr)
		if not slot then
			self.error = "INVALID ADDR"
			self.status = "ERROR"
			return
		end

		if TaggedValue.isLocalAddr(addr) then
			push(self.memorySlots[slot] or 0)
		elseif TaggedValue.isSharedAddr(addr) then
			push((self.sharedMemory and self.sharedMemory[slot]) or 0)
		end
	end

	-- ============== RETURN STACK WORDS ==============
	-- Return stack is used to store keys and other values temporarily

	-- Initialize return stack if needed
	local function ensureRStack()
		if not self.rstack then
			self.rstack = {}
		end
	end

	-- >R - Move top of data stack to return stack
	dict[">R"] = function()
		local v = pop()
		if v == nil then
			self.error = "STACK UNDERFLOW"
			self.status = "ERROR"
			return
		end
		ensureRStack()
		if #self.rstack >= 10 then
			self.error = "RSTACK OVERFLOW"
			self.status = "ERROR"
			return
		end
		table.insert(self.rstack, v)
	end

	-- R> - Move top of return stack to data stack
	dict["R>"] = function()
		ensureRStack()
		if #self.rstack == 0 then
			self.error = "RSTACK UNDERFLOW"
			self.status = "ERROR"
			return
		end
		push(table.remove(self.rstack))
	end

	-- R@ - Copy top of return stack to data stack (non-destructive)
	dict["R@"] = function()
		ensureRStack()
		if #self.rstack == 0 then
			push(0)
			return
		end
		push(self.rstack[#self.rstack])
	end

	-- #R - Push count of items on return stack
	dict["#R"] = function()
		ensureRStack()
		push(#self.rstack)
	end

	-- #R@ - Copy ALL items from return stack to data stack (non-destructive)
	-- Items are pushed in order so top of rstack becomes top of data stack
	dict["#R@"] = function()
		ensureRStack()
		for i = 1, #self.rstack do
			push(self.rstack[i])
		end
	end

	-- NR@ - Copy top N items from return stack to data stack
	-- Usage: 3 NR@ (copies top 3 items from rstack)
	dict["NR@"] = function()
		local n = pop()
		if n == nil then return end
		ensureRStack()

		local count = math.min(n, #self.rstack)
		local startIdx = #self.rstack - count + 1

		for i = startIdx, #self.rstack do
			push(self.rstack[i])
		end
	end

	-- RCLEAR - Clear the return stack
	dict["RCLEAR"] = function()
		self.rstack = {}
	end
end

return StackWords
