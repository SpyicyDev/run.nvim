local M = {}

local notify = require("run.utils.notify").notify

-- Evaluate a single environment variable value
local function evaluate_env_value(value)
    if type(value) == "function" then
        local success, result = pcall(value)
        if success then
            return result
        end
        notify("Error evaluating environment variable function: " .. tostring(result), vim.log.levels.ERROR)
        return nil
    end
    return value
end

-- Evaluate a conditional environment variable
local function evaluate_conditional_env(condition, value)
    if type(condition) == "function" then
        local success, result = pcall(condition)
        if not success then
            notify("Error evaluating condition function: " .. tostring(result), vim.log.levels.ERROR)
            return nil
        end
        if result then
            return evaluate_env_value(value)
        end
        return nil
    end
    return evaluate_env_value(value)
end

-- Process environment variables configuration
M.process_env = function(env_config)
    if not env_config then
        return nil
    end

    local processed_env = {}
    for key, value in pairs(env_config) do
        if type(value) == "table" and value.when and value.value then
            -- Handle conditional environment variables
            local env_value = evaluate_conditional_env(value.when, value.value)
            if env_value ~= nil then
                processed_env[key] = env_value
            end
        else
            -- Handle regular environment variables (static or dynamic)
            local env_value = evaluate_env_value(value)
            if env_value ~= nil then
                processed_env[key] = env_value
            end
        end
    end

    return next(processed_env) and processed_env or nil
end

-- Merge environment variables with system environment
M.merge_with_system_env = function(env_vars)
    if not env_vars then
        return nil
    end

    local merged_env = {}
    -- Copy current environment
    for k, v in pairs(vim.loop.os_environ()) do
        merged_env[k] = v
    end
    -- Override with custom environment variables
    for k, v in pairs(env_vars) do
        merged_env[k] = tostring(v)
    end

    return merged_env
end

return M
