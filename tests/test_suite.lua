-- ============================================
-- TEST SUITE: Validation & Quality Assurance
-- ============================================
-- Comprehensive tests for all components

local Lexer = require(script.Parent.parser.lexer)
local Parser = require(script.Parent.parser.parser)
local BytecodeCompiler = require(script.Parent.vm.bytecode_compiler)
local Obfuscator = require(script.Parent.main)

local Tests = {}
Tests.passed = 0
Tests.failed = 0
Tests.total = 0

function Tests:assert_equals(actual, expected, message)
    self.total = self.total + 1
    if actual == expected then
        self.passed = self.passed + 1
        print("✓ PASS: " .. (message or "Test passed"))
    else
        self.failed = self.failed + 1
        print("✗ FAIL: " .. (message or "Test failed"))
        print("  Expected: " .. tostring(expected))
        print("  Got: " .. tostring(actual))
    end
end

function Tests:assert_true(value, message)
    self:assert_equals(value, true, message)
end

function Tests:assert_not_nil(value, message)
    self.total = self.total + 1
    if value ~= nil then
        self.passed = self.passed + 1
        print("✓ PASS: " .. (message or "Value is not nil"))
    else
        self.failed = self.failed + 1
        print("✗ FAIL: " .. (message or "Value is nil"))
    end
end

function Tests:test_lexer_basic()
    print("\n=== LEXER TESTS ===")
    
    local source = "local x = 10"
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    
    self:assert_not_nil(tokens, "Lexer produces tokens")
    self:assert_equals(#tokens > 0, true, "Tokens are generated")
    self:assert_equals(tokens[1].type, Lexer.TokenType.LOCAL, "LOCAL keyword recognized")
end

function Tests:test_lexer_strings()
    print("\n=== LEXER STRING TESTS ===")
    
    local source = 'local s = "hello world"'
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    
    local string_token = nil
    for _, token in ipairs(tokens) do
        if token.type == Lexer.TokenType.STRING then
            string_token = token
            break
        end
    end
    
    self:assert_not_nil(string_token, "String token found")
    self:assert_equals(string_token.value, "hello world", "String value extracted correctly")
end

function Tests:test_lexer_numbers()
    print("\n=== LEXER NUMBER TESTS ===")
    
    local source = "local a = 42; local b = 3.14; local c = 0xFF"
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    
    local numbers = {}
    for _, token in ipairs(tokens) do
        if token.type == Lexer.TokenType.NUMBER then
            table.insert(numbers, token.value)
        end
    end
    
    self:assert_equals(#numbers, 3, "Three numbers found")
    self:assert_equals(numbers[1], 42, "Integer parsed correctly")
    self:assert_equals(numbers[2], 3.14, "Float parsed correctly")
    self:assert_equals(numbers[3], 255, "Hex number parsed correctly")
end

function Tests:test_parser_basic()
    print("\n=== PARSER TESTS ===")
    
    local source = "local x = 10"
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    local parser = Parser.new(tokens)
    local ast = parser:parse()
    
    self:assert_not_nil(ast, "AST generated")
    self:assert_equals(ast.type, "Block", "Root is Block node")
    self:assert_equals(#ast.statements, 1, "One statement in block")
end

function Tests:test_parser_expression()
    print("\n=== PARSER EXPRESSION TESTS ===")
    
    local source = "local result = 10 + 20"
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    local parser = Parser.new(tokens)
    local ast = parser:parse()
    
    local local_decl = ast.statements[1]
    self:assert_equals(local_decl.type, "LocalDeclaration", "Local declaration parsed")
    self:assert_equals(#local_decl.values, 1, "One value assigned")
    self:assert_equals(local_decl.values[1].type, "BinaryOp", "Binary operation parsed")
end

function Tests:test_parser_if_statement()
    print("\n=== PARSER IF STATEMENT TESTS ===")
    
    local source = [[if x > 5 then
        print("x is big")
    else
        print("x is small")
    end]]
    
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    local parser = Parser.new(tokens)
    local ast = parser:parse()
    
    local if_stmt = ast.statements[1]
    self:assert_equals(if_stmt.type, "IfStatement", "If statement parsed")
    self:assert_not_nil(if_stmt.then_block, "Then block exists")
    self:assert_not_nil(if_stmt.else_block, "Else block exists")
end

function Tests:test_parser_function()
    print("\n=== PARSER FUNCTION TESTS ===")
    
    local source = [[function add(a, b)
        return a + b
    end]]
    
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    local parser = Parser.new(tokens)
    local ast = parser:parse()
    
    local func = ast.statements[1]
    self:assert_equals(func.type, "FunctionDeclaration", "Function declaration parsed")
    self:assert_equals(func.name, "add", "Function name correct")
    self:assert_equals(#func.params, 2, "Two parameters")
end

function Tests:test_bytecode_compiler()
    print("\n=== BYTECODE COMPILER TESTS ===")
    
    local source = "local x = 42"
    local lexer = Lexer.new(source)
    local tokens = lexer:tokenize()
    local parser = Parser.new(tokens)
    local ast = parser:parse()
    
    local compiler = BytecodeCompiler.new()
    local bytecode = compiler:compile(ast)
    
    self:assert_not_nil(bytecode, "Bytecode generated")
    self:assert_true(#bytecode > 0, "Bytecode is not empty")
end

function Tests:test_obfuscator_simple()
    print("\n=== OBFUSCATOR TESTS ===")
    
    local source = "local x = 10; print(x)"
    local obfuscated = Obfuscator.obfuscate(source, {
        obfuscation_level = "high",
        vm_enabled = true,
        seed = 12345,
    })
    
    self:assert_not_nil(obfuscated, "Obfuscated code generated")
    self:assert_true(#obfuscated > 0, "Obfuscated code is not empty")
    self:assert_true(obfuscated:find("_VM") ~= nil, "VM wrapper present")
end

function Tests:run_all()
    print("\n" .. string.rep("=", 50))
    print("RUNNING TEST SUITE")
    print(string.rep("=", 50))
    
    self:test_lexer_basic()
    self:test_lexer_strings()
    self:test_lexer_numbers()
    self:test_parser_basic()
    self:test_parser_expression()
    self:test_parser_if_statement()
    self:test_parser_function()
    self:test_bytecode_compiler()
    self:test_obfuscator_simple()
    
    print("\n" .. string.rep("=", 50))
    print("TEST RESULTS")
    print(string.rep("=", 50))
    print("Total:  " .. self.total)
    print("Passed: " .. self.passed .. " ✓")
    print("Failed: " .. self.failed .. " ✗")
    print("Success Rate: " .. string.format("%.1f%%", (self.passed / self.total) * 100))
    print(string.rep("=", 50) .. "\n")
end

return Tests