-- ============================================
-- CONSTANT OBFUSCATOR: Hide numeric constants
-- ============================================
-- Encode numbers as mathematical expressions

local ConstantObfuscator = {}
ConstantObfuscator.__index = ConstantObfuscator

function ConstantObfuscator.new(seed)
    local self = setmetatable({}, ConstantObfuscator)
    self.seed = seed or math.random(1, 2147483647)
    math.randomseed(self.seed)
    return self
end

function ConstantObfuscator:encode_number(num)
    local methods = {
        -- Method 1: Addition
        function(n)
            local a = math.random(1, 100)
            local b = n - a
            return {method = "add", a = a, b = b}
        end,
        -- Method 2: Subtraction
        function(n)
            local a = n + math.random(1, 100)
            local b = a - n
            return {method = "sub", a = a, b = b}
        end,
        -- Method 3: Multiplication
        function(n)
            if n == 0 then return {method = "const", value = 0} end
            local div = math.random(2, 10)
            if n % div == 0 then
                return {method = "mul", a = n / div, b = div}
            else
                return {method = "const", value = n}
            end
        end,
        -- Method 4: XOR with random number
        function(n)
            local rand = math.random(1, 100000)
            return {method = "xor", a = rand, b = n ~ rand}
        end,
        -- Method 5: Bit shift
        function(n)
            if n > 0 and n < 1000 then
                local shifted = n * 2
                return {method = "shift", a = shifted, b = 1}
            else
                return {method = "const", value = n}
            end
        end,
    }
    
    local method = methods[math.random(1, #methods)]
    return method(num)
end

function ConstantObfuscator:generate_expression(encoded)
    if encoded.method == "add" then
        return encoded.a .. " + " .. encoded.b
    elseif encoded.method == "sub" then
        return encoded.a .. " - " .. encoded.b
    elseif encoded.method == "mul" then
        return encoded.a .. " * " .. encoded.b
    elseif encoded.method == "xor" then
        return encoded.a .. " ~ " .. encoded.b
    elseif encoded.method == "shift" then
        return "(" .. encoded.a .. " >> " .. encoded.b .. ")"
    else
        return tostring(encoded.value)
    end
end

function ConstantObfuscator:obfuscate_ast(ast)
    -- Recursively walk AST and replace numeric literals
    if ast.type == "NumberLiteral" then
        local encoded = self:encode_number(ast.value)
        -- Store encoding info for later code generation
        ast._encoded = encoded
        ast._expression = self:generate_expression(encoded)
    elseif ast.type == "BinaryOp" or ast.type == "UnaryOp" or ast.type == "Block" then
        for key, value in pairs(ast) do
            if type(value) == "table" and value.type then
                self:obfuscate_ast(value)
            elseif type(value) == "table" then
                for _, item in ipairs(value) do
                    if type(item) == "table" and item.type then
                        self:obfuscate_ast(item)
                    end
                end
            end
        end
    end
end

return ConstantObfuscator