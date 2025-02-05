local M = {}

-- Import required modules
local notify = require("run.utils.notify").notify
local env = require("run.utils.env")
local validation = require("run.utils.validation")
local error = require("run.utils.error")
local config = require("run.config")
local fterm = require("FTerm")

---Validates a command object in a command chain
---@param cmd table|string The command object or string to validate
---@return boolean is_valid Whether the command is valid
---@return string|nil error_message Error message if invalid
local function validate_command_object(cmd)
    if type(cmd) == "string" then return true, nil end
    if type(cmd) ~= "table" then
        error.validation_error("Command must be a string or table", {
            details = string.format("Got %s: %s", type(cmd), vim.inspect(cmd))
        })
        return false, "Command must be a string or table"
    end
    
    if not cmd.cmd then
        error.validation_error("Command table must have a 'cmd' field", {
            details = vim.inspect(cmd)
        })
        return false, "Command table must have a 'cmd' field"
    end
    
    if cmd.when and type(cmd.when) ~= "function" then
        error.validation_error("Command 'when' must be a function", {
            details = string.format("Got %s: %s", type(cmd.when), vim.inspect(cmd.when))
        })
        return false, "Command 'when' must be a function"
    end
    
    return true, nil
end

---Process file path substitutions and validate command
---@param cmd string The command to process
---@return string|nil processed_cmd The processed command or nil if invalid
local function preprocess_cmd(cmd)
    if not validation.validate_cmd(cmd) then return nil end

    if string.find(cmd, "%%f") then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if not buf_name or buf_name == "" then
            error.validation_error("No buffer name available for %f substitution", {
                details = "Buffer name is empty"
            })
            return nil
        end
        return string.gsub(cmd, "%%f", buf_name)
    end
    return cmd
end

---Execute a Vim command in the current instance
---@param cmd string The Vim command to execute (with leading ":")
---@return boolean success Whether the command executed successfully
local function execute_vim_cmd(cmd)
    -- Remove the leading ":"
    local vim_cmd = cmd:sub(2)
    local success, err = pcall(vim.cmd, vim_cmd)
    if not success then
        error.command_error("Error executing vim command: " .. tostring(err), {
            details = err,
            command = vim_cmd
        })
        return false
    end
    return true
end

---Execute a shell command with environment variables
---@param cmd string The shell command to execute
---@param env_vars table|nil Environment variables for the command
---@return boolean success Whether the command started successfully
local function execute_shell_cmd(cmd, env_vars)
    local term = require("FTerm")
    if not term then
        error.command_error("FTerm not found. Make sure it's installed")
        return false
    end
    
    -- Merge environment variables with system environment
    local merged_env = env.merge_with_system_env(env_vars)
    
    -- Execute in a single terminal instance
    local success, err = pcall(term.scratch, { 
        cmd = cmd,
        env = merged_env,
        auto_close = false -- Keep terminal open for visibility
    })
    
    if not success then
        error.command_error("Error starting terminal command", {
            details = err,
            command = cmd
        })
        return false
    end
    
    return true
end

---Execute a single command of any type
---@param cmd string The command to execute
---@param env_vars table|nil Environment variables for the command
---@return boolean success Whether the command executed successfully
local function execute_single_cmd(cmd, env_vars)
    if type(cmd) ~= "string" then
        error.validation_error("Command must be a string", {
            details = string.format("Got %s: %s", type(cmd), vim.inspect(cmd))
        })
        return false
    end
    
    -- Handle Vim commands
    if cmd:sub(1, 1) == ":" then
        return execute_vim_cmd(cmd)
    end
    
    -- Handle shell commands
    return execute_shell_cmd(cmd, env_vars)
end

---Validate command section
---@param cmd_section table The command section to validate
---@return boolean is_valid Whether the command section is valid
local function validate_cmd_section(cmd_section)
    if not cmd_section then
        error.validation_error("Command section is nil")
        return false
    end
    
    if not cmd_section.cmd then
        error.validation_error("Command section missing 'cmd' field", {
            details = vim.inspect(cmd_section)
        })
        return false
    end
    
    return true
end

---Execute a command in the terminal
---@param cmd string|function The command to execute
---@param env_vars table|nil Environment variables for the command
local function execute_command(cmd, env_vars)
    if type(cmd) == "function" then
        local ok, result = pcall(cmd)
        if not ok then
            error.command_error("Failed to execute command function", {
                details = result
            })
            return
        end
        cmd = result
    end
    
    if type(cmd) ~= "string" then
        error.validation_error("Command must be a string", {
            details = string.format("Got %s: %s", type(cmd), vim.inspect(cmd))
        })
        return
    end
    
    -- Create terminal instance
    local term = fterm:new({
        cmd = cmd,
        env = env_vars,
        auto_close = false
    })
    
    -- Execute command
    local ok, err = pcall(function()
        term:open()
    end)
    
    if not ok then
        error.command_error("Failed to execute command in terminal", {
            details = err,
            command = cmd
        })
    end
end

