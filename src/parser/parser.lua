-- ============================================
-- PARSER: AST Generation from Tokens
-- ============================================
-- Recursive descent parser for complete Luau syntax

local Parser = {}
Parser.__index = Parser

local Lexer = require(script.Parent.lexer)
local ASTNode = require(script.Parent.ast_nodes)

function Parser.new(tokens)
    local self = setmetatable({}, Parser)
    self.tokens = tokens
    self.current = 1
    return self
end

function Parser:peek(offset)
    offset = offset or 0
    local pos = self.current + offset
    if pos > #self.tokens then
        return self.tokens[#self.tokens]
    end
    return self.tokens[pos]
end

function Parser:advance()
    local token = self:peek()
    self.current = self.current + 1
    return token
end

function Parser:check(token_type)
    return self:peek().type == token_type
end

function Parser:match(...)
    for _, token_type in ipairs({...}) do
        if self:check(token_type) then
            return self:advance()
        end
    end
    return nil
end

function Parser:consume(token_type, message)
    if self:check(token_type) then
        return self:advance()
    end
    error(message or "Expected " .. token_type)
end

function Parser:skip_newlines()
    while self:check(Lexer.TokenType.NEWLINE) do
        self:advance()
    end
end

function Parser:parse()
    return self:parse_block()
end

function Parser:parse_block()
    local statements = {}
    
    self:skip_newlines()
    
    while not self:check(Lexer.TokenType.EOF) and 
          not self:check(Lexer.TokenType.END) and
          not self:check(Lexer.TokenType.ELSE) and
          not self:check(Lexer.TokenType.ELSEIF) and
          not self:check(Lexer.TokenType.UNTIL) do
        
        self:skip_newlines()
        
        if self:check(Lexer.TokenType.LOCAL) then
            table.insert(statements, self:parse_local_declaration())
        elseif self:check(Lexer.TokenType.FUNCTION) then
            table.insert(statements, self:parse_function_declaration())
        elseif self:check(Lexer.TokenType.IF) then
            table.insert(statements, self:parse_if_statement())
        elseif self:check(Lexer.TokenType.FOR) then
            table.insert(statements, self:parse_for_loop())
        elseif self:check(Lexer.TokenType.WHILE) then
            table.insert(statements, self:parse_while_loop())
        elseif self:check(Lexer.TokenType.REPEAT) then
            table.insert(statements, self:parse_repeat_loop())
        elseif self:check(Lexer.TokenType.BREAK) then
            table.insert(statements, self:parse_break_statement())
        elseif self:check(Lexer.TokenType.CONTINUE) then
            table.insert(statements, self:parse_continue_statement())
        elseif self:check(Lexer.TokenType.RETURN) then
            table.insert(statements, self:parse_return_statement())
        elseif self:check(Lexer.TokenType.SEMICOLON) then
            self:advance()
        else
            table.insert(statements, self:parse_expression_statement())
        end
        
        self:skip_newlines()
    end
    
    return ASTNode.block(statements, self:peek().line, self:peek().column)
end

function Parser:parse_local_declaration()
    local line = self:consume(Lexer.TokenType.LOCAL).line
    local names = {}
    
    table.insert(names, self:consume(Lexer.TokenType.IDENTIFIER).value)
    
    while self:match(Lexer.TokenType.COMMA) do
        table.insert(names, self:consume(Lexer.TokenType.IDENTIFIER).value)
    end
    
    local values = {}
    if self:match(Lexer.TokenType.ASSIGN) then
        table.insert(values, self:parse_expression())
        while self:match(Lexer.TokenType.COMMA) do
            table.insert(values, self:parse_expression())
        end
    end
    
    return ASTNode.local_declaration(names, values, line, 0)
end

function Parser:parse_function_declaration()
    local line = self:consume(Lexer.TokenType.FUNCTION).line
    local is_local = false
    
    local name_token = self:consume(Lexer.TokenType.IDENTIFIER)
    local name = name_token.value
    
    self:consume(Lexer.TokenType.LEFT_PAREN)
    local params, is_variadic = self:parse_parameter_list()
    self:consume(Lexer.TokenType.RIGHT_PAREN)
    
    self:skip_newlines()
    local body = self:parse_block()
    self:consume(Lexer.TokenType.END)
    
    return ASTNode.function_declaration(name, params, body, is_local, line, 0)
end

function Parser:parse_parameter_list()
    local params = {}
    local is_variadic = false
    
    if not self:check(Lexer.TokenType.RIGHT_PAREN) then
        if self:check(Lexer.TokenType.ELLIPSIS) then
            self:advance()
            is_variadic = true
        else
            table.insert(params, self:consume(Lexer.TokenType.IDENTIFIER).value)
            
            while self:match(Lexer.TokenType.COMMA) do
                if self:check(Lexer.TokenType.ELLIPSIS) then
                    self:advance()
                    is_variadic = true
                    break
                end
                table.insert(params, self:consume(Lexer.TokenType.IDENTIFIER).value)
            end
        end
    end
    
    return params, is_variadic
end

function Parser:parse_if_statement()
    local line = self:consume(Lexer.TokenType.IF).line
    local condition = self:parse_expression()
    self:consume(Lexer.TokenType.THEN)
    self:skip_newlines()
    local then_block = self:parse_block()
    
    local elseif_parts = {}
    while self:match(Lexer.TokenType.ELSEIF) do
        local elseif_cond = self:parse_expression()
        self:consume(Lexer.TokenType.THEN)
        self:skip_newlines()
        local elseif_block = self:parse_block()
        table.insert(elseif_parts, {
            condition = elseif_cond,
            block = elseif_block
        })
    end
    
    local else_block = nil
    if self:match(Lexer.TokenType.ELSE) then
        self:skip_newlines()
        else_block = self:parse_block()
    end
    
    self:consume(Lexer.TokenType.END)
    
    return ASTNode.if_statement(condition, then_block, elseif_parts, else_block, line, 0)
end

function Parser:parse_for_loop()
    local line = self:consume(Lexer.TokenType.FOR).line
    local var = self:consume(Lexer.TokenType.IDENTIFIER).value
    
    if self:match(Lexer.TokenType.ASSIGN) then
        -- Numeric for loop
        local start_val = self:parse_expression()
        self:consume(Lexer.TokenType.COMMA)
        local end_val = self:parse_expression()
        
        local step_val = ASTNode.number_literal(1, line, 0)
        if self:match(Lexer.TokenType.COMMA) then
            step_val = self:parse_expression()
        end
        
        self:consume(Lexer.TokenType.DO)
        self:skip_newlines()
        local body = self:parse_block()
        self:consume(Lexer.TokenType.END)
        
        return ASTNode.for_loop(var, start_val, end_val, step_val, body, line, 0)
    else
        error("for-in loops not fully implemented yet")
    end
end

function Parser:parse_while_loop()
    local line = self:consume(Lexer.TokenType.WHILE).line
    local condition = self:parse_expression()
    self:consume(Lexer.TokenType.DO)
    self:skip_newlines()
    local body = self:parse_block()
    self:consume(Lexer.TokenType.END)
    
    return ASTNode.while_loop(condition, body, line, 0)
end

function Parser:parse_repeat_loop()
    local line = self:consume(Lexer.TokenType.REPEAT).line
    self:skip_newlines()
    local body = self:parse_block()
    self:consume(Lexer.TokenType.UNTIL)
    local condition = self:parse_expression()
    
    return ASTNode.repeat_loop(body, condition, line, 0)
end

function Parser:parse_break_statement()
    local line = self:consume(Lexer.TokenType.BREAK).line
    return ASTNode.break_statement(line, 0)
end

function Parser:parse_continue_statement()
    local line = self:consume(Lexer.TokenType.CONTINUE).line
    return ASTNode.continue_statement(line, 0)
end

function Parser:parse_return_statement()
    local line = self:consume(Lexer.TokenType.RETURN).line
    local values = {}
    
    if not self:check(Lexer.TokenType.EOF) and 
       not self:check(Lexer.TokenType.END) and
       not self:check(Lexer.TokenType.ELSE) and
       not self:check(Lexer.TokenType.ELSEIF) and
       not self:check(Lexer.TokenType.UNTIL) and
       not self:check(Lexer.TokenType.NEWLINE) then
        table.insert(values, self:parse_expression())
        while self:match(Lexer.TokenType.COMMA) do
            table.insert(values, self:parse_expression())
        end
    end
    
    return ASTNode.return_statement(values, line, 0)
end

function Parser:parse_expression_statement()
    local expr = self:parse_expression()
    
    -- Check for assignment
    if self:check(Lexer.TokenType.ASSIGN) or 
       self:check(Lexer.TokenType.PLUS_ASSIGN) or
       self:check(Lexer.TokenType.MINUS_ASSIGN) or
       self:check(Lexer.TokenType.MULT_ASSIGN) or
       self:check(Lexer.TokenType.DIV_ASSIGN) or
       self:check(Lexer.TokenType.MOD_ASSIGN) or
       self:check(Lexer.TokenType.CONCAT_ASSIGN) then
        
        local targets = {expr}
        while self:match(Lexer.TokenType.COMMA) do
            table.insert(targets, self:parse_primary())
        end
        
        self:advance() -- consume assignment operator
        
        local values = {self:parse_expression()}
        while self:match(Lexer.TokenType.COMMA) do
            table.insert(values, self:parse_expression())
        end
        
        return ASTNode.assignment(targets, values, expr.line, expr.column)
    else
        return ASTNode.expression_statement(expr, expr.line, expr.column)
    end
end

function Parser:parse_expression()
    return self:parse_or()
end

function Parser:parse_or()
    local left = self:parse_and()
    
    while self:match(Lexer.TokenType.OR) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_and()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_and()
    local left = self:parse_comparison()
    
    while self:match(Lexer.TokenType.AND) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_comparison()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_comparison()
    local left = self:parse_concat()
    
    while self:match(Lexer.TokenType.EQUAL, Lexer.TokenType.NOT_EQUAL, 
                     Lexer.TokenType.LESS_THAN, Lexer.TokenType.GREATER_THAN,
                     Lexer.TokenType.LESS_EQUAL, Lexer.TokenType.GREATER_EQUAL) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_concat()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_concat()
    local left = self:parse_additive()
    
    while self:match(Lexer.TokenType.CONCAT) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_additive()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_additive()
    local left = self:parse_multiplicative()
    
    while self:match(Lexer.TokenType.PLUS, Lexer.TokenType.MINUS) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_multiplicative()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_multiplicative()
    local left = self:parse_unary()
    
    while self:match(Lexer.TokenType.MULTIPLY, Lexer.TokenType.DIVIDE, Lexer.TokenType.MODULO) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_unary()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_unary()
    if self:match(Lexer.TokenType.NOT, Lexer.TokenType.MINUS, Lexer.TokenType.LENGTH) then
        local operator = self.tokens[self.current - 1].value
        local operand = self:parse_unary()
        return ASTNode.unary_op(operator, operand, operand.line, operand.column)
    end
    
    return self:parse_power()
end

function Parser:parse_power()
    local left = self:parse_postfix()
    
    if self:match(Lexer.TokenType.POWER) do
        local operator = self.tokens[self.current - 1].value
        local right = self:parse_power()
        left = ASTNode.binary_op(left, operator, right, left.line, left.column)
    end
    
    return left
end

function Parser:parse_postfix()
    local expr = self:parse_primary()
    
    while true do
        if self:match(Lexer.TokenType.LEFT_PAREN) then
            -- Function call
            local args = {}
            if not self:check(Lexer.TokenType.RIGHT_PAREN) then
                table.insert(args, self:parse_expression())
                while self:match(Lexer.TokenType.COMMA) do
                    table.insert(args, self:parse_expression())
                end
            end
            self:consume(Lexer.TokenType.RIGHT_PAREN)
            expr = ASTNode.call_expression(expr, args, expr.line, expr.column)
        
        elseif self:match(Lexer.TokenType.DOT) then
            -- Member access
            local property = self:consume(Lexer.TokenType.IDENTIFIER).value
            expr = ASTNode.member_expression(expr, ASTNode.identifier(property, 0, 0), false, expr.line, expr.column)
        
        elseif self:match(Lexer.TokenType.LEFT_BRACKET) then
            -- Index access
            local index = self:parse_expression()
            self:consume(Lexer.TokenType.RIGHT_BRACKET)
            expr = ASTNode.index_expression(expr, index, expr.line, expr.column)
        
        elseif self:match(Lexer.TokenType.COLON) then
            -- Method call
            local method = self:consume(Lexer.TokenType.IDENTIFIER).value
            self:consume(Lexer.TokenType.LEFT_PAREN)
            local args = {}
            if not self:check(Lexer.TokenType.RIGHT_PAREN) then
                table.insert(args, self:parse_expression())
                while self:match(Lexer.TokenType.COMMA) do
                    table.insert(args, self:parse_expression())
                end
            end
            self:consume(Lexer.TokenType.RIGHT_PAREN)
            expr = ASTNode.method_call(expr, method, args, expr.line, expr.column)
        else
            break
        end
    end
    
    return expr
end

function Parser:parse_primary()
    local line = self:peek().line
    local column = self:peek().column
    
    if self:match(Lexer.TokenType.NUMBER) then
        return ASTNode.number_literal(self.tokens[self.current - 1].value, line, column)
    
    elseif self:match(Lexer.TokenType.STRING) then
        return ASTNode.string_literal(self.tokens[self.current - 1].value, line, column)
    
    elseif self:match(Lexer.TokenType.TRUE) then
        return ASTNode.boolean_literal(true, line, column)
    
    elseif self:match(Lexer.TokenType.FALSE) then
        return ASTNode.boolean_literal(false, line, column)
    
    elseif self:match(Lexer.TokenType.NIL) then
        return ASTNode.nil_literal(line, column)
    
    elseif self:match(Lexer.TokenType.ELLIPSIS) then
        return ASTNode.varargs(line, column)
    
    elseif self:match(Lexer.TokenType.IDENTIFIER) then
        return ASTNode.identifier(self.tokens[self.current - 1].value, line, column)
    
    elseif self:match(Lexer.TokenType.LEFT_BRACE) then
        return self:parse_table_constructor()
    
    elseif self:match(Lexer.TokenType.FUNCTION) then
        return self:parse_function_literal()
    
    elseif self:match(Lexer.TokenType.LEFT_PAREN) then
        local expr = self:parse_expression()
        self:consume(Lexer.TokenType.RIGHT_PAREN)
        return expr
    
    else
        error("Unexpected token: " .. self:peek().type)
    end
end

function Parser:parse_table_constructor()
    local line = self:peek().line
    local fields = {}
    
    if not self:check(Lexer.TokenType.RIGHT_BRACE) then
        table.insert(fields, self:parse_table_field())
        while self:match(Lexer.TokenType.COMMA) do
            if self:check(Lexer.TokenType.RIGHT_BRACE) then
                break
            end
            table.insert(fields, self:parse_table_field())
        end
    end
    
    self:consume(Lexer.TokenType.RIGHT_BRACE)
    return ASTNode.table_constructor(fields, line, 0)
end

function Parser:parse_table_field()
    if self:check(Lexer.TokenType.IDENTIFIER) and self:peek(1).type == Lexer.TokenType.ASSIGN then
        local name = self:consume(Lexer.TokenType.IDENTIFIER).value
        self:consume(Lexer.TokenType.ASSIGN)
        local value = self:parse_expression()
        return ASTNode.table_field_name(name, value, 0, 0)
    
    elseif self:check(Lexer.TokenType.LEFT_BRACKET) then
        self:advance()
        local key = self:parse_expression()
        self:consume(Lexer.TokenType.RIGHT_BRACKET)
        self:consume(Lexer.TokenType.ASSIGN)
        local value = self:parse_expression()
        return ASTNode.table_field_key_value(key, value, 0, 0)
    
    else
        return ASTNode.table_field_list(self:parse_expression(), 0, 0)
    end
end

function Parser:parse_function_literal()
    local line = self:peek().line
    self:consume(Lexer.TokenType.LEFT_PAREN)
    local params, is_variadic = self:parse_parameter_list()
    self:consume(Lexer.TokenType.RIGHT_PAREN)
    self:skip_newlines()
    local body = self:parse_block()
    self:consume(Lexer.TokenType.END)
    return ASTNode.function_literal(params, body, is_variadic, line, 0)
end

return Parser