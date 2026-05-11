-- ============================================
-- OBFUSCATION PIPELINE: Multi-pass processing
-- ============================================
-- Orchestrate all obfuscation passes

local Pipeline = {}
Pipeline.__index = Pipeline

local StringObfuscator = require(script.Parent.string_obfuscator)
local ConstantObfuscator = require(script.Parent.constant_obfuscator)
local IdentifierMangler = require(script.Parent.identifier_mangler)
local ControlFlowObfuscator = require(script.Parent.flow_obfuscator)

function Pipeline.new(config)
    local self = setmetatable({}, Pipeline)
    
    self.config = config or {}
    self.config.level = self.config.level or "high"
    self.config.string_encryption = self.config.string_encryption ~= false
    self.config.constant_obfuscation = self.config.constant_obfuscation ~= false
    self.config.identifier_mangling = self.config.identifier_mangling ~= false
    self.config.control_flow = self.config.control_flow ~= false
    self.config.seed = self.config.seed or math.random(1, 2147483647)
    
    math.randomseed(self.config.seed)
    
    -- Initialize passes
    self.string_obfuscator = StringObfuscator.new(self.config.seed)
    self.constant_obfuscator = ConstantObfuscator.new(self.config.seed)
    self.identifier_mangler = IdentifierMangler.new(self.config.seed)
    self.control_flow_obfuscator = ControlFlowObfuscator.new(self.config.seed)
    
    return self
end

function Pipeline:execute(ast)
    -- Pass 1: Identifier Mangling
    if self.config.identifier_mangling then
        self.identifier_mangler:obfuscate_ast(ast)
    end
    
    -- Pass 2: Control Flow Obfuscation
    if self.config.control_flow then
        self.control_flow_obfuscator:obfuscate_ast(ast)
    end
    
    -- Pass 3: Constant Obfuscation
    if self.config.constant_obfuscation then
        self.constant_obfuscator:obfuscate_ast(ast)
    end
    
    -- Pass 4: String Encryption
    if self.config.string_encryption then
        -- String encryption happens during code generation
    end
    
    return ast
end

function Pipeline:get_string_obfuscator()
    return self.string_obfuscator
end

function Pipeline:get_constant_obfuscator()
    return self.constant_obfuscator
end

function Pipeline:get_identifier_mangler()
    return self.identifier_mangler
end

function Pipeline:get_control_flow_obfuscator()
    return self.control_flow_obfuscator
end

function Pipeline:get_config()
    return self.config
end

return Pipeline