---Run a command section
---@param cmd_name string The name of the command section to run
function M.run_cmd(cmd_name)
    if not config.proj then
        error.project_error("No project configuration loaded")
        return
    end
    
    local cmd_section = config.proj[cmd_name]
    if not cmd_section then
        error.command_error("Command section not found", {
            details = cmd_name
        })
        return
    end
    
    if not validate_cmd_section(cmd_section) then
        return
    end
    
    -- Process environment variables
    local env_vars = env.process_env(cmd_section.env)
    if not env_vars then
        error.env_error("Failed to process environment variables", {
            command = cmd_name
        })
        return
    end
    
    -- Execute command
    execute_command(cmd_section.cmd, env_vars)
end

---Process command section and execute
---@param cmd_section string The command section to execute
---@return boolean success Whether the command executed successfully
M.run_cmd = function(cmd_section)
    if not cmd_section then
        error.validation_error("Command section is nil")
        return false
    end

    local config = require("run.config")
    if not config.proj or not config.proj[cmd_section] then
        error.command_error("Command section not found in project configuration", {
            details = cmd_section
        })
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
            error.command_error("Error executing command function: " .. tostring(result), {
                details = result
            })
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

---Execute a command chain
---@param commands table The array of commands to execute
---@param cmd_section string The command section name
---@return boolean success Whether all commands executed successfully
M.run_command_chain = function(commands, cmd_section)
    if not commands or #commands == 0 then
        error.validation_error("No commands to execute in chain", {
            details = "Command chain is empty"
        })
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
    local vim_commands = {}
    local shell_commands = {}
    local success = true

    for _, cmd in ipairs(commands) do
        -- Validate command object
        local is_valid, error_msg = validate_command_object(cmd)
        if not is_valid then
            error.validation_error("Invalid command: " .. error_msg, {
                details = vim.inspect(cmd)
            })
            return false
        end

        -- Skip if condition not met
        if type(cmd) == "table" and cmd.when and not cmd.when() then
            goto continue
        end

        -- Process the command
        local current_cmd = type(cmd) == "table" and cmd.cmd or cmd
        if type(current_cmd) == "function" then
            local success, result = pcall(current_cmd)
            if not success then
                error.command_error("Error executing command function: " .. tostring(result), {
                    details = result
                })
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

        -- Separate Vim and shell commands
        if current_cmd:sub(1, 1) == ":" then
            table.insert(vim_commands, {
                cmd = current_cmd,
                continue_on_error = type(cmd) == "table" and cmd.continue_on_error,
                always_run = type(cmd) == "table" and cmd.always_run
            })
        else
            table.insert(shell_commands, {
                cmd = current_cmd,
                continue_on_error = type(cmd) == "table" and cmd.continue_on_error,
                always_run = type(cmd) == "table" and cmd.always_run
            })
        end

        ::continue::
    end

    -- Execute Vim commands first in the current instance
    for _, cmd_info in ipairs(vim_commands) do
        if not success and not cmd_info.always_run then
            goto continue
        end

        local cmd_success = execute_vim_cmd(cmd_info.cmd)
        if not cmd_success and not cmd_info.continue_on_error then
            success = false
        end

        ::continue::
    end

    -- Then execute shell commands in a single FTerm instance
    if success or vim.tbl_any(shell_commands, function(cmd) return cmd.always_run end) then
        -- Join commands with && to ensure proper execution order
        -- Add echo statements to show command execution
        local command_parts = {}
        for _, cmd_info in ipairs(shell_commands) do
            if not success and not cmd_info.always_run then
                goto continue
            end

            -- Add command with proper error handling
            if cmd_info.always_run then
                table.insert(command_parts, "{ " .. cmd_info.cmd .. "; }")
            else
                local error_check = cmd_info.continue_on_error and "|| true" or ""
                table.insert(command_parts, cmd_info.cmd .. " " .. error_check)
            end

            ::continue::
        end

        if #command_parts > 0 then
            -- Add command execution feedback
            local combined_cmd = table.concat(
                vim.tbl_map(function(cmd)
                    return string.format('echo "\\033[1;34m==> Running: %s\\033[0m" && %s', 
                        cmd:gsub('"', '\\"'), cmd)
                end, command_parts),
                " && "
            )
            success = execute_shell_cmd(combined_cmd, processed_env)
        end
    end

    -- Handle callbacks
    if success and callbacks.on_success then
        callbacks.on_success()
    elseif not success and callbacks.on_error then
        callbacks.on_error()
    end

    return success
end

---Format command with preprocessing
---@param cmd string The command to format
---@return string|nil formatted_cmd The formatted command or nil if invalid
M.fmt_cmd = function(cmd)
    return preprocess_cmd(cmd)
end

---Execute a single command
---@param cmd string The command to execute
---@param env_vars table|nil Environment variables for the command
---@return boolean success Whether the command executed successfully
M.execute_single_cmd = function(cmd, env_vars)
    return execute_single_cmd(cmd, env_vars)
end

return M
