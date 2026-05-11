-- ============================================
-- IDENTIFIER MANGLER: Rename variables/functions
-- ============================================
-- Obfuscate variable and function names with unicode

local IdentifierMangler = {}
IdentifierMangler.__index = IdentifierMangler

function IdentifierMangler.new(seed)
    local self = setmetatable({}, IdentifierMangler)
    self.seed = seed or math.random(1, 2147483647)
    math.randomseed(self.seed)
    self.name_map = {}           -- original -> obfuscated
    self.reverse_map = {}        -- obfuscated -> original (for debug)
    self.preserved_names = {     -- Don't mangle these
        print = true,
        tostring = true,
        tonumber = true,
        type = true,
        pairs = true,
        ipairs = true,
        next = true,
        table = true,
        string = true,
        math = true,
        game = true,
        script = true,
        Instance = true,
        Vector3 = true,
        CFrame = true,
        Color3 = true,
    }
    return self
end

function IdentifierMangler:generate_name()
    -- Generate random unicode-based identifier
    local chars = {}
    local length = math.random(8, 16)
    
    for i = 1, length do
        -- Use mathematical alphanumeric symbols and other unicode ranges
        local code_point = math.random(0x1D400, 0x1D7FF) -- Mathematical Alphanumeric Symbols
        table.insert(chars, string.char(code_point))
    end
    
    return table.concat(chars)
end

function IdentifierMangler:get_mangled_name(original)
    if self.preserved_names[original] then
        return original
    end
    
    if not self.name_map[original] then
        local mangled = self:generate_name()
        self.name_map[original] = mangled
        self.reverse_map[mangled] = original
    end
    
    return self.name_map[original]
end

function IdentifierMangler:obfuscate_ast(ast)
    if ast.type == "Identifier" then
        ast.name = self:get_mangled_name(ast.name)
    
    elseif ast.type == "LocalDeclaration" then
        for i, name in ipairs(ast.names) do
            ast.names[i] = self:get_mangled_name(name)
        end
        for _, value in ipairs(ast.values or {}) do
            if type(value) == "table" and value.type then
                self:obfuscate_ast(value)
            end
        end
    
    elseif ast.type == "FunctionDeclaration" then
        ast.name = self:get_mangled_name(ast.name)
        for i, param in ipairs(ast.params or {}) do
            ast.params[i] = self:get_mangled_name(param)
        end
        self:obfuscate_ast(ast.body)
    
    elseif ast.type == "FunctionLiteral" then
        for i, param in ipairs(ast.params or {}) do
            ast.params[i] = self:get_mangled_name(param)
        end
        self:obfuscate_ast(ast.body)
    
    elseif ast.type == "Block" then
        for _, stmt in ipairs(ast.statements or {}) do
            self:obfuscate_ast(stmt)
        end
    
    elseif ast.type == "BinaryOp" then
        self:obfuscate_ast(ast.left)
        self:obfuscate_ast(ast.right)
    
    elseif ast.type == "UnaryOp" then
        self:obfuscate_ast(ast.operand)
    
    elseif ast.type == "CallExpression" then
        self:obfuscate_ast(ast.callee)
        for _, arg in ipairs(ast.args or {}) do
            self:obfuscate_ast(arg)
        end
    
    elseif ast.type == "TableConstructor" then
        for _, field in ipairs(ast.fields or {}) do
            self:obfuscate_ast(field)
        end
    
    elseif ast.type == "MemberExpression" then
        self:obfuscate_ast(ast.object)
        self:obfuscate_ast(ast.property)
    
    elseif ast.type == "IfStatement" then
        self:obfuscate_ast(ast.condition)
        self:obfuscate_ast(ast.then_block)
        for _, elseif_part in ipairs(ast.elseif_parts or {}) do
            self:obfuscate_ast(elseif_part.condition)
            self:obfuscate_ast(elseif_part.block)
        end
        if ast.else_block then
            self:obfuscate_ast(ast.else_block)
        end
    
    elseif ast.type == "ForLoop" then
        ast.var = self:get_mangled_name(ast.var)
        self:obfuscate_ast(ast.start_val)
        self:obfuscate_ast(ast.end_val)
        self:obfuscate_ast(ast.step_val)
        self:obfuscate_ast(ast.body)
    
    elseif ast.type == "WhileLoop" then
        self:obfuscate_ast(ast.condition)
        self:obfuscate_ast(ast.body)
    
    elseif ast.type == "Assignment" then
        for _, target in ipairs(ast.targets or {}) do
            self:obfuscate_ast(target)
        end
        for _, value in ipairs(ast.values or {}) do
            self:obfuscate_ast(value)
        end
    end
end

function IdentifierMangler:get_name_map()
    return self.name_map
end

function IdentifierMangler:get_reverse_map()
    return self.reverse_map
end

return IdentifierMangler