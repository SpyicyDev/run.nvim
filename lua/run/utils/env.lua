local M = {}

local error = require("run.utils.error")

---Validate environment variable value
---@param value any The value to validate
---@param name string The name of the environment variable
---@return boolean is_valid Whether the value is valid
local function validate_env_value(value, name)
    local value_type = type(value)
    
    if value_type == "string" or value_type == "number" then
        return true
    end
    
    if value_type == "function" then
        local ok, result = pcall(value)
        if not ok then
            error.env_error("Environment variable function failed", {
                name = name,
                details = result
            })
            return false
        end
        
        if type(result) ~= "string" and type(result) ~= "number" then
            error.validation_error("Environment variable function must return string or number", {
                name = name,
                got = type(result)
            })
            return false
        end
        
        return true
    end
    
    error.validation_error("Invalid environment variable type", {
        name = name,
        expected = "string, number, or function",
        got = value_type
    })
    return false
end

---Convert value to string
---@param value any The value to convert
---@return string|nil result The converted string or nil if conversion failed
local function to_string(value)
    if type(value) == "function" then
        local ok, result = pcall(value)
        if not ok then
            error.env_error("Failed to evaluate environment variable function", {
                details = result
            })
            return nil
        end
        value = result
    end
    
    return tostring(value)
end

---Process environment variables
---@param env_config table|nil The environment configuration
---@return table|nil env_vars The processed environment variables or nil if processing failed
function M.process_env(env_config)
    -- Return empty table if no environment config
    if not env_config then
        return {}
    end
    
    -- Validate env_config is a table
    if type(env_config) ~= "table" then
        error.validation_error("Environment configuration must be a table", {
            got = type(env_config)
        })
        return nil
    end
    
    local env_vars = {}
    
    -- Process each environment variable
    for name, value in pairs(env_config) do
        -- Validate value
        if not validate_env_value(value, name) then
            return nil
        end
        
        -- Convert to string
        local str_value = to_string(value)
        if not str_value then
            return nil
        end
        
        env_vars[name] = str_value
    end
    
    return env_vars
end

---Merge environment variables with system environment
---@param env_vars table|nil The environment variables to merge
---@return table merged_env The merged environment variables
M.merge_with_system_env = function(env_vars)
    local result = {}
    
    -- Copy system environment
    for key, value in pairs(vim.loop.os_environ()) do
        result[key] = value
    end
    
    -- Merge custom environment
    if env_vars then
        for key, value in pairs(env_vars) do
            result[key] = value
        end
    end
    
    return result
end

return M
