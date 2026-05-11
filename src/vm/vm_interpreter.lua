-- ============================================
-- VM INTERPRETER: Bytecode Executor
-- ============================================
-- Complete VM that executes bytecode instructions

local VMInterpreter = {}
VMInterpreter.__index = VMInterpreter

local StackMachine = require(script.Parent.stack_machine)

function VMInterpreter.new()
    local self = setmetatable({}, VMInterpreter)
    self.machine = StackMachine.new()
    self.debug_mode = false
    return self
end

function VMInterpreter:load(bytecode, constants)
    self.machine:set_bytecode(bytecode)
    self.machine:set_constants(constants)
    self.machine.pc = 1
end

function VMInterpreter:execute(bytecode, constants)
    self:load(bytecode, constants)
    self.machine.running = true
    
    while self.machine.running and self.machine.pc <= #bytecode do
        if self.debug_mode then
            print("PC: " .. self.machine.pc .. " | Stack size: " .. self.machine:stack_size())
        end
        
        local opcode = self.machine:read_byte()
        
        if not self:dispatch(opcode) then
            break
        end
    end
    
    self.machine.running = false
    return self.machine.return_value
end

function VMInterpreter:dispatch(opcode)
    if opcode == 0x01 then
        -- LOAD_CONST
        local const_idx = self.machine:read_int16()
        self.machine:load_const(const_idx)
    
    elseif opcode == 0x02 then
        -- LOAD_VAR
        local var_idx = self.machine:read_int16()
        self.machine:load_var(var_idx)
    
    elseif opcode == 0x03 then
        -- STORE_VAR
        local var_idx = self.machine:read_int16()
        local value = self.machine:pop()
        self.machine:store_var(var_idx, value)
    
    elseif opcode == 0x04 then
        -- LOAD_GLOBAL
        local name_idx = self.machine:read_int16()
        local name = self.machine.constants[name_idx]
        self.machine:load_global(name)
    
    elseif opcode == 0x05 then
        -- STORE_GLOBAL
        local name_idx = self.machine:read_int16()
        local name = self.machine.constants[name_idx]
        local value = self.machine:pop()
        self.machine:store_global(name, value)
    
    elseif opcode == 0x10 then
        -- ADD
        self.machine:op_add()
    
    elseif opcode == 0x11 then
        -- SUB
        self.machine:op_sub()
    
    elseif opcode == 0x12 then
        -- MUL
        self.machine:op_mul()
    
    elseif opcode == 0x13 then
        -- DIV
        self.machine:op_div()
    
    elseif opcode == 0x14 then
        -- MOD
        self.machine:op_mod()
    
    elseif opcode == 0x15 then
        -- POW
        self.machine:op_pow()
    
    elseif opcode == 0x20 then
        -- EQ
        self.machine:op_eq()
    
    elseif opcode == 0x21 then
        -- NEQ
        self.machine:op_neq()
    
    elseif opcode == 0x22 then
        -- LT
        self.machine:op_lt()
    
    elseif opcode == 0x23 then
        -- GT
        self.machine:op_gt()
    
    elseif opcode == 0x24 then
        -- LTE
        self.machine:op_lte()
    
    elseif opcode == 0x25 then
        -- GTE
        self.machine:op_gte()
    
    elseif opcode == 0x30 then
        -- AND
        self.machine:op_and()
    
    elseif opcode == 0x31 then
        -- OR
        self.machine:op_or()
    
    elseif opcode == 0x32 then
        -- NOT
        self.machine:op_not()
    
    elseif opcode == 0x40 then
        -- JMP
        local target = self.machine:read_int16()
        self.machine:jump(target)
    
    elseif opcode == 0x41 then
        -- JMP_IF_TRUE
        local target = self.machine:read_int16()
        local cond = self.machine:pop()
        if cond then
            self.machine:jump(target)
        end
    
    elseif opcode == 0x42 then
        -- JMP_IF_FALSE
        local target = self.machine:read_int16()
        local cond = self.machine:pop()
        if not cond then
            self.machine:jump(target)
        end
    
    elseif opcode == 0x50 then
        -- CALL
        local arg_count = self.machine:read_byte()
        local args = self.machine:pop_n(arg_count)
        local func = self.machine:pop()
        
        if type(func) == "function" then
            local results = {func(unpack(args))}
            self.machine:push_n(results)
        else
            error("Cannot call non-function")
        end
    
    elseif opcode == 0x51 then
        -- RETURN
        local return_val = self.machine:pop()
        self.machine.return_value = return_val
        self.machine:halt()
        return false
    
    elseif opcode == 0x60 then
        -- MAKE_TABLE
        self.machine:op_make_table()
    
    elseif opcode == 0x61 then
        -- TABLE_SET
        self.machine:op_table_set()
    
    elseif opcode == 0x62 then
        -- TABLE_GET
        self.machine:op_table_get()
    
    elseif opcode == 0x70 then
        -- CONCAT
        self.machine:op_concat()
    
    elseif opcode == 0x71 then
        -- STRLEN
        self.machine:op_strlen()
    
    elseif opcode == 0xFF then
        -- NOP / END
        self.machine:halt()
        return false
    
    else
        error("Unknown opcode: " .. string.format("0x%02X", opcode))
    end
    
    return true
end

function VMInterpreter:set_debug(enabled)
    self.debug_mode = enabled
end

return VMInterpreter