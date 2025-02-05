local M = {}

local notify = require("run.utils.notify").notify

---Validate an environment variable value
---@param value any The value to validate
---@return boolean is_valid Whether the value is valid
---@return string|nil error_message Error message if invalid
local function validate_env_value(value)
    if type(value) == "string" then
        return true, nil
    elseif type(value) == "function" then
        return true, nil
    elseif type(value) == "number" then
        return true, nil
    elseif value == nil then
        return false, "Environment variable value cannot be nil"
    else
        return false, string.format("Invalid environment variable type: %s", type(value))
    end
end

---Convert a value to a string suitable for an environment variable
---@param value any The value to convert
---@return string|nil The converted string or nil if invalid
local function to_env_string(value)
    if type(value) == "string" then
        return value
    elseif type(value) == "number" then
        return tostring(value)
    end
    return nil
end

---Process a single environment variable
---@param key string The environment variable key
---@param value string|function|number The environment variable value or function
---@return string|nil processed_value The processed value or nil if invalid
local function process_single_env(key, value)
    -- Handle function values
    if type(value) == "function" then
        local success, result = pcall(value)
        if not success then
            notify(string.format("Error evaluating environment variable %s: %s", key, result), vim.log.levels.ERROR)
            return nil
        end
        
        -- Validate function return value
        local is_valid, error_msg = validate_env_value(result)
        if not is_valid then
            notify(string.format("Invalid return value for environment variable %s: %s", key, error_msg), vim.log.levels.ERROR)
            return nil
        end
        
        value = result
    end
    
    -- Convert to string
    local str_value = to_env_string(value)
    if not str_value then
        notify(string.format("Could not convert environment variable %s to string", key), vim.log.levels.ERROR)
        return nil
    end
    
    return str_value
end

---Process environment variables configuration
---@param env_config table|nil The environment configuration to process
---@return table processed_env The processed environment variables
M.process_env = function(env_config)
    local result = {}
    
    -- Return empty table if no config
    if not env_config then
        return result
    end
    
    -- Validate config type
    if type(env_config) ~= "table" then
        notify("Environment configuration must be a table", vim.log.levels.ERROR)
        return result
    end
    
    -- Process each environment variable
    for key, value in pairs(env_config) do
        -- Validate key
        if type(key) ~= "string" then
            notify(string.format("Environment variable key must be a string, got %s", type(key)), vim.log.levels.ERROR)
            goto continue
        end
        
        -- Validate value
        local is_valid, error_msg = validate_env_value(value)
        if not is_valid then
            notify(string.format("Invalid environment variable %s: %s", key, error_msg), vim.log.levels.ERROR)
            goto continue
        end
        
        -- Process value
        local processed_value = process_single_env(key, value)
        if processed_value then
            result[key] = processed_value
        end
        
        ::continue::
    end
    
    return result
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
