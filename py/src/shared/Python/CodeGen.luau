-- CodeGen.luau
-- Generates Lua code from Python AST
-- Handles Python->Lua semantic differences

local Parser = require(script.Parent.Parser)
local Lexer = require(script.Parent.Lexer)
local NT = Parser.NodeType
local TT = Lexer.TokenType

local CodeGen = {}

-- Operator mappings from Python to Lua
local BINARY_OPS = {
	[TT.PLUS] = "+",
	[TT.MINUS] = "-",
	[TT.STAR] = "*",
	[TT.SLASH] = "/",
	[TT.FLOOR_DIV] = "//",  -- Lua 5.3+ has this, Luau uses math.floor
	[TT.PERCENT] = "%",
	[TT.POWER] = "^",
	[TT.EQ] = "==",
	[TT.NE] = "~=",  -- Python != -> Lua ~=
	[TT.LT] = "<",
	[TT.GT] = ">",
	[TT.LE] = "<=",
	[TT.GE] = ">=",
	[TT.AND] = "and",
	[TT.OR] = "or",
}

local UNARY_OPS = {
	[TT.NOT] = "not ",
	[TT.MINUS] = "-",
}

local AUG_ASSIGN_OPS = {
	[TT.PLUS_ASSIGN] = "+",
	[TT.MINUS_ASSIGN] = "-",
	[TT.STAR_ASSIGN] = "*",
	[TT.SLASH_ASSIGN] = "/",
}

-- Create code generator state
local function createCodeGen()
	return {
		indent = 0,
		output = {},
		loopDepth = 0,  -- Track if we're inside a loop (for break/continue)
	}
end

-- Helper to add indentation
local function getIndent(cg)
	return string.rep("\t", cg.indent)
end

-- Helper to emit a line
local function emit(cg, line)
	table.insert(cg.output, getIndent(cg) .. line)
end

-- Helper to emit without indentation
local function emitRaw(cg, line)
	table.insert(cg.output, line)
end

-- Forward declaration
local generateExpr
local generateStmt

-- Generate expression code
generateExpr = function(cg, node)
	if node.type == NT.NUMBER then
		return tostring(node.value)

	elseif node.type == NT.STRING then
		-- Escape string for Lua
		local escaped = node.value:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\t", "\\t")
		return "\"" .. escaped .. "\""

	elseif node.type == NT.BOOLEAN then
		return node.value and "true" or "false"

	elseif node.type == NT.NONE then
		return "nil"

	elseif node.type == NT.IDENTIFIER then
		return node.name

	elseif node.type == NT.BINARY_OP then
		local left = generateExpr(cg, node.left)
		local right = generateExpr(cg, node.right)
		local op = BINARY_OPS[node.operator]

		if not op then
			error("Unknown binary operator: " .. tostring(node.operator))
		end

		-- Special handling for floor division in Luau
		if node.operator == TT.FLOOR_DIV then
			return "math.floor(" .. left .. " / " .. right .. ")"
		end

		return "(" .. left .. " " .. op .. " " .. right .. ")"

	elseif node.type == NT.UNARY_OP then
		local operand = generateExpr(cg, node.operand)
		local op = UNARY_OPS[node.operator]

		if not op then
			error("Unknown unary operator: " .. tostring(node.operator))
		end

		return "(" .. op .. operand .. ")"

	elseif node.type == NT.CALL then
		local callee = generateExpr(cg, node.callee)
		local args = {}

		for _, arg in ipairs(node.args) do
			table.insert(args, generateExpr(cg, arg))
		end

		-- Special handling for built-in functions
		if node.callee.type == NT.IDENTIFIER then
			local name = node.callee.name

			-- range(n) -> creates iterator (handled in for loop)
			if name == "range" then
				-- Just pass through, for loop handles it
				return "_py_range(" .. table.concat(args, ", ") .. ")"

			-- len(x) -> #x
			elseif name == "len" then
				if #args ~= 1 then
					error("len() takes exactly 1 argument")
				end
				return "#" .. args[1]

			-- print() -> print()
			elseif name == "print" then
				return "print(" .. table.concat(args, ", ") .. ")"

			-- str(x) -> tostring(x)
			elseif name == "str" then
				if #args ~= 1 then
					error("str() takes exactly 1 argument")
				end
				return "tostring(" .. args[1] .. ")"

			-- int(x) -> math.floor(tonumber(x))
			elseif name == "int" then
				if #args ~= 1 then
					error("int() takes exactly 1 argument")
				end
				return "math.floor(tonumber(" .. args[1] .. ") or 0)"

			-- float(x) -> tonumber(x)
			elseif name == "float" then
				if #args ~= 1 then
					error("float() takes exactly 1 argument")
				end
				return "(tonumber(" .. args[1] .. ") or 0)"

			-- abs(x) -> math.abs(x)
			elseif name == "abs" then
				if #args ~= 1 then
					error("abs() takes exactly 1 argument")
				end
				return "math.abs(" .. args[1] .. ")"

			-- min/max
			elseif name == "min" then
				return "math.min(" .. table.concat(args, ", ") .. ")"
			elseif name == "max" then
				return "math.max(" .. table.concat(args, ", ") .. ")"
			end
		end

		-- Method calls on lists
		if node.callee.type == NT.ATTRIBUTE then
			local obj = generateExpr(cg, node.callee.object)
			local method = node.callee.attribute

			if method == "append" then
				if #args ~= 1 then
					error("append() takes exactly 1 argument")
				end
				return "table.insert(" .. obj .. ", " .. args[1] .. ")"

			elseif method == "pop" then
				if #args == 0 then
					return "table.remove(" .. obj .. ")"
				else
					-- Python uses 0-indexed, convert to 1-indexed
					return "table.remove(" .. obj .. ", " .. args[1] .. " + 1)"
				end

			elseif method == "insert" then
				if #args ~= 2 then
					error("insert() takes exactly 2 arguments")
				end
				-- Convert 0-indexed to 1-indexed
				return "table.insert(" .. obj .. ", " .. args[1] .. " + 1, " .. args[2] .. ")"
			end
		end

		return callee .. "(" .. table.concat(args, ", ") .. ")"

	elseif node.type == NT.INDEX then
		local obj = generateExpr(cg, node.object)
		local index = generateExpr(cg, node.index)
		-- Python is 0-indexed, Lua is 1-indexed
		return obj .. "[" .. index .. " + 1]"

	elseif node.type == NT.ATTRIBUTE then
		local obj = generateExpr(cg, node.object)
		return obj .. "." .. node.attribute

	elseif node.type == NT.LIST then
		local elements = {}
		for _, elem in ipairs(node.elements) do
			table.insert(elements, generateExpr(cg, elem))
		end
		return "{" .. table.concat(elements, ", ") .. "}"

	else
		error("Unknown expression type: " .. tostring(node.type))
	end
