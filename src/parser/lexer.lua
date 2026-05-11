-- ============================================
-- LEXER: Luau Tokenization Engine
-- ============================================
-- Complete tokenization for Luau with all syntax support

local Lexer = {}
Lexer.__index = Lexer

-- Token types
Lexer.TokenType = {
    -- Literals
    NUMBER = "NUMBER",
    STRING = "STRING",
    IDENTIFIER = "IDENTIFIER",
    TRUE = "TRUE",
    FALSE = "FALSE",
    NIL = "NIL",
    
    -- Keywords
    LOCAL = "LOCAL",
    FUNCTION = "FUNCTION",
    IF = "IF",
    THEN = "THEN",
    ELSE = "ELSE",
    ELSEIF = "ELSEIF",
    END = "END",
    FOR = "FOR",
    WHILE = "WHILE",
    DO = "DO",
    BREAK = "BREAK",
    RETURN = "RETURN",
    AND = "AND",
    OR = "OR",
    NOT = "NOT",
    IN = "IN",
    REPEAT = "REPEAT",
    UNTIL = "UNTIL",
    CONTINUE = "CONTINUE",
    EXPORT = "EXPORT",
    TYPE = "TYPE",
    TYPEOF = "TYPEOF",
    
    -- Operators
    PLUS = "PLUS",
    MINUS = "MINUS",
    MULTIPLY = "MULTIPLY",
    DIVIDE = "DIVIDE",
    MODULO = "MODULO",
    POWER = "POWER",
    CONCAT = "CONCAT",
    EQUAL = "EQUAL",
    NOT_EQUAL = "NOT_EQUAL",
    LESS_THAN = "LESS_THAN",
    GREATER_THAN = "GREATER_THAN",
    LESS_EQUAL = "LESS_EQUAL",
    GREATER_EQUAL = "GREATER_EQUAL",
    ASSIGN = "ASSIGN",
    PLUS_ASSIGN = "PLUS_ASSIGN",
    MINUS_ASSIGN = "MINUS_ASSIGN",
    MULT_ASSIGN = "MULT_ASSIGN",
    DIV_ASSIGN = "DIV_ASSIGN",
    MOD_ASSIGN = "MOD_ASSIGN",
    CONCAT_ASSIGN = "CONCAT_ASSIGN",
    LENGTH = "LENGTH",
    BITWISE_AND = "BITWISE_AND",
    BITWISE_OR = "BITWISE_OR",
    BITWISE_XOR = "BITWISE_XOR",
    BITWISE_NOT = "BITWISE_NOT",
    LEFT_SHIFT = "LEFT_SHIFT",
    RIGHT_SHIFT = "RIGHT_SHIFT",
    
    -- Delimiters
    LEFT_PAREN = "LEFT_PAREN",
    RIGHT_PAREN = "RIGHT_PAREN",
    LEFT_BRACE = "LEFT_BRACE",
    RIGHT_BRACE = "RIGHT_BRACE",
    LEFT_BRACKET = "LEFT_BRACKET",
    RIGHT_BRACKET = "RIGHT_BRACKET",
    SEMICOLON = "SEMICOLON",
    COMMA = "COMMA",
    DOT = "DOT",
    COLON = "COLON",
    DOUBLE_COLON = "DOUBLE_COLON",
    ELLIPSIS = "ELLIPSIS",
    ARROW = "ARROW",
    FAT_ARROW = "FAT_ARROW",
    QUESTION = "QUESTION",
    
    -- Special
    EOF = "EOF",
    NEWLINE = "NEWLINE",
    COMMENT = "COMMENT",
}

local KEYWORDS = {
    ["local"] = Lexer.TokenType.LOCAL,
    ["function"] = Lexer.TokenType.FUNCTION,
    ["if"] = Lexer.TokenType.IF,
    ["then"] = Lexer.TokenType.THEN,
    ["else"] = Lexer.TokenType.ELSE,
    ["elseif"] = Lexer.TokenType.ELSEIF,
    ["end"] = Lexer.TokenType.END,
    ["for"] = Lexer.TokenType.FOR,
    ["while"] = Lexer.TokenType.WHILE,
    ["do"] = Lexer.TokenType.DO,
    ["break"] = Lexer.TokenType.BREAK,
    ["return"] = Lexer.TokenType.RETURN,
    ["and"] = Lexer.TokenType.AND,
    ["or"] = Lexer.TokenType.OR,
    ["not"] = Lexer.TokenType.NOT,
    ["in"] = Lexer.TokenType.IN,
    ["repeat"] = Lexer.TokenType.REPEAT,
    ["until"] = Lexer.TokenType.UNTIL,
    ["continue"] = Lexer.TokenType.CONTINUE,
    ["export"] = Lexer.TokenType.EXPORT,
    ["true"] = Lexer.TokenType.TRUE,
    ["false"] = Lexer.TokenType.FALSE,
    ["nil"] = Lexer.TokenType.NIL,
    ["type"] = Lexer.TokenType.TYPE,
    ["typeof"] = Lexer.TokenType.TYPEOF,
}

