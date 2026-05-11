-- ============================================
-- BYTECODE COMPILER: AST to Bytecode
-- ============================================
-- Converts Abstract Syntax Tree to VM bytecode

local BytecodeCompiler = {}
BytecodeCompiler.__index = BytecodeCompiler

local ASTNode = require(script.Parent.Parent.parser.ast_nodes)

function BytecodeCompiler.new()
    local self = setmetatable({}, BytecodeCompiler)
    
    self.bytecode = {}
    self.constants = {}
    self.constant_map = {}      -- For deduplication
    self.variables = {}         -- Variable name to index mapping
    self.var_counter = 0
    self.scope_stack = {}       -- Scope management
    self.label_map = {}         -- Labels for jumps
    self.label_counter = 0
    
    return self
end

-- ============ BYTECODE EMISSION ============

function BytecodeCompiler:emit_byte(byte_val)
    table.insert(self.bytecode, byte_val)
end

function BytecodeCompiler:emit_bytes(...)
    for _, byte_val in ipairs({...}) do
        self:emit_byte(byte_val)
    end
end

function BytecodeCompiler:emit_int32(value)
    self:emit_byte(value % 256)
    self:emit_byte(math.floor(value / 256) % 256)
    self:emit_byte(math.floor(value / 65536) % 256)
    self:emit_byte(math.floor(value / 16777216) % 256)
end

function BytecodeCompiler:emit_int16(value)
    self:emit_byte(value % 256)
    self:emit_byte(math.floor(value / 256) % 256)
end

function BytecodeCompiler:get_position()
    return #self.bytecode + 1
end

function BytecodeCompiler:patch_jump(position, target)
    local offset = target - position - 2
    self.bytecode[position] = offset % 256
    self.bytecode[position + 1] = math.floor(offset / 256) % 256
end

-- ============ CONSTANT POOL ============

function BytecodeCompiler:add_constant(value)
    local key = tostring(value) .. ":" .. type(value)
    
    if self.constant_map[key] then
        return self.constant_map[key]
    end
    
    local index = #self.constants + 1
    table.insert(self.constants, value)
    self.constant_map[key] = index
    return index
end

function BytecodeCompiler:get_constants()
    return self.constants
end

-- ============ VARIABLE MANAGEMENT ============

function BytecodeCompiler:register_variable(name)
    if not self.variables[name] then
        self.var_counter = self.var_counter + 1
        self.variables[name] = self.var_counter
    end
    return self.variables[name]
end

function BytecodeCompiler:get_variable(name)
    return self.variables[name] or error("Undefined variable: " .. name)
end

-- ============ LABEL MANAGEMENT ============

function BytecodeCompiler:create_label()
    self.label_counter = self.label_counter + 1
    return self.label_counter
end

function BytecodeCompiler:emit_label(label_id)
    self.label_map[label_id] = self:get_position()
end

-- ============ INSTRUCTION EMISSION ============

function BytecodeCompiler:emit_load_const(const_idx)
    self:emit_bytes(0x01, const_idx % 256, math.floor(const_idx / 256))
end

function BytecodeCompiler:emit_load_var(var_idx)
    self:emit_bytes(0x02, var_idx % 256, math.floor(var_idx / 256))
end

function BytecodeCompiler:emit_store_var(var_idx)
    self:emit_bytes(0x03, var_idx % 256, math.floor(var_idx / 256))
end

function BytecodeCompiler:emit_load_global(name_idx)
    self:emit_bytes(0x04, name_idx % 256, math.floor(name_idx / 256))
end

function BytecodeCompiler:emit_store_global(name_idx)
    self:emit_bytes(0x05, name_idx % 256, math.floor(name_idx / 256))
end

function BytecodeCompiler:emit_add()
    self:emit_byte(0x10)
end

function BytecodeCompiler:emit_sub()
    self:emit_byte(0x11)
end

function BytecodeCompiler:emit_mul()
    self:emit_byte(0x12)
end

function BytecodeCompiler:emit_div()
    self:emit_byte(0x13)
end

function BytecodeCompiler:emit_mod()
    self:emit_byte(0x14)
end