end

-- Generate statement code
generateStmt = function(cg, node)
	if node.type == NT.EXPR_STMT then
		emit(cg, generateExpr(cg, node.expression))

	elseif node.type == NT.ASSIGN_STMT then
		local target = generateExpr(cg, node.target)
		local value = generateExpr(cg, node.value)

		-- Check if it's an index assignment (needs special handling for 0->1 index)
		if node.target.type == NT.INDEX then
			local obj = generateExpr(cg, node.target.object)
			local index = generateExpr(cg, node.target.index)
			emit(cg, obj .. "[" .. index .. " + 1] = " .. value)
		else
			emit(cg, target .. " = " .. value)
		end

	elseif node.type == NT.AUG_ASSIGN_STMT then
		local target = generateExpr(cg, node.target)
		local value = generateExpr(cg, node.value)
		local op = AUG_ASSIGN_OPS[node.operator]

		if not op then
			error("Unknown augmented assignment operator: " .. tostring(node.operator))
		end

		emit(cg, target .. " = " .. target .. " " .. op .. " " .. value)

	elseif node.type == NT.IF_STMT then
		emit(cg, "if " .. generateExpr(cg, node.condition) .. " then")
		cg.indent = cg.indent + 1
		for _, stmt in ipairs(node.thenBlock) do
			generateStmt(cg, stmt)
		end
		cg.indent = cg.indent - 1

		for _, clause in ipairs(node.elseIfClauses) do
			emit(cg, "elseif " .. generateExpr(cg, clause.condition) .. " then")
			cg.indent = cg.indent + 1
			for _, stmt in ipairs(clause.body) do
				generateStmt(cg, stmt)
			end
			cg.indent = cg.indent - 1
		end

		if node.elseBlock then
			emit(cg, "else")
			cg.indent = cg.indent + 1
			for _, stmt in ipairs(node.elseBlock) do
				generateStmt(cg, stmt)
			end
			cg.indent = cg.indent - 1
		end

		emit(cg, "end")

	elseif node.type == NT.WHILE_STMT then
		cg.loopDepth = cg.loopDepth + 1
		emit(cg, "while " .. generateExpr(cg, node.condition) .. " do")
		cg.indent = cg.indent + 1
		for _, stmt in ipairs(node.body) do
			generateStmt(cg, stmt)
		end
		cg.indent = cg.indent - 1
		emit(cg, "end")
		cg.loopDepth = cg.loopDepth - 1

	elseif node.type == NT.FOR_STMT then
		cg.loopDepth = cg.loopDepth + 1

		-- Check if it's a range() call
		if node.iterable.type == NT.CALL and
		   node.iterable.callee.type == NT.IDENTIFIER and
		   node.iterable.callee.name == "range" then

			local args = node.iterable.args
			local startVal, endVal, stepVal

			if #args == 1 then
				startVal = "0"
				endVal = generateExpr(cg, args[1]) .. " - 1"
				stepVal = "1"
			elseif #args == 2 then
				startVal = generateExpr(cg, args[1])
				endVal = generateExpr(cg, args[2]) .. " - 1"
				stepVal = "1"
			elseif #args == 3 then
				startVal = generateExpr(cg, args[1])
				endVal = generateExpr(cg, args[2]) .. " - 1"
				stepVal = generateExpr(cg, args[3])
			else
				error("range() takes 1 to 3 arguments")
			end

			emit(cg, "for " .. node.variable .. " = " .. startVal .. ", " .. endVal .. ", " .. stepVal .. " do")
		else
			-- Generic iteration (ipairs)
			emit(cg, "for _, " .. node.variable .. " in ipairs(" .. generateExpr(cg, node.iterable) .. ") do")
		end

		cg.indent = cg.indent + 1
		for _, stmt in ipairs(node.body) do
			generateStmt(cg, stmt)
		end
		cg.indent = cg.indent - 1
		emit(cg, "end")
		cg.loopDepth = cg.loopDepth - 1

	elseif node.type == NT.FUNCTION_DEF then
		local params = table.concat(node.params, ", ")
		emit(cg, "local function " .. node.name .. "(" .. params .. ")")
		cg.indent = cg.indent + 1
		for _, stmt in ipairs(node.body) do
			generateStmt(cg, stmt)
		end
		cg.indent = cg.indent - 1
		emit(cg, "end")

	elseif node.type == NT.RETURN_STMT then
		if node.value then
			emit(cg, "return " .. generateExpr(cg, node.value))
		else
			emit(cg, "return")
		end

	elseif node.type == NT.BREAK_STMT then
		if cg.loopDepth == 0 then
			error("'break' outside loop")
		end
		emit(cg, "break")

	elseif node.type == NT.CONTINUE_STMT then
		if cg.loopDepth == 0 then
			error("'continue' outside loop")
		end
		emit(cg, "continue")

	elseif node.type == NT.PASS_STMT then
		-- Lua doesn't need pass, but emit a comment for clarity
		emit(cg, "-- pass")

	else
		error("Unknown statement type: " .. tostring(node.type))
	end
