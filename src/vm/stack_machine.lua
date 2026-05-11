-- ============================================
-- STACK MACHINE: VM State Management
-- ============================================
-- Core VM execution engine with stack, memory, and call frames

local StackMachine = {}
StackMachine.__index = StackMachine

function StackMachine.new()
    local self = setmetatable({}, StackMachine)
    
    -- Execution state
    self.stack = {}              -- Value stack
    self.call_stack = {}         -- Function call frames
    self.pc = 0                  -- Program counter
    self.bytecode = nil          -- Current bytecode
    self.constants = {}          -- Constant pool
    
    -- Memory management
    self.globals = {}            -- Global variables
    self.locals = {}             -- Local variable stack
    self.upvalues = {}           -- Captured variables (closures)
    
    -- Execution flags
    self.running = false
    self.halted = false
    self.return_value = nil
    
    return self
end

-- ============ STACK OPERATIONS ============

function StackMachine:push(value)
    table.insert(self.stack, value)
end

function StackMachine:pop()
    if #self.stack == 0 then
        error("Stack underflow")
    end
    return table.remove(self.stack)
end

function StackMachine:peek(offset)
    offset = offset or 0
    local pos = #self.stack - offset
    if pos < 1 then
        error("Stack access out of bounds")
    end
    return self.stack[pos]
end

function StackMachine:pop_n(n)
    local values = {}
    for i = 1, n do
        table.insert(values, 1, self:pop())
    end
    return values
end

function StackMachine:push_n(values)
    for _, v in ipairs(values) do
        self:push(v)
    end
end

function StackMachine:stack_size()
    return #self.stack
end

function StackMachine:clear_stack()
    self.stack = {}
end

-- ============ VARIABLE OPERATIONS ============

function StackMachine:load_var(var_index)
    if not self.locals[var_index] then
        error("Undefined local variable at index " .. var_index)
    end
    self:push(self.locals[var_index])
end

function StackMachine:store_var(var_index, value)
    self.locals[var_index] = value
end

function StackMachine:load_global(var_name)
    local value = self.globals[var_name]
    if value == nil then
        -- Try Roblox globals
        value = _G[var_name]
    end
    self:push(value)
end

function StackMachine:store_global(var_name, value)
    self.globals[var_name] = value
end

-- ============ CONSTANT POOL ============

function StackMachine:load_const(const_index)
    if not self.constants[const_index] then
        error("Invalid constant index: " .. const_index)
    end
    self:push(self.constants[const_index])
end

function StackMachine:set_constants(constants)
    self.constants = constants
end

-- ============ CALL FRAME MANAGEMENT ============

function StackMachine:push_frame(function_ptr, arg_count, local_count)
    table.insert(self.call_stack, {
        function_ptr = function_ptr,
        return_pc = self.pc,
        arg_count = arg_count,
        local_count = local_count,
        local_base = #self.locals,
        stack_base = #self.stack,
    })
end

function StackMachine:pop_frame()
    if #self.call_stack == 0 then
        error("Call stack underflow")
    end
    return table.remove(self.call_stack)
end

