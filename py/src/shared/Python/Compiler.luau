-- Compiler.luau
-- Compiles Python AST to bytecode for the VM
-- Produces a flat array of instructions with source line mappings

local Parser = require(script.Parent.Parser)
local Lexer = require(script.Parent.Lexer)
local NT = Parser.NodeType
local TT = Lexer.TokenType

local Compiler = {}

-- Opcodes
Compiler.Op = {
	-- Stack operations
	LOAD_CONST = "LOAD_CONST",       -- Push constant value
	LOAD_VAR = "LOAD_VAR",           -- Push variable value
	STORE_VAR = "STORE_VAR",         -- Pop and store to variable
	LOAD_ATTR = "LOAD_ATTR",         -- Pop obj, push obj.attr
	STORE_ATTR = "STORE_ATTR",       -- Pop val, pop obj, obj.attr = val
	POP = "POP",                     -- Discard top of stack
	DUP = "DUP",                     -- Duplicate top of stack

	-- Binary operations
	BINARY_ADD = "BINARY_ADD",
	BINARY_SUB = "BINARY_SUB",
	BINARY_MUL = "BINARY_MUL",
	BINARY_DIV = "BINARY_DIV",
	BINARY_MOD = "BINARY_MOD",
	BINARY_POW = "BINARY_POW",
	BINARY_FLOOR_DIV = "BINARY_FLOOR_DIV",

	-- Comparison
	COMPARE_EQ = "COMPARE_EQ",
	COMPARE_NE = "COMPARE_NE",
	COMPARE_LT = "COMPARE_LT",
	COMPARE_GT = "COMPARE_GT",
	COMPARE_LE = "COMPARE_LE",
	COMPARE_GE = "COMPARE_GE",

	-- Logical
	BINARY_AND = "BINARY_AND",
	BINARY_OR = "BINARY_OR",
	UNARY_NOT = "UNARY_NOT",
	UNARY_NEG = "UNARY_NEG",

	-- Control flow
	JUMP = "JUMP",                   -- Unconditional jump
	JUMP_IF_FALSE = "JUMP_IF_FALSE", -- Pop, jump if falsy
	JUMP_IF_TRUE = "JUMP_IF_TRUE",   -- Pop, jump if truthy
	POP_JUMP_IF_FALSE = "POP_JUMP_IF_FALSE", -- Jump if false, always pop
	POP_JUMP_IF_TRUE = "POP_JUMP_IF_TRUE",   -- Jump if true, always pop

	-- Functions
	CALL = "CALL",                   -- Call function with n args
	RETURN = "RETURN",               -- Return from function
	MAKE_FUNCTION = "MAKE_FUNCTION", -- Create function object

	-- Data structures
	BUILD_LIST = "BUILD_LIST",       -- Create list from n stack items
	GET_INDEX = "GET_INDEX",         -- Pop index, pop list, push list[index]
	SET_INDEX = "SET_INDEX",         -- Pop val, pop index, pop list, set

	-- Iteration
	GET_ITER = "GET_ITER",           -- Convert to iterator
	FOR_ITER = "FOR_ITER",           -- Get next from iterator or jump

	-- Special
	YIELD = "YIELD",                 -- Yield execution for time-slice
	HALT = "HALT",                   -- End of program

	-- Tuple unpacking
	UNPACK_SEQUENCE = "UNPACK_SEQUENCE", -- Unpack n items from sequence
}

local Op = Compiler.Op

-- Map binary operators to opcodes
local BINARY_OP_MAP = {
	[TT.PLUS] = Op.BINARY_ADD,
	[TT.MINUS] = Op.BINARY_SUB,
	[TT.STAR] = Op.BINARY_MUL,
	[TT.SLASH] = Op.BINARY_DIV,
	[TT.PERCENT] = Op.BINARY_MOD,
	[TT.POWER] = Op.BINARY_POW,
	[TT.FLOOR_DIV] = Op.BINARY_FLOOR_DIV,
	[TT.EQ] = Op.COMPARE_EQ,
	[TT.NE] = Op.COMPARE_NE,
	[TT.LT] = Op.COMPARE_LT,
	[TT.GT] = Op.COMPARE_GT,
	[TT.LE] = Op.COMPARE_LE,
	[TT.GE] = Op.COMPARE_GE,
	[TT.AND] = Op.BINARY_AND,
	[TT.OR] = Op.BINARY_OR,
}

-- Create compiler state
local function createCompiler()
	return {
		code = {},           -- Bytecode instructions
		loopStack = {},      -- For break/continue
		errors = {},         -- Compilation errors
		currentLine = 1,
	}
end

-- Emit an instruction
local function emit(c, op, arg, line)
	table.insert(c.code, {
		op = op,
		arg = arg,
		line = line or c.currentLine,
	})
	return #c.code  -- Return instruction index