end

-- Generate Lua code from AST
function CodeGen.generate(ast)
	local cg = createCodeGen()

	if ast.type ~= NT.PROGRAM then
		error("Expected PROGRAM node")
	end

	for _, stmt in ipairs(ast.statements) do
		generateStmt(cg, stmt)
	end

	return table.concat(cg.output, "\n")
end

-- Compile Python source to Lua code
function CodeGen.compile(source)
	local ast = Parser.parse(source)
	return CodeGen.generate(ast)
end

-- Compile with runtime wrapper (for game execution)
function CodeGen.compileWithRuntime(source, runtimeEnv)
	local luaCode = CodeGen.compile(source)

	-- Wrap in a function that receives the game environment
	local wrapped = [[
return function(_env)
	-- Import game functions into local scope
	-- Golem functions
	local scan = _env.scan
	local nearest = _env.nearest
	local weakest = _env.weakest
	local strongest = _env.strongest
	local target = _env.target
	local fire = _env.fire
	local ammo = _env.ammo
	local set_range = _env.set_range
	local get_range = _env.get_range

	-- Bot logistics functions
	local scrap = _env.scrap
	local has_scrap = _env.has_scrap
	local my_scrap = _env.my_scrap
	local capacity = _env.capacity
	local bag_full = _env.bag_full
	local move = _env.move
	local move_to_scrap = _env.move_to_scrap
	local collect = _env.collect
	local golem = _env.golem
	local move_to_golem = _env.move_to_golem
	local supply = _env.supply

	-- Player movement functions
	local teleport = _env.teleport
	local teleport_to_golem = _env.teleport_to_golem
	local forward = _env.forward
	local left = _env.left
	local right = _env.right
	local hit = _env.hit

	-- Ammo type constants
	local BULLET = _env.BULLET or 1
	local ROCKET = _env.ROCKET or 2
	local LASER = _env.LASER or 3
	local ICE = _env.ICE or 4
	local FREEZE = _env.FREEZE or 5

	-- Built-in functions
	local wait = _env.wait
	local print = _env.print or print

	-- Python True/False for compatibility
	local True = true
	local False = false
	local None = nil

	-- User code begins here
]] .. luaCode .. [[

end
]]
	return wrapped
end

return CodeGen
