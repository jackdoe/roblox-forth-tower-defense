-- Python module
-- Exposes the Python bytecode compiler and VM

local Lexer = require(script.Lexer)
local Parser = require(script.Parser)
local Compiler = require(script.Compiler)
local VM = require(script.VM)
local Runtime = require(script.Runtime)
local GameAPI = require(script.GameAPI)

return {
	Lexer = Lexer,
	Parser = Parser,
	Compiler = Compiler,
	VM = VM,
	Runtime = Runtime,
	GameAPI = GameAPI,

	-- Create a new runtime
	createRuntime = Runtime.new,

	-- Tokenize source (for syntax highlighting)
	tokenize = Lexer.tokenize,

	-- Parse source to AST
	parse = Parser.parse,

	-- Compile to bytecode
	compile = Compiler.compile,

	-- Bytecode opcodes (for reference)
	Op = Compiler.Op,

	-- Create game environments
	createGolemEnvironment = GameAPI.createGolemEnvironment,
	createBotEnvironment = GameAPI.createBotEnvironment,
	createPlayerEnvironment = GameAPI.createPlayerEnvironment,
}
