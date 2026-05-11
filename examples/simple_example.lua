-- ============================================
-- EXAMPLE: Simple Obfuscation
-- ============================================
-- Basic usage example

local Obfuscator = require(script.Parent.src.main)

-- Example 1: Simple arithmetic
local example1 = [[
local function add(a, b)
    return a + b
end

local result = add(10, 20)
print(result)
]]

print("=== EXAMPLE 1: Simple Function ===")
print("Original code:")
print(example1)
print("\nObfuscating...")
local obfuscated1 = Obfuscator.obfuscate(example1, {
    obfuscation_level = "high",
    vm_enabled = true,
    string_encryption = true,
    identifier_mangling = true,
    constant_obfuscation = true,
    control_flow_flattening = true,
    seed = 0, -- Random
})
print("\nObfuscated code (first 500 chars):")
print(obfuscated1:sub(1, 500) .. "...")

-- Example 2: With string encryption
local example2 = [[
local name = "John"
local age = 25
print("Hello, " .. name)
print("Age: " .. age)
]]

print("\n=== EXAMPLE 2: String Encryption ===")
print("Original code:")
print(example2)
print("\nObfuscating...")
local obfuscated2 = Obfuscator.obfuscate(example2, {
    obfuscation_level = "maximum",
    string_encryption = true,
    seed = 54321,
})
print("\nObfuscated (first 300 chars):")
print(obfuscated2:sub(1, 300) .. "...")

print("\n✅ Examples complete!")