function BytecodeCompiler:emit_pow()
    self:emit_byte(0x15)
end

function BytecodeCompiler:emit_eq()
    self:emit_byte(0x20)
end

function BytecodeCompiler:emit_neq()
    self:emit_byte(0x21)
end

function BytecodeCompiler:emit_lt()
    self:emit_byte(0x22)
end

function BytecodeCompiler:emit_gt()
    self:emit_byte(0x23)
end

function BytecodeCompiler:emit_lte()
    self:emit_byte(0x24)
end

function BytecodeCompiler:emit_gte()
    self:emit_byte(0x25)
end

function BytecodeCompiler:emit_and()
    self:emit_byte(0x30)
end

function BytecodeCompiler:emit_or()
    self:emit_byte(0x31)
end

function BytecodeCompiler:emit_not()
    self:emit_byte(0x32)
end

function BytecodeCompiler:emit_jmp(target_pc)
    self:emit_bytes(0x40)
    self:emit_int16(target_pc)
end

function BytecodeCompiler:emit_jmp_if_true(target_pc)
    self:emit_bytes(0x41)
    self:emit_int16(target_pc)
end

function BytecodeCompiler:emit_jmp_if_false(target_pc)
    self:emit_bytes(0x42)
    self:emit_int16(target_pc)
end

function BytecodeCompiler:emit_call(arg_count)
    self:emit_bytes(0x50, arg_count)
end

function BytecodeCompiler:emit_return()
    self:emit_byte(0x51)
end

function BytecodeCompiler:emit_make_table()
    self:emit_byte(0x60)
end

function BytecodeCompiler:emit_table_set()
    self:emit_byte(0x61)
end

function BytecodeCompiler:emit_table_get()
    self:emit_byte(0x62)
end

function BytecodeCompiler:emit_concat()
    self:emit_byte(0x70)
end

function BytecodeCompiler:emit_strlen()
    self:emit_byte(0x71)
end

function BytecodeCompiler:emit_nop()
    self:emit_byte(0xFF)
end

-- ============ AST COMPILATION ============

function BytecodeCompiler:compile(ast)
    self:compile_block(ast)
    self:emit_byte(0xFF) -- END marker
    return table.concat(self.bytecode:map(function(b) return string.char(b) end))
end

function BytecodeCompiler:compile_block(block_node)
    for _, stmt in ipairs(block_node.statements) do
        self:compile_statement(stmt)
    end
end

function BytecodeCompiler:compile_statement(stmt)
    if stmt.type == "LocalDeclaration" then
        self:compile_local_declaration(stmt)
    
    elseif stmt.type == "Assignment" then
        self:compile_assignment(stmt)
    
    elseif stmt.type == "FunctionDeclaration" then
        self:compile_function_declaration(stmt)
    
    elseif stmt.type == "IfStatement" then
        self:compile_if_statement(stmt)
    
    elseif stmt.type == "ForLoop" then
        self:compile_for_loop(stmt)
    
    elseif stmt.type == "WhileLoop" then
        self:compile_while_loop(stmt)
    
    elseif stmt.type == "RepeatLoop" then
        self:compile_repeat_loop(stmt)
    
    elseif stmt.type == "ReturnStatement" then
        self:compile_return_statement(stmt)
    
    elseif stmt.type == "BreakStatement" then
        self:compile_break_statement(stmt)
    
    elseif stmt.type == "ExpressionStatement" then
        self:compile_expression(stmt.expression)
        self:emit_byte(0xFF) -- Pop result
    end
end

function BytecodeCompiler:compile_local_declaration(node)
    for i, name in ipairs(node.names) do
        self:register_variable(name)
        
        if node.values[i] then
            self:compile_expression(node.values[i])
            self:emit_store_var(self:get_variable(name))
        else
            self:emit_load_const(self:add_constant(nil))
            self:emit_store_var(self:get_variable(name))
        end
    end
end

function BytecodeCompiler:compile_assignment(node)
    for i, value in ipairs(node.values) do
        self:compile_expression(value)
    end
    
    for i = #node.targets, 1, -1 do
        local target = node.targets[i]
        if target.type == "Identifier" then
            local var_idx = self:get_variable(target.name)
            self:emit_store_var(var_idx)
        end
    end
