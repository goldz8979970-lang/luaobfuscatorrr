-- ============================================
-- STRING OBFUSCATOR: Encrypt string literals
-- ============================================
-- XOR encryption + dynamic decryption for strings

local StringObfuscator = {}
StringObfuscator.__index = StringObfuscator

function StringObfuscator.new(seed)
    local self = setmetatable({}, StringObfuscator)
    self.seed = seed or math.random(1, 2147483647)
    self.encrypted_strings = {}
    self.decryption_key = self:generate_key()
    return self
end

function StringObfuscator:generate_key()
    math.randomseed(self.seed)
    local key = {}
    for i = 1, 32 do
        table.insert(key, math.random(0, 255))
    end
    return key
end

function StringObfuscator:xor_encrypt(str)
    local encrypted = {}
    for i = 1, #str do
        local char = str:byte(i)
        local key_byte = self.decryption_key[(i % #self.decryption_key) + 1]
        table.insert(encrypted, char ~ key_byte)
    end
    return encrypted
end

function StringObfuscator:xor_decrypt(encrypted, key)
    local decrypted = ""
    for i = 1, #encrypted do
        local key_byte = key[(i % #key) + 1]
        local char = encrypted[i] ~ key_byte
        decrypted = decrypted .. string.char(char)
    end
    return decrypted
end

function StringObfuscator:obfuscate_string(str)
    local encrypted = self:xor_encrypt(str)
    local id = #self.encrypted_strings + 1
    self.encrypted_strings[id] = encrypted
    return id
end

function StringObfuscator:get_encrypted_strings()
    return self.encrypted_strings
end

function StringObfuscator:generate_runtime_decryptor()
    return [[
local _decrypted_strings = {}
local _string_key = {]] .. table.concat(self.decryption_key, ",") .. [[}
local function _decrypt_string(encrypted_id, encrypted_bytes)
    if _decrypted_strings[encrypted_id] then
        return _decrypted_strings[encrypted_id]
    end
    local decrypted = ""
    for i = 1, #encrypted_bytes do
        local key_byte = _string_key[(i % #_string_key) + 1]
        local char = encrypted_bytes[i] ~ key_byte
        decrypted = decrypted .. string.char(char)
    end
    _decrypted_strings[encrypted_id] = decrypted
    return decrypted
end
]]
end

return StringObfuscator