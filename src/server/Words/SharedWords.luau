-- SharedWords.luau
-- Words available to both players and monsters

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)


local SharedWords = {}

function SharedWords.register(dict, push, pop, peek, self, deps)
	-- Initialize timeout queue if not present
	if not self.timeoutQueue then
		self.timeoutQueue = {}
	end

	-- TIMEOUT: Set a memory slot to a value after a delay
	-- Stack: ( delay value addr -- )
	-- Example: 60 0 S1 TIMEOUT  (after 60 seconds, set S1 to 0)
	dict["TIMEOUT"] = function()
		local addr = pop(); if addr == nil then return end
		local value = pop(); if value == nil then return end
		local delay = pop(); if delay == nil then return end

		-- Validate delay
		if type(delay) ~= "number" or delay < 0 then
			self.error = "TIMEOUT: delay must be positive number"
			self.status = "ERROR"
			return
		end

		-- Validate addr (must be tagged address)
		local slot = TaggedValue.getAddrSlot(addr)
		if not slot then
			self.error = "TIMEOUT: addr must be S0-S9"
			self.status = "ERROR"
			return
		end

		-- Schedule the timeout
		table.insert(self.timeoutQueue, {
			triggerTime = tick() + delay,
			value = value,
			addr = addr,
			slot = slot,
		})
	end

	-- GOLEM: Convert spot ID to golem reference
	-- Stack: ( spotId -- {golem:spotId} )
	dict["GOLEM"] = function()
		local spotId = pop(); if spotId == nil then return end

		if type(spotId) ~= "number" or spotId < 1 or spotId > 99 then
			self.error = "GOLEM: Invalid spot ID"
			self.status = "ERROR"
			return
		end

		push(TaggedValue.createGolem(math.floor(spotId)))
	end
end

-- Process timeout queue - called from main loop
-- Returns true if any timeouts were triggered
function SharedWords.processTimeouts(interp)
	if not interp.timeoutQueue or #interp.timeoutQueue == 0 then
		return false
	end

	local now = tick()
	local triggered = false
	local i = 1

	while i <= #interp.timeoutQueue do
		local timeout = interp.timeoutQueue[i]
		if now >= timeout.triggerTime then
			-- Trigger the timeout - set memory slot to value

			if TaggedValue.isLocalAddr(timeout.addr) then
				interp.memorySlots[timeout.slot] = timeout.value
			elseif TaggedValue.isSharedAddr(timeout.addr) then
				interp.sharedMemory[timeout.slot] = timeout.value
			end

			table.remove(interp.timeoutQueue, i)
			triggered = true
		else
			i = i + 1
		end
	end

	return triggered
end

return SharedWords
