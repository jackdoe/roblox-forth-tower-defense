-- Compiler.luau
-- Compiles Forth source code to bytecode
-- Extracts word definitions separately (they get stored in slots)
-- Tracks original token indices for highlighting

local Compiler = {}

local MAX_WORD_DEFINITIONS = 3

-- Opcode enum (numbers are faster than string comparisons in hot loops)
-- IMPORTANT: Keep in sync with Interpreter.luau
local OP = {
	PUSH = 1,
	CALL = 2,
	CALL_USER = 3,
	JUMP = 4,
	JUMPZ = 5,
}
Compiler.OP = OP  -- Export for Interpreter

-- Compile a token list to bytecode (used for both main and word definitions)
function Compiler.compileTokens(tokens, tokenTypes, userWords)
	local code = {}
	local controlStack = {}
	local tokenMap = {}
	local hasLoop = false

	local MIN_VALUE = -32768
	local MAX_VALUE = 32767

	for i, word in ipairs(tokens) do
		local tokenType = tokenTypes and tokenTypes[i] or "word"

		if tokenType == "string" then
			table.insert(code, { op = OP.PUSH, value = word })
			tokenMap[#code] = i
		elseif tonumber(word) then
			local num = tonumber(word)
			if num < MIN_VALUE or num > MAX_VALUE then
				return nil, nil, nil, "Number out of range: " .. word
			end
			table.insert(code, { op = OP.PUSH, value = num })
			tokenMap[#code] = i
		elseif word == "BEGIN" then
			table.insert(controlStack, { type = "BEGIN", addr = #code + 1, tokenIdx = i })
		elseif word == "AGAIN" then
			local ctrl = table.remove(controlStack)
			if not ctrl or ctrl.type ~= "BEGIN" then
				return nil, nil, nil, "AGAIN without BEGIN"
			end
			table.insert(code, { op = OP.JUMP, target = ctrl.addr })
			tokenMap[#code] = i
			hasLoop = true
		elseif word == "UNTIL" then
			local ctrl = table.remove(controlStack)
			if not ctrl or ctrl.type ~= "BEGIN" then
				return nil, nil, nil, "UNTIL without BEGIN"
			end
			table.insert(code, { op = OP.JUMPZ, target = ctrl.addr })
			tokenMap[#code] = i
			hasLoop = true
		elseif word == "WHILE" then
			table.insert(code, { op = OP.JUMPZ, target = 0 })
			tokenMap[#code] = i
			table.insert(controlStack, { type = "WHILE", addr = #code, tokenIdx = i })
		elseif word == "REPEAT" then
			local whileCtrl = table.remove(controlStack)
			if not whileCtrl or whileCtrl.type ~= "WHILE" then
				return nil, nil, nil, "REPEAT without WHILE"
			end
			local beginCtrl = table.remove(controlStack)
			if not beginCtrl or beginCtrl.type ~= "BEGIN" then
				return nil, nil, nil, "REPEAT without BEGIN"
			end
			table.insert(code, { op = OP.JUMP, target = beginCtrl.addr })
			tokenMap[#code] = i
			code[whileCtrl.addr].target = #code + 1
			hasLoop = true
		elseif word == "IF" then
			table.insert(code, { op = OP.JUMPZ, target = 0 })
			tokenMap[#code] = i
			table.insert(controlStack, { type = "IF", addr = #code, tokenIdx = i })
		elseif word == "ELSE" then
			local ctrl = table.remove(controlStack)
			if not ctrl or ctrl.type ~= "IF" then
				return nil, nil, nil, "ELSE without IF"
			end
			table.insert(code, { op = OP.JUMP, target = 0 })
			tokenMap[#code] = i
			code[ctrl.addr].target = #code + 1
			table.insert(controlStack, { type = "ELSE", addr = #code, tokenIdx = i })
		elseif word == "THEN" then
			local ctrl = table.remove(controlStack)
			if not ctrl or (ctrl.type ~= "IF" and ctrl.type ~= "ELSE") then
				return nil, nil, nil, "THEN without IF"
			end
			code[ctrl.addr].target = #code + 1
		elseif userWords and userWords[word] then
			-- Call to user-defined word
			table.insert(code, { op = OP.CALL_USER, word = word })
			tokenMap[#code] = i
		else
			table.insert(code, { op = OP.CALL, word = word })
			tokenMap[#code] = i
		end
	end

	if #controlStack > 0 then
		return nil, nil, nil, "Unmatched " .. controlStack[#controlStack].type
	end

	return code, tokenMap, hasLoop, nil
end

function Compiler.compile(source, existingWordSlots)
	-- Tokenize
	local tokens = {}
	local tokenTypes = {}
	local inComment = false
	local inString = false
	local currentString = ""

	local i = 1
	local len = #source
	while i <= len do
		local char = source:sub(i, i)

		if inString then
			if char == '"' then
				table.insert(tokens, currentString)
				table.insert(tokenTypes, "string")
				currentString = ""
				inString = false
			else
				currentString = currentString .. char
			end
			i = i + 1
		elseif char == '"' then
			inString = true
			currentString = ""
			i = i + 1
		elseif char:match("%s") then
			i = i + 1
		else
			local wordStart = i
			while i <= len and not source:sub(i, i):match("[%s\"]") do
				i = i + 1
			end
			local word = source:sub(wordStart, i - 1):upper()

			if word == "(" then
				inComment = true
			elseif word == ")" then
				inComment = false
			elseif not inComment and #word > 0 then
				table.insert(tokens, word)
				table.insert(tokenTypes, "word")
			end
		end
	end

	if inString then
		return nil, nil, nil, nil, nil, "Unterminated string literal"
	end

	-- Extract word definitions and main program
	-- Track original indices so tokenMap points to full source positions
	local newDefinitions = {} -- {name, tokens, tokenTypes, origIndices}
	local mainTokens = {}
	local mainTokenTypes = {}
	local mainOrigIndices = {} -- maps mainTokens index -> original tokens index

	local definingWord = nil
	local defTokens = {}
	local defTokenTypes = {}
	local defOrigIndices = {}

	for idx, word in ipairs(tokens) do
		local tokenType = tokenTypes[idx]

		if word == ":" and tokenType == "word" then
			if definingWord then
				return nil, nil, nil, nil, nil, "Nested definitions not allowed"
			end
			definingWord = "WAITING_NAME"
			defTokens = {}
			defTokenTypes = {}
			defOrigIndices = {}
		elseif definingWord == "WAITING_NAME" then
			if tokenType ~= "word" then
				return nil, nil, nil, nil, nil, "Expected word name after :"
			end
			if tonumber(word) then
				return nil, nil, nil, nil, nil, "Word name cannot be a number"
			end
			definingWord = word
		elseif word == ";" and tokenType == "word" and definingWord and definingWord ~= "WAITING_NAME" then
			table.insert(newDefinitions, {
				name = definingWord,
				tokens = defTokens,
				tokenTypes = defTokenTypes,
				origIndices = defOrigIndices
			})
			definingWord = nil
		elseif definingWord and definingWord ~= "WAITING_NAME" then
			table.insert(defTokens, word)
			table.insert(defTokenTypes, tokenType)
			table.insert(defOrigIndices, idx)
		else
			table.insert(mainTokens, word)
			table.insert(mainTokenTypes, tokenType)
			table.insert(mainOrigIndices, idx)
		end
	end

	if definingWord then
		return nil, nil, nil, nil, nil,
			"Unterminated definition: " .. (definingWord == "WAITING_NAME" and ":" or definingWord)
	end

	-- Check for too many word definitions
	if #newDefinitions > MAX_WORD_DEFINITIONS then
		return nil, nil, nil, nil, nil,
			"Too many words (max " .. MAX_WORD_DEFINITIONS .. ")"
	end

	-- Build word lookup from existing slots + new definitions
	local wordLookup = {}
	if existingWordSlots then
		for _, slot in ipairs(existingWordSlots) do
			if slot and slot.name then
				wordLookup[slot.name] = true
			end
		end
	end
	for _, def in ipairs(newDefinitions) do
		wordLookup[def.name] = true
	end

	-- Compile main program
	local code, tokenMap, hasLoop, err = Compiler.compileTokens(mainTokens, mainTokenTypes, wordLookup)
	if err then
		return nil, nil, nil, nil, nil, err
	end

	-- Remap tokenMap to original source indices
	for pc, localIdx in pairs(tokenMap) do
		tokenMap[pc] = mainOrigIndices[localIdx]
	end

	-- Compile word definitions
	local compiledDefinitions = {}
	for _, def in ipairs(newDefinitions) do
		local defCode, defTokenMap, defHasLoop, defErr = Compiler.compileTokens(def.tokens, def.tokenTypes, wordLookup)
		if defErr then
			return nil, nil, nil, nil, nil, "In " .. def.name .. ": " .. defErr
		end
		-- Remap word tokenMap to original source indices
		for pc, localIdx in pairs(defTokenMap) do
			defTokenMap[pc] = def.origIndices[localIdx]
		end
		table.insert(compiledDefinitions, {
			name = def.name,
			tokens = def.tokens,
			code = defCode,
			tokenMap = defTokenMap,
			hasLoop = defHasLoop
		})
	end

	return code, tokens, tokenMap, hasLoop, compiledDefinitions, nil
end

function Compiler.disassemble(code)
	local lines = {}
	for i, instr in ipairs(code) do
		local line = string.format("%3d: ", i)
		if instr.op == OP.PUSH then
			line = line .. "PUSH " .. tostring(instr.value)
		elseif instr.op == OP.CALL then
			line = line .. "CALL " .. instr.word
		elseif instr.op == OP.CALL_USER then
			line = line .. "CALL_USER " .. instr.word
		elseif instr.op == OP.JUMP then
			line = line .. "JUMP -> " .. tostring(instr.target)
		elseif instr.op == OP.JUMPZ then
			line = line .. "JUMPZ -> " .. tostring(instr.target)
		else
			line = line .. "??? " .. tostring(instr.op)
		end
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end

return Compiler