local function is_digit(char)
    if not char then return false end
    return char >= "0" and char <= "9"
 end

local function is_alpha(char)
    if not char then return false end
    return (char >= "a" and char <= "z") or (char >= "A" and char <= "Z") or char == "_"
end

local function is_alphanumeric(char)
    return is_alpha(char) or is_digit(char)
end

local function is_whitespace(char)
    if not char then return false end
    return char == " " or char == "\t" or char == "\r"
end

function Lexer.new(source)
    local self = setmetatable({}, Lexer)
    self.source = source
    self.position = 1
    self.line = 1
    self.column = 1
    self.tokens = {}
    return self
end

function Lexer:peek(offset)
    offset = offset or 0
    local pos = self.position + offset
    if pos > #self.source then
        return nil
    end
    return self.source:sub(pos, pos)
end

function Lexer:advance()
    local char = self:peek()
    if char == "\n" then
        self.line = self.line + 1
        self.column = 1
    else
        self.column = self.column + 1
    end
    self.position = self.position + 1
    return char
end

function Lexer:skip_whitespace()
    while is_whitespace(self:peek()) do
        self:advance()
    end
end

function Lexer:read_line_comment()
    -- Skip initial --
    self:advance()
    self:advance()
    
    local start = self.position
    while self:peek() and self:peek() ~= "\n" do
        self:advance()
    end
    
    return self.source:sub(start, self.position - 1)
end