end

-- Get current code position
local function currentPos(c)
	return #c.code
end

-- Patch a jump instruction with the correct offset
local function patchJump(c, instrIndex, target)
	c.code[instrIndex].arg = target
end

-- Forward declarations
local compileExpr
local compileStmt

-- Compile an expression (leaves result on stack)
compileExpr = function(c, node)
	if not node then return end

	c.currentLine = node.line or c.currentLine

	if node.type == NT.NUMBER then
		emit(c, Op.LOAD_CONST, {type = "number", value = node.value}, node.line)

	elseif node.type == NT.STRING then
		emit(c, Op.LOAD_CONST, {type = "string", value = node.value}, node.line)

	elseif node.type == NT.BOOLEAN then
		emit(c, Op.LOAD_CONST, {type = "boolean", value = node.value}, node.line)

	elseif node.type == NT.NONE then
		emit(c, Op.LOAD_CONST, {type = "nil", value = nil}, node.line)

	elseif node.type == NT.IDENTIFIER then
		emit(c, Op.LOAD_VAR, node.name, node.line)

	elseif node.type == NT.BINARY_OP then
		-- Short-circuit evaluation for and/or
		if node.operator == TT.AND then
			compileExpr(c, node.left)
			emit(c, Op.DUP, nil, node.line)
			local jumpIfFalse = emit(c, Op.POP_JUMP_IF_FALSE, 0, node.line)
			emit(c, Op.POP, nil, node.line)
			compileExpr(c, node.right)
			patchJump(c, jumpIfFalse, currentPos(c) + 1)

		elseif node.operator == TT.OR then
			compileExpr(c, node.left)
			emit(c, Op.DUP, nil, node.line)
			local jumpIfTrue = emit(c, Op.POP_JUMP_IF_TRUE, 0, node.line)
			emit(c, Op.POP, nil, node.line)
			compileExpr(c, node.right)
			patchJump(c, jumpIfTrue, currentPos(c) + 1)

		else
			-- Normal binary operation
			compileExpr(c, node.left)
			compileExpr(c, node.right)
			local op = BINARY_OP_MAP[node.operator]
			if not op then
				table.insert(c.errors, "Unknown binary operator at line " .. node.line)
				return
			end
			emit(c, op, nil, node.line)
		end

	elseif node.type == NT.UNARY_OP then
		compileExpr(c, node.operand)
		if node.operator == TT.NOT then
			emit(c, Op.UNARY_NOT, nil, node.line)
		elseif node.operator == TT.MINUS then
			emit(c, Op.UNARY_NEG, nil, node.line)
		else
			table.insert(c.errors, "Unknown unary operator at line " .. node.line)
		end

	elseif node.type == NT.CALL then
		-- Compile callee
		compileExpr(c, node.callee)

		-- Compile arguments
		for _, arg in ipairs(node.args) do
			compileExpr(c, arg)
		end

		emit(c, Op.CALL, #node.args, node.line)

	elseif node.type == NT.INDEX then
		compileExpr(c, node.object)
		compileExpr(c, node.index)
		emit(c, Op.GET_INDEX, nil, node.line)

	elseif node.type == NT.ATTRIBUTE then
		compileExpr(c, node.object)
		emit(c, Op.LOAD_ATTR, node.attribute, node.line)

	elseif node.type == NT.LIST then
		for _, elem in ipairs(node.elements) do
			compileExpr(c, elem)
		end
		emit(c, Op.BUILD_LIST, #node.elements, node.line)

	elseif node.type == NT.TUPLE then
		for _, elem in ipairs(node.elements) do
			compileExpr(c, elem)
		end
		emit(c, Op.BUILD_LIST, #node.elements, node.line)

	else
		table.insert(c.errors, "Unknown expression type: " .. tostring(node.type) .. " at line " .. (node.line or "?"))
	end
end

-- Compile a statement
compileStmt = function(c, node)
	if not node then return end

	c.currentLine = node.line or c.currentLine

	if node.type == NT.EXPR_STMT then
		compileExpr(c, node.expression)
		emit(c, Op.POP, nil, node.line)  -- Discard expression result

	elseif node.type == NT.ASSIGN_STMT then
		compileExpr(c, node.value)

		if node.target.type == NT.IDENTIFIER then
			emit(c, Op.STORE_VAR, node.target.name, node.line)

		elseif node.target.type == NT.INDEX then
			-- Stack: value
			-- Need: list, index, value
			compileExpr(c, node.target.object)  -- Stack: value, list
			compileExpr(c, node.target.index)   -- Stack: value, list, index

			-- Rearrange stack for SET_INDEX (expects: list, index, value)
			-- We'll handle this in the VM by having SET_INDEX expect the right order
			emit(c, Op.SET_INDEX, nil, node.line)

		elseif node.target.type == NT.ATTRIBUTE then
			compileExpr(c, node.target.object)
			emit(c, Op.STORE_ATTR, node.target.attribute, node.line)
		end

	elseif node.type == NT.TUPLE_UNPACK_STMT then
		-- Compile the value (should be a sequence)
		compileExpr(c, node.value)

		-- Unpack into variables (reverse order for stack)
		emit(c, Op.UNPACK_SEQUENCE, #node.targets, node.line)

		-- Store each target (they're on stack in reverse order)
		for i = #node.targets, 1, -1 do
			local target = node.targets[i]
			if target.type == NT.IDENTIFIER then
				emit(c, Op.STORE_VAR, target.name, node.line)
			end
		end

	elseif node.type == NT.AUG_ASSIGN_STMT then
		-- x += y becomes x = x + y
		if node.target.type == NT.IDENTIFIER then
			emit(c, Op.LOAD_VAR, node.target.name, node.line)
			compileExpr(c, node.value)

			-- Determine operation
			local op
			if node.operator == TT.PLUS_ASSIGN then op = Op.BINARY_ADD
			elseif node.operator == TT.MINUS_ASSIGN then op = Op.BINARY_SUB
			elseif node.operator == TT.STAR_ASSIGN then op = Op.BINARY_MUL
			elseif node.operator == TT.SLASH_ASSIGN then op = Op.BINARY_DIV
			end

			if op then
				emit(c, op, nil, node.line)
				emit(c, Op.STORE_VAR, node.target.name, node.line)
			end
		end

	elseif node.type == NT.IF_STMT then
		-- Compile condition
		compileExpr(c, node.condition)

		-- Jump if false to elif/else/end
		local jumpToElse = emit(c, Op.POP_JUMP_IF_FALSE, 0, node.line)

		-- Compile then block
		for _, stmt in ipairs(node.thenBlock) do
			compileStmt(c, stmt)
		end

		-- Jump past else
		local jumpToEnd = emit(c, Op.JUMP, 0, node.line)

		-- Patch the false jump
		patchJump(c, jumpToElse, currentPos(c) + 1)

		-- Compile elif clauses
		local elifEndJumps = {}
		for _, clause in ipairs(node.elseIfClauses or {}) do
			compileExpr(c, clause.condition)
			local jumpToNextElif = emit(c, Op.POP_JUMP_IF_FALSE, 0, clause.condition.line)

			for _, stmt in ipairs(clause.body) do
				compileStmt(c, stmt)
			end

			table.insert(elifEndJumps, emit(c, Op.JUMP, 0, clause.condition.line))
			patchJump(c, jumpToNextElif, currentPos(c) + 1)
		end

		-- Compile else block
		if node.elseBlock then
			for _, stmt in ipairs(node.elseBlock) do
				compileStmt(c, stmt)
			end
		end

		-- Patch all end jumps
		local endPos = currentPos(c) + 1
		patchJump(c, jumpToEnd, endPos)
		for _, jumpIdx in ipairs(elifEndJumps) do
			patchJump(c, jumpIdx, endPos)
		end

	elseif node.type == NT.WHILE_STMT then
		-- Record loop start for continue
		local loopStart = currentPos(c) + 1

		-- Push loop context
		table.insert(c.loopStack, {
			startPos = loopStart,
			breakJumps = {},
		})

		-- Compile condition
		compileExpr(c, node.condition)

		-- Jump past loop if false
		local jumpToEnd = emit(c, Op.POP_JUMP_IF_FALSE, 0, node.line)

		-- Compile body
		for _, stmt in ipairs(node.body) do
			compileStmt(c, stmt)
		end

		-- Yield for time-slicing
		emit(c, Op.YIELD, nil, node.line)

		-- Jump back to condition
		emit(c, Op.JUMP, loopStart, node.line)

		-- Patch end jump
		patchJump(c, jumpToEnd, currentPos(c) + 1)

		-- Patch all break jumps
		local loopCtx = table.remove(c.loopStack)
		for _, jumpIdx in ipairs(loopCtx.breakJumps) do
			patchJump(c, jumpIdx, currentPos(c) + 1)
		end

	elseif node.type == NT.FOR_STMT then
		-- Compile iterable
		compileExpr(c, node.iterable)

		-- Convert to iterator (sets up iteration state)
		emit(c, Op.GET_ITER, nil, node.line)

		-- Loop start
		local loopStart = currentPos(c) + 1

		-- Push loop context
		table.insert(c.loopStack, {
			startPos = loopStart,
			breakJumps = {},
		})

		-- Get next item or jump to end
		local forIterJump = emit(c, Op.FOR_ITER, 0, node.line)

		-- Store in loop variable
		emit(c, Op.STORE_VAR, node.variable, node.line)

		-- Compile body
		for _, stmt in ipairs(node.body) do
			compileStmt(c, stmt)
		end

		-- Yield for time-slicing
		emit(c, Op.YIELD, nil, node.line)

		-- Jump back to FOR_ITER
		emit(c, Op.JUMP, loopStart, node.line)

		-- Patch FOR_ITER to jump here when exhausted
		patchJump(c, forIterJump, currentPos(c) + 1)

		-- Pop iterator from stack
		emit(c, Op.POP, nil, node.line)

		-- Patch all break jumps
		local loopCtx = table.remove(c.loopStack)
		for _, jumpIdx in ipairs(loopCtx.breakJumps) do
			patchJump(c, jumpIdx, currentPos(c) + 1)
		end

	elseif node.type == NT.FUNCTION_DEF then
		-- Compile function body into separate code object
		local funcCompiler = createCompiler()
		funcCompiler.currentLine = node.line

		-- Compile function body
		for _, stmt in ipairs(node.body) do
			compileStmt(funcCompiler, stmt)
		end

		-- Ensure function returns
		emit(funcCompiler, Op.LOAD_CONST, {type = "nil", value = nil}, node.line)
		emit(funcCompiler, Op.RETURN, nil, node.line)

		-- Create function object
		local funcObj = {
			name = node.name,
			params = node.params,
			code = funcCompiler.code,
			line = node.line,
		}

		-- Emit instruction to create function and store it
		emit(c, Op.MAKE_FUNCTION, funcObj, node.line)
		emit(c, Op.STORE_VAR, node.name, node.line)

	elseif node.type == NT.RETURN_STMT then
		if node.value then
			compileExpr(c, node.value)
		else
			emit(c, Op.LOAD_CONST, {type = "nil", value = nil}, node.line)
		end
		emit(c, Op.RETURN, nil, node.line)

	elseif node.type == NT.BREAK_STMT then
		if #c.loopStack == 0 then
			table.insert(c.errors, "'break' outside loop at line " .. node.line)
			return
		end
		local jumpIdx = emit(c, Op.JUMP, 0, node.line)
		table.insert(c.loopStack[#c.loopStack].breakJumps, jumpIdx)

	elseif node.type == NT.CONTINUE_STMT then
		if #c.loopStack == 0 then
			table.insert(c.errors, "'continue' outside loop at line " .. node.line)
			return
		end
		emit(c, Op.JUMP, c.loopStack[#c.loopStack].startPos, node.line)

	elseif node.type == NT.PASS_STMT then
		-- No-op, but emit for line tracking
		-- Actually don't need to emit anything

	else
		table.insert(c.errors, "Unknown statement type: " .. tostring(node.type) .. " at line " .. (node.line or "?"))
	end
end

-- Main compile function
function Compiler.compile(source)
	-- Parse source
	local success, ast = pcall(function()
		return Parser.parse(source)
	end)

	if not success then
		return nil, {ast}  -- ast is the error message
	end

	-- Create compiler
	local c = createCompiler()

	-- Compile program
	if ast.type == NT.PROGRAM then
		for _, stmt in ipairs(ast.statements) do
			compileStmt(c, stmt)
		end
	else
		table.insert(c.errors, "Expected PROGRAM node")
	end

	-- Add HALT at end
	emit(c, Op.HALT, nil, c.currentLine)

	-- Check for errors
	if #c.errors > 0 then
		return nil, c.errors
	end

	-- Return compiled code
	return {
		code = c.code,
		source = source,
	}
end

-- Format bytecode for display
function Compiler.formatBytecode(compiled)
	if not compiled or not compiled.code then
		return "No bytecode"
	end

	local lines = {}
	for i, instr in ipairs(compiled.code) do
		local argStr = ""
		if instr.arg ~= nil then
			if type(instr.arg) == "table" then
				if instr.arg.type then
					-- Constant
					if instr.arg.value == nil then
						argStr = "None"
					elseif type(instr.arg.value) == "string" then
						argStr = '"' .. instr.arg.value .. '"'
					else
						argStr = tostring(instr.arg.value)
					end
				elseif instr.arg.name then
					-- Function
					argStr = "<func " .. instr.arg.name .. ">"
				end
			else
				argStr = tostring(instr.arg)
			end
		end

		local lineNum = string.format("%3d", i)
		local opName = string.format("%-20s", instr.op)
		table.insert(lines, lineNum .. "  " .. opName .. " " .. argStr)
	end

	return table.concat(lines, "\n")
end

-- Get source line mapping
function Compiler.getLineMapping(compiled)
	if not compiled or not compiled.code then
		return {}
	end

	local mapping = {}
	for i, instr in ipairs(compiled.code) do
		mapping[i] = instr.line
	end
	return mapping
end

return Compiler
