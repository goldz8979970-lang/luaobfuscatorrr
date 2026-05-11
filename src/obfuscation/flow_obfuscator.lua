-- ============================================
-- CONTROL FLOW OBFUSCATOR: Flatten if statements
-- ============================================
-- Convert nested if/else to dispatcher state machine

local ControlFlowObfuscator = {}
ControlFlowObfuscator.__index = ControlFlowObfuscator

function ControlFlowObfuscator.new(seed)
    local self = setmetatable({}, ControlFlowObfuscator)
    self.seed = seed or math.random(1, 2147483647)
    math.randomseed(self.seed)
    self.state_counter = 0
    return self
end

function ControlFlowObfuscator:create_state()
    self.state_counter = self.state_counter + 1
    return self.state_counter
end

function ControlFlowObfuscator:flatten_if_statement(if_stmt)
    -- Convert:
    -- if condition then
    --   block1
    -- else
    --   block2
    -- end
    --
    -- To:
    -- local _state = 0
    -- if condition then _state = 1 else _state = 2 end
    -- if _state == 1 then block1 elseif _state == 2 then block2 end
    
    local state_var = "_state_" .. self:create_state()
    local state_then = self:create_state()
    local state_else = self:create_state()
    
    -- Create state dispatcher
    local dispatcher = {
        type = "Block",
        statements = {
            {
                type = "LocalDeclaration",
                names = {state_var},
                values = {{type = "NumberLiteral", value = 0}}
            },
            {
                type = "IfStatement",
                condition = if_stmt.condition,
                then_block = {
                    type = "Block",
                    statements = {
                        {
                            type = "Assignment",
                            targets = {{type = "Identifier", name = state_var}},
                            values = {{type = "NumberLiteral", value = state_then}}
                        }
                    }
                },
                elseif_parts = {},
                else_block = {
                    type = "Block",
                    statements = {
                        {
                            type = "Assignment",
                            targets = {{type = "Identifier", name = state_var}},
                            values = {{type = "NumberLiteral", value = state_else}}
                        }
                    }
                }
            },
            -- State machine dispatcher
            {
                type = "IfStatement",
                condition = {
                    type = "BinaryOp",
                    left = {type = "Identifier", name = state_var},
                    operator = "==",
                    right = {type = "NumberLiteral", value = state_then}
                },
                then_block = if_stmt.then_block,
                elseif_parts = {},
                else_block = if_stmt.else_block
            }
        }
    }
    
    return dispatcher
end

function ControlFlowObfuscator:inject_dead_code(block)
    -- Insert unreachable code to confuse decompilers
    local dead_code = {
        type = "IfStatement",
        condition = {type = "BooleanLiteral", value = false},
        then_block = {
            type = "Block",
            statements = {
                {
                    type = "ExpressionStatement",
                    expression = {
                        type = "BinaryOp",
                        left = {type = "NumberLiteral", value = math.random(1, 1000)},
                        operator = "+",
                        right = {type = "NumberLiteral", value = math.random(1, 1000)}
                    }
                }
            }
        },
        elseif_parts = {},
        else_block = nil
    }
    
    table.insert(block.statements, dead_code)
end

function ControlFlowObfuscator:obfuscate_ast(ast)
    if ast.type == "Block" then
        for i, stmt in ipairs(ast.statements or {}) do
            self:obfuscate_ast(stmt)
        end
        -- Inject dead code occasionally
        if math.random(1, 5) == 1 then
            self:inject_dead_code(ast)
        end
    
    elseif ast.type == "IfStatement" then
        -- Optionally flatten if statements
        if math.random(1, 3) == 1 then
            return self:flatten_if_statement(ast)
        else
            self:obfuscate_ast(ast.condition)
            self:obfuscate_ast(ast.then_block)
            for _, elseif_part in ipairs(ast.elseif_parts or {}) do
                self:obfuscate_ast(elseif_part.condition)
                self:obfuscate_ast(elseif_part.block)
            end
            if ast.else_block then
                self:obfuscate_ast(ast.else_block)
            end
        end
    
    elseif ast.type == "ForLoop" then
        self:obfuscate_ast(ast.start_val)
        self:obfuscate_ast(ast.end_val)
        self:obfuscate_ast(ast.step_val)
        self:obfuscate_ast(ast.body)
    
    elseif ast.type == "WhileLoop" then
        self:obfuscate_ast(ast.condition)
        self:obfuscate_ast(ast.body)
    
    elseif ast.type == "BinaryOp" then
        self:obfuscate_ast(ast.left)
        self:obfuscate_ast(ast.right)
    
    elseif ast.type == "UnaryOp" then
        self:obfuscate_ast(ast.operand)
    end
end

return ControlFlowObfuscator