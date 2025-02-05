local M = {}

-- Import required modules
local notify = require("run.utils.notify").notify
local env = require("run.utils.env")
local validation = require("run.utils.validation")

-- Process file path substitutions and validate command
local function preprocess_cmd(cmd)
    if not validation.validate_cmd(cmd) then return nil end

    if string.find(cmd, "%%f") then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if not buf_name or buf_name == "" then
            notify("No buffer name available for %f substitution", vim.log.levels.ERROR)
            return nil
        end
        return string.gsub(cmd, "%%f", buf_name)
    end
    return cmd
end

-- Execute a command with environment variables
local function execute_cmd(cmd, env_vars)
    local term = require("FTerm")
    if not term then
        notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR)
        return false
    end
    
    -- Merge environment variables with system environment
    local merged_env = env.merge_with_system_env(env_vars)
    
    term.scratch({ 
        cmd = cmd,
        env = merged_env
    })
    return true
end

-- Format command with preprocessing
M.fmt_cmd = function(cmd)
    return preprocess_cmd(cmd)
end

-- Execute a single command
M.execute_single_cmd = function(cmd, env_vars)
    return execute_cmd(cmd, env_vars)
end

-- Build a shell command with error handling
local function build_shell_command(cmd, continue_on_error)
    if type(cmd) ~= "string" then return nil end
    
    -- Handle Vim commands
    if cmd:sub(1, 1) == ":" then
        local vim_cmd = cmd:sub(2) -- Remove the leading ":"
        -- Convert vim command to shell command using nvim --headless
        return string.format("nvim --headless -c '%s' -c 'q'", vim_cmd)
    end
    
    -- Handle shell commands
    local error_check = continue_on_error and "|| true" or ""
    return cmd .. " " .. error_check
end

-- Process command section and execute
M.run_cmd = function(cmd_section)
    if not cmd_section then
        notify("Command section is nil", vim.log.levels.ERROR)
        return false
    end

    local config = require("run.config")
    if not config.proj or not config.proj[cmd_section] then
        notify("Command section not found in project configuration", vim.log.levels.ERROR)
        return false
    end

    local cmd_config = config.proj[cmd_section]
    local cmd = cmd_config.cmd

    -- Handle command chains
    if type(cmd) == "table" and #cmd > 0 then
        return M.run_command_chain(cmd, cmd_section)
    end

    -- Handle function commands
    if type(cmd) == "function" then
        local success, result = pcall(cmd)
        if not success then
            notify("Error executing command function: " .. tostring(result), vim.log.levels.ERROR)
            return false
        end
        cmd = result
        if cmd == nil then return true end
    end

    -- Process and validate command
    cmd = M.fmt_cmd(cmd)
    if not cmd then return false end

    -- Process environment variables and execute
    local processed_env = env.process_env(cmd_config.env)
    return M.execute_single_cmd(cmd, processed_env)
end

-- Execute a command chain
M.run_command_chain = function(commands, cmd_section)
    if not commands or #commands == 0 then
        notify("No commands to execute in chain", vim.log.levels.ERROR)
        return false
    end

    -- Get environment variables from the run configuration
    local config = require("run.config")
    local processed_env = nil
    if config.proj and config.proj[cmd_section] and config.proj[cmd_section].env then
        processed_env = env.process_env(config.proj[cmd_section].env)
    end

    -- Extract callbacks if they exist
    local callbacks = {}
    for i = #commands, 1, -1 do
        local cmd = commands[i]
        if type(cmd) == "table" then
            if cmd.on_success then
                callbacks.on_success = cmd.on_success
                table.remove(commands, i)
            elseif cmd.on_error then
                callbacks.on_error = cmd.on_error
                table.remove(commands, i)
            end
        end
    end

    -- Process each command
    local command_parts = {}
    local success = true

    for _, cmd in ipairs(commands) do
        -- Skip if condition not met
        if type(cmd) == "table" and cmd.when and not cmd.when() then
            goto continue
        end

        -- Handle wait conditions
        if type(cmd) == "table" and cmd.wait_for then
            local start_time = vim.loop.now()
            while not cmd.wait_for() do
                if vim.loop.now() - start_time > 5000 then
                    notify("Timeout waiting for condition", vim.log.levels.ERROR)
                    return false
                end
                vim.loop.sleep(100)
            end
        end

        -- Process the command
        local current_cmd = type(cmd) == "table" and cmd.cmd or cmd
        if type(current_cmd) == "function" then
            local success, result = pcall(current_cmd)
            if not success then
                notify("Error executing command function: " .. tostring(result), vim.log.levels.ERROR)
                if not (type(cmd) == "table" and cmd.continue_on_error) then
                    return false
                end
                goto continue
            end
            if result == nil then goto continue end
            current_cmd = result
        end

        current_cmd = M.fmt_cmd(current_cmd)
        if not current_cmd then goto continue end

        -- Build shell command with error handling
        local shell_cmd = build_shell_command(current_cmd, type(cmd) == "table" and cmd.continue_on_error)
        if not shell_cmd then goto continue end

        -- Add command to chain based on always_run flag
        if type(cmd) == "table" and cmd.always_run then
            -- Commands that should always run are added with true || command
            table.insert(command_parts, "true || " .. shell_cmd)
        else
            table.insert(command_parts, shell_cmd)
        end

        ::continue::
    end

    -- If we have commands to run, execute them in a single FTerm instance
    if #command_parts > 0 then
        -- Join commands with && to ensure proper execution order
        local combined_cmd = table.concat(command_parts, " && ")
        success = execute_cmd(combined_cmd, processed_env)
    end

    -- Handle callbacks
    if success and callbacks.on_success then
        callbacks.on_success()
    elseif not success and callbacks.on_error then
        callbacks.on_error()
    end

    return success
end

return M
