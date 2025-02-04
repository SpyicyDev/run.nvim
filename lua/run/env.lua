local M = {}

-- Process environment variables, handling static, dynamic, and conditional values
M.process_env = function(env_config)
    local env = {}
    
    if not env_config then
        return env
    end

    -- Handle different types of environment variables
    for key, value in pairs(env_config) do
        -- Function that returns value
        if type(value) == "function" then
            local success, result = pcall(value)
            if success and result then
                env[key] = tostring(result)
            end
        -- Table with condition and value
        elseif type(value) == "table" and value.condition then
            local should_set = true
            if type(value.condition) == "function" then
                local success, result = pcall(value.condition)
                should_set = success and result
            end
            if should_set and value.value then
                env[key] = tostring(value.value)
            end
        -- Direct value
        else
            env[key] = tostring(value)
        end
    end

    return env
end

-- Format environment variables for shell execution
M.format_env_for_shell = function(env)
    local commands = {}
    for k, v in pairs(env) do
        -- Escape value for shell
        local escaped_value = vim.fn.shellescape(v)
        table.insert(commands, string.format("export %s=%s", k, escaped_value))
    end
    return commands
end

-- Get environment prompt configuration
M.get_env_prompt = function(prompt_config)
    local env = {}
    
    if not prompt_config then
        return env
    end

    for key, config in pairs(prompt_config) do
        -- Skip if environment variable is already set
        if vim.env[key] and not config.force then
            goto continue
        end

        local value = vim.fn.input({
            prompt = string.format("%s%s: ", 
                config.description or key,
                config.required and " (required)" or ""
            ),
            default = config.default or "",
            completion = config.completion,
        })

        -- Handle required fields
        if config.required and (value == nil or value == "") then
            vim.notify(string.format("Environment variable %s is required", key),
                vim.log.levels.ERROR,
                { title = "run.nvim" }
            )
            return nil
        end

        -- Validate if needed
        if config.validate and value ~= "" then
            local valid = config.validate(value)
            if not valid then
                vim.notify(string.format("Invalid value for %s", key),
                    vim.log.levels.ERROR,
                    { title = "run.nvim" }
                )
                return nil
            end
        end

        if value and value ~= "" then
            env[key] = value
        end

        ::continue::
    end

    return env
end

return M
