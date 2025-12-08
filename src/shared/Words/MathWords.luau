-- MathWords.luau
-- Math and comparison words for Forth
-- NOTE: This module is in ReplicatedStorage for both Server and Client access

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TaggedValue = require(ReplicatedStorage.Forthy.TaggedValue)

local MathWords = {}

function MathWords.register(dict, push, pop, peek, self)
	-- Basic math
	dict["+"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(b + a)
	end

	dict["-"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(b - a)
	end

	dict["*"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(b * a)
	end

	dict["/"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		if a == 0 then
			self.error = "DIVIDE BY ZERO"
			self.status = "ERROR"
			return
		end
		push(math.floor(b / a))
	end

	dict["MOD"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		if a == 0 then
			self.error = "DIVIDE BY ZERO"
			self.status = "ERROR"
			return
		end
		push(b % a)
	end

	dict["ABS"] = function()
		local a = pop(); if a == nil then return end
		push(math.abs(a))
	end

	dict["MIN"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(math.min(a, b))
	end

	dict["MAX"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(math.max(a, b))
	end

	dict["RND"] = function()
		local max = pop(); if max == nil then return end
		if max <= 0 then
			push(0) -- Safe fallback for invalid range
			return
		end
		push(math.random(0, max - 1))
	end

	-- Comparison (Forth true is -1)
	dict["="] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(a == b and -1 or 0)
	end

	dict["<"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(b < a and -1 or 0)
	end

	dict[">"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push(b > a and -1 or 0)
	end

	dict["0="] = function()
		local a = pop(); if a == nil then return end
		push(a == 0 and -1 or 0)
	end

	-- Logic
	dict["AND"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push((a ~= 0 and b ~= 0) and -1 or 0)
	end

	dict["OR"] = function()
		local a = pop(); if a == nil then return end
		local b = pop(); if b == nil then return end
		push((a ~= 0 or b ~= 0) and -1 or 0)
	end

	dict["NOT"] = function()
		local a = pop(); if a == nil then return end
		push(a == 0 and -1 or 0)
	end


	dict["."] = function()
		local v = pop(); if v == nil then return end
		self.safeOutput(TaggedValue.format(v))
	end
end

return MathWords