function Lexer:read_block_comment()
    -- Skip initial --[[
    self:advance()
    self:advance()
    self:advance()
    self:advance()
    
    local start = self.position
    while self:peek() do
        if self:peek() == "]" and self:peek(1) == "]" then
            local content = self.source:sub(start, self.position - 1)
            self:advance()
            self:advance()
            return content
        end
        self:advance()
    end
    
    error("Unclosed block comment at line " .. self.line)
end

function Lexer:read_string(quote_char)
    self:advance() -- Skip opening quote
    
    local start = self.position
    local result = ""
    
    while self:peek() and self:peek() ~= quote_char do
        if self:peek() == "\\" then
            self:advance()
            local escape_char = self:peek()
            if escape_char == "n" then
                result = result .. "\n"
            elseif escape_char == "t" then
                result = result .. "\t"
            elseif escape_char == "r" then
                result = result .. "\r"
            elseif escape_char == "\\" then
                result = result .. "\\"
            elseif escape_char == quote_char then
                result = result .. quote_char
            elseif escape_char == "0" then
                result = result .. "\0"
            else
                result = result .. escape_char
            end
            self:advance()
        else
            result = result .. self:peek()
            self:advance()
        end
    end
    
    if not self:peek() then
        error("Unclosed string at line " .. self.line)
    end
    
    self:advance() -- Skip closing quote
    return result
end

function Lexer:read_number()
    local start = self.position
    local num_str = ""
    local has_dot = false
    local has_exp = false
    
    -- Handle hex numbers
    if self:peek() == "0" and (self:peek(1) == "x" or self:peek(1) == "X") then
        num_str = num_str .. self:advance()
        num_str = num_str .. self:advance()
        while is_digit(self:peek()) or (self:peek() and self:peek():lower() >= "a" and self:peek():lower() <= "f") do
            num_str = num_str .. self:advance()
        end
        return tonumber(num_str)
    end
    
    -- Regular decimal number
    while is_digit(self:peek()) or self:peek() == "." or self:peek() == "e" or self:peek() == "E" do
        if self:peek() == "." then
            if has_dot or has_exp then break end
            has_dot = true
            num_str = num_str .. self:advance()
        elseif self:peek() == "e" or self:peek() == "E" then
            if has_exp then break end
            has_exp = true
            num_str = num_str .. self:advance()
            if self:peek() == "+" or self:peek() == "-" then
                num_str = num_str .. self:advance()
            end
        else
            num_str = num_str .. self:advance()
        end
    end
    
    return tonumber(num_str)
end

function Lexer:read_identifier()
    local start = self.position
    while is_alphanumeric(self:peek()) do
        self:advance()
    end
    return self.source:sub(start, self.position - 1)
end

function Lexer:add_token(token_type, value, literal)
    table.insert(self.tokens, {
        type = token_type,
        value = value,
        literal = literal,
        line = self.line,
        column = self.column,
    })
end

function Lexer:tokenize()
    while self.position <= #self.source do
        self:skip_whitespace()
        
        if self.position > #self.source then
            break
        end
        
        local char = self:peek()
        
        -- Newline
        if char == "\n" then
            self:advance()
            self:add_token(Lexer.TokenType.NEWLINE, "\n")
        
        -- Comments
        elseif char == "-" and self:peek(1) == "-" then
            if self:peek(2) == "[" and self:peek(3) == "[" then
                self:read_block_comment()
            else
                self:read_line_comment()
            end
        
        -- Strings
        elseif char == '"' or char == "'" then
            local str_val = self:read_string(char)
            self:add_token(Lexer.TokenType.STRING, str_val)
        
        -- Numbers
        elseif is_digit(char) then
            local num_val = self:read_number()
            self:add_token(Lexer.TokenType.NUMBER, num_val)
        
        -- Identifiers and Keywords
        elseif is_alpha(char) then
            local ident = self:read_identifier()
            local token_type = KEYWORDS[ident] or Lexer.TokenType.IDENTIFIER
            self:add_token(token_type, ident)
        
        -- Operators and Delimiters
        elseif char == "+" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.PLUS_ASSIGN, "+=")
            else
                self:add_token(Lexer.TokenType.PLUS, "+")
            end
        
        elseif char == "-" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.MINUS_ASSIGN, "-=")
            else
                self:add_token(Lexer.TokenType.MINUS, "-")
            end
        
        elseif char == "*" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.MULT_ASSIGN, "*=")
            else
                self:add_token(Lexer.TokenType.MULTIPLY, "*")
            end
        
        elseif char == "/" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.DIV_ASSIGN, "/=")
            else
                self:add_token(Lexer.TokenType.DIVIDE, "/")
            end
        
        elseif char == "%" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.MOD_ASSIGN, "%=")
            else
                self:add_token(Lexer.TokenType.MODULO, "%")
            end
        
        elseif char == "^" then
            self:advance()
            self:add_token(Lexer.TokenType.POWER, "^")
        
        elseif char == "." then
            self:advance()
            if self:peek() == "." then
                self:advance()
                if self:peek() == "." then
                    self:advance()
                    self:add_token(Lexer.TokenType.ELLIPSIS, "...")
                else
                    self:add_token(Lexer.TokenType.CONCAT, "..")
                end
            else
                self:add_token(Lexer.TokenType.DOT, ".")
            end
        
        elseif char == "=" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.EQUAL, "==")
            elseif self:peek() == ">" then
                self:advance()
                self:add_token(Lexer.TokenType.FAT_ARROW, "=>")
            else
                self:add_token(Lexer.TokenType.ASSIGN, "=")
            end
        
        elseif char == "~" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.NOT_EQUAL, "~=")
            else
                self:add_token(Lexer.TokenType.BITWISE_XOR, "~")
            end
        
        elseif char == "<" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.LESS_EQUAL, "<=")
            elseif self:peek() == "<" then
                self:advance()
                self:add_token(Lexer.TokenType.LEFT_SHIFT, "<<")
            else
                self:add_token(Lexer.TokenType.LESS_THAN, "<")
            end
        
        elseif char == ">" then
            self:advance()
            if self:peek() == "=" then
                self:advance()
                self:add_token(Lexer.TokenType.GREATER_EQUAL, ">=")
            elseif self:peek() == ">" then
                self:advance()
                self:add_token(Lexer.TokenType.RIGHT_SHIFT, ">>")
            else
                self:add_token(Lexer.TokenType.GREATER_THAN, ">")
            end
        
        elseif char == "#" then
            self:advance()
            self:add_token(Lexer.TokenType.LENGTH, "#")
        
        elseif char == "&" then
            self:advance()
            self:add_token(Lexer.TokenType.BITWISE_AND, "&")
        
        elseif char == "|" then
            self:advance()
            self:add_token(Lexer.TokenType.BITWISE_OR, "|")
        
        elseif char == "(" then
            self:advance()
            self:add_token(Lexer.TokenType.LEFT_PAREN, "(")
        
        elseif char == ")" then
            self:advance()
            self:add_token(Lexer.TokenType.RIGHT_PAREN, ")")
        
        elseif char == "{" then
            self:advance()
            self:add_token(Lexer.TokenType.LEFT_BRACE, "{")
        
        elseif char == "}" then
            self:advance()
            self:add_token(Lexer.TokenType.RIGHT_BRACE, "}")
        
        elseif char == "[" then
            self:advance()
            self:add_token(Lexer.TokenType.LEFT_BRACKET, "[")
        
        elseif char == "]" then
            self:advance()
            self:add_token(Lexer.TokenType.RIGHT_BRACKET, "]")
        
        elseif char == ";" then
            self:advance()
            self:add_token(Lexer.TokenType.SEMICOLON, ";")
        
        elseif char == "," then
            self:advance()
            self:add_token(Lexer.TokenType.COMMA, ",")
        
        elseif char == ":" then
            self:advance()
            if self:peek() == ":" then
                self:advance()
                self:add_token(Lexer.TokenType.DOUBLE_COLON, "::")
            else
                self:add_token(Lexer.TokenType.COLON, ":")
            end
        
        elseif char == "?" then
            self:advance()
            self:add_token(Lexer.TokenType.QUESTION, "?")
        
        else
            error("Unexpected character '" .. char .. "' at line " .. self.line .. ", column " .. self.column)
        end
    end
    
    self:add_token(Lexer.TokenType.EOF, "EOF")
    return self.tokens
end

return Lexer