end

function BytecodeCompiler:compile_function_declaration(node)
    -- TODO: Implement function compilation
end

function BytecodeCompiler:compile_if_statement(node)
    self:compile_expression(node.condition)
    local false_label = self:create_label()
    self:emit_jmp_if_false(false_label)
    
    self:compile_block(node.then_block)
    
    if node.else_block then
        local end_label = self:create_label()
        self:emit_jmp(end_label)
        self:emit_label(false_label)
        self:compile_block(node.else_block)
        self:emit_label(end_label)
    else
        self:emit_label(false_label)
    end
end

function BytecodeCompiler:compile_for_loop(node)
    -- TODO: Implement for loop compilation
end

function BytecodeCompiler:compile_while_loop(node)
    -- TODO: Implement while loop compilation
end

function BytecodeCompiler:compile_repeat_loop(node)
    -- TODO: Implement repeat loop compilation
end

function BytecodeCompiler:compile_return_statement(node)
    for _, value in ipairs(node.values) do
        self:compile_expression(value)
    end
    self:emit_return()
end

function BytecodeCompiler:compile_break_statement(node)
    -- TODO: Implement break
end

function BytecodeCompiler:compile_expression(expr)
    if expr.type == "NumberLiteral" then
        self:emit_load_const(self:add_constant(expr.value))
    
    elseif expr.type == "StringLiteral" then
        self:emit_load_const(self:add_constant(expr.value))
    
    elseif expr.type == "BooleanLiteral" then
        self:emit_load_const(self:add_constant(expr.value))
    
    elseif expr.type == "NilLiteral" then
        self:emit_load_const(self:add_constant(nil))
    
    elseif expr.type == "Identifier" then
        if self.variables[expr.name] then
            self:emit_load_var(self.variables[expr.name])
        else
            self:emit_load_global(self:add_constant(expr.name))
        end
    
    elseif expr.type == "BinaryOp" then
        self:compile_expression(expr.left)
        self:compile_expression(expr.right)
        
        if expr.operator == "+" then
            self:emit_add()
        elseif expr.operator == "-" then
            self:emit_sub()
        elseif expr.operator == "*" then
            self:emit_mul()
        elseif expr.operator == "/" then
            self:emit_div()
        elseif expr.operator == "%" then
            self:emit_mod()
        elseif expr.operator == "^" then
            self:emit_pow()
        elseif expr.operator == "==" then
            self:emit_eq()
        elseif expr.operator == "~=" then
            self:emit_neq()
        elseif expr.operator == "<" then
            self:emit_lt()
        elseif expr.operator == ">" then
            self:emit_gt()
        elseif expr.operator == "<=" then
            self:emit_lte()
        elseif expr.operator == ">=" then
            self:emit_gte()
        elseif expr.operator == "and" then
            self:emit_and()
        elseif expr.operator == "or" then
            self:emit_or()
        elseif expr.operator == ".." then
            self:emit_concat()
        end
    
    elseif expr.type == "UnaryOp" then
        self:compile_expression(expr.operand)
        
        if expr.operator == "not" then
            self:emit_not()
        elseif expr.operator == "-" then
            self:emit_load_const(self:add_constant(0))
            self:emit_sub()
        elseif expr.operator == "#" then
            self:emit_strlen()
        end
    
    elseif expr.type == "TableConstructor" then
        self:emit_make_table()
        for _, field in ipairs(expr.fields) do
            if field.type == "TableFieldKeyValue" then
                self:compile_expression(field.key)
                self:compile_expression(field.value)
                self:emit_table_set()
            elseif field.type == "TableFieldName" then
                self:compile_expression(field.value)
                -- Store in table
            end
        end
    
    elseif expr.type == "CallExpression" then
        self:compile_expression(expr.callee)
        for _, arg in ipairs(expr.args) do
            self:compile_expression(arg)
        end
        self:emit_call(#expr.args)
    
    elseif expr.type == "MemberExpression" then
        self:compile_expression(expr.object)
        self:compile_expression(expr.property)
        self:emit_table_get()
    end
end

return BytecodeCompiler