function StackMachine:current_frame()
    return self.call_stack[#self.call_stack]
end

function StackMachine:frame_count()
    return #self.call_stack
end

-- ============ PROGRAM COUNTER ============

function StackMachine:set_pc(address)
    self.pc = address
end

function StackMachine:get_pc()
    return self.pc
end

function StackMachine:advance_pc()
    self.pc = self.pc + 1
end

function StackMachine:jump(target_pc)
    self.pc = target_pc
end

-- ============ BYTECODE EXECUTION ============

function StackMachine:set_bytecode(bytecode)
    self.bytecode = bytecode
end

function StackMachine:read_byte()
    if self.pc > #self.bytecode then
        error("PC out of bounds")
    end
    local byte = self.bytecode:byte(self.pc)
    self.pc = self.pc + 1
    return byte
end

function StackMachine:read_bytes(n)
    local bytes = {}
    for i = 1, n do
        table.insert(bytes, self:read_byte())
    end
    return bytes
end

function StackMachine:read_int32()
    local b1 = self:read_byte()
    local b2 = self:read_byte()
    local b3 = self:read_byte()
    local b4 = self:read_byte()
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

function StackMachine:read_int16()
    local b1 = self:read_byte()
    local b2 = self:read_byte()
    return b1 + (b2 * 256)
end

-- ============ CLOSURE & UPVALUE HANDLING ============

function StackMachine:create_closure(function_code, upvalues)
    return {
        type = "closure",
        code = function_code,
        upvalues = upvalues or {},
    }
end

function StackMachine:call_closure(closure, args)
    if type(closure) == "function" then
        return closure(unpack(args or {}))
    elseif type(closure) == "table" and closure.type == "closure" then
        -- VM function call
        self:push_frame(closure.code, #(args or {}), 0)
        for _, arg in ipairs(args or {}) do
            self:push(arg)
        end
        return self:execute(closure.code)
    else
        error("Cannot call non-function value")
    end
end

-- ============ ARITHMETIC OPERATIONS ============

function StackMachine:op_add()
    local b = self:pop()
    local a = self:pop()
    self:push(a + b)
end

function StackMachine:op_sub()
    local b = self:pop()
    local a = self:pop()
    self:push(a - b)
end

function StackMachine:op_mul()
    local b = self:pop()
    local a = self:pop()
    self:push(a * b)
end

function StackMachine:op_div()
    local b = self:pop()
    local a = self:pop()
    if b == 0 then
        error("Division by zero")
    end
    self:push(a / b)
end

function StackMachine:op_mod()
    local b = self:pop()
    local a = self:pop()
    self:push(a % b)
end

function StackMachine:op_pow()
    local b = self:pop()
    local a = self:pop()
    self:push(a ^ b)
end

function StackMachine:op_concat()
    local b = self:pop()
    local a = self:pop()
    self:push(tostring(a) .. tostring(b))
end

-- ============ COMPARISON OPERATIONS ============

function StackMachine:op_eq()
    local b = self:pop()
    local a = self:pop()
    self:push(a == b)
end

function StackMachine:op_neq()
    local b = self:pop()
    local a = self:pop()
    self:push(a ~= b)
end

function StackMachine:op_lt()
    local b = self:pop()
    local a = self:pop()
    self:push(a < b)
end

function StackMachine:op_gt()
    local b = self:pop()
    local a = self:pop()
    self:push(a > b)
end

function StackMachine:op_lte()
    local b = self:pop()
    local a = self:pop()
    self:push(a <= b)
end

function StackMachine:op_gte()
    local b = self:pop()
    local a = self:pop()
    self:push(a >= b)
end

-- ============ LOGICAL OPERATIONS ============

function StackMachine:op_and()
    local b = self:pop()
    local a = self:pop()
    self:push(a and b)
end

function StackMachine:op_or()
    local b = self:pop()
    local a = self:pop()
    self:push(a or b)
end

function StackMachine:op_not()
    local a = self:pop()
    self:push(not a)
end

-- ============ TABLE OPERATIONS ============

function StackMachine:op_make_table()
    self:push({})
end

function StackMachine:op_table_set()
    local value = self:pop()
    local key = self:pop()
    local table_val = self:pop()
    table_val[key] = value
    self:push(table_val)
end

function StackMachine:op_table_get()
    local key = self:pop()
    local table_val = self:pop()
    self:push(table_val[key])
end

-- ============ STRING OPERATIONS ============

function StackMachine:op_strlen()
    local str = self:pop()
    self:push(#tostring(str))
end

-- ============ EXECUTION STATE ============

function StackMachine:is_running()
    return self.running
end

function StackMachine:halt()
    self.halted = true
    self.running = false
end

function StackMachine:reset()
    self.stack = {}
    self.call_stack = {}
    self.pc = 0
    self.running = false
    self.halted = false
    self.return_value = nil
end

return StackMachine