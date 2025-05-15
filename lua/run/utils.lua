-- Consolidated utilities module for run.nvim
local M = {}

-- Notification utility
---Display a notification with the run.nvim title
---@param msg string The message to display
---@param level number|nil The notification level (defaults to INFO)
---@return nil
M.notify = function(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "run.nvim" })
end

-- Command utilities ----------------------------------------------------------

---Validate command input
---@param cmd any The command to validate
---@return boolean is_valid Whether the command is valid
local function validate_cmd(cmd)
    if not cmd then
        M.notify("Command is nil", vim.log.levels.ERROR)
        return false
    end
    if type(cmd) ~= "string" then
        M.notify("Command must be a string", vim.log.levels.ERROR)
        return false
    end
    return true
end

---Process file path substitutions and validate command
---@param cmd string The command to process
---@return string|nil processed_cmd The processed command or nil if invalid
local function preprocess_cmd(cmd)
    if not validate_cmd(cmd) then 
        return nil 
    end

    if string.find(cmd, "%%f") then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if not buf_name or buf_name == "" then
            M.notify("No buffer name available for %f substitution", vim.log.levels.ERROR)
            return nil
        end
        local processed = string.gsub(cmd, "%%f", buf_name)
        return processed
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
        M.notify("Error executing vim command: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    return true
end

---Execute a shell command
---@param cmd string The shell command to execute
---@return boolean success Whether the command started successfully
local function execute_shell_cmd(cmd)
    local term = require("FTerm")
    if not term then
        M.notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR)
        return false
    end
    
    -- Execute in a single terminal instance
    local success, err = pcall(term.scratch, { 
        cmd = cmd,
        auto_close = false -- Keep terminal open for visibility
    })
    
    if not success then
        M.notify("Error starting terminal command: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    
    return true
end

---Format and validate a command string
---@param cmd string The command string to format
---@return string|nil formatted_cmd The formatted command or nil if invalid
M.fmt_cmd = function(cmd)
    local ret_cmd = preprocess_cmd(cmd)
    if not ret_cmd then return nil end
    return ret_cmd
end

---Execute a single command
---@param cmd string The command to execute
---@return boolean success Whether the command executed successfully
M.execute_cmd = function(cmd)
    if cmd:sub(1, 1) == ":" then
        return execute_vim_cmd(cmd)
    end
    return execute_shell_cmd(cmd)
end

---Execute a command from the project configuration
---@param cmd_section string The command section to execute
---@return boolean success Whether the command executed successfully
M.run_cmd = function(cmd_section)
    if not cmd_section then
        M.notify("Command section is nil", vim.log.levels.ERROR)
        return false
    end

    local config = require("run.config")
    if not config.proj or not config.proj[cmd_section] then
        M.notify("Command section not found in project configuration", vim.log.levels.ERROR)
        return false
    end

    local cmd_config = config.proj[cmd_section]
    local cmd = cmd_config.cmd

    -- No longer support table commands
    if type(cmd) == "table" then
        M.notify("Command chains are no longer supported", vim.log.levels.ERROR)
        return false
    end

    -- Handle function commands
    if type(cmd) == "function" then
        local success, result = pcall(cmd)
        if not success then
            M.notify("Error executing command function: " .. tostring(result), vim.log.levels.ERROR)
            return false
        end
        cmd = result
        if cmd == nil then return true end
    end

    -- Process and validate command
    cmd = M.fmt_cmd(cmd)
    if not cmd then return false end

    -- Execute the command
    return M.execute_cmd(cmd)
end

-- Path utilities -------------------------------------------------------------

---Write the current project configuration to the run.nvim.lua file
---@return nil
M.write_conf = function()
    local config = require("run.config")
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    if not proj_file or proj_file == "" then
        M.notify("Could not find run.nvim.lua file", vim.log.levels.ERROR)
        return
    end

    local file = io.open(proj_file, "w")
    if not file then
        M.notify("Could not open run.nvim.lua for writing", vim.log.levels.ERROR)
        return
    end

    if not config.proj then
        M.notify("Project configuration is nil", vim.log.levels.ERROR)
        file:close()
        return
    end

    local inspect = require("inspect")
    if not inspect then
        M.notify("Could not load inspect module", vim.log.levels.ERROR)
        file:close()
        return
    end

    local conf_string = inspect.inspect(config.proj)
    conf_string = "return " .. conf_string

    local success, err = pcall(function()
        file:write(conf_string)
        file:close()
    end)

    if not success then
        M.notify("Error writing configuration: " .. tostring(err), vim.log.levels.ERROR)
    end
end

-- Configuration validation utilities -----------------------------------------

-- Valid options for different configuration types
local VALID_COMMAND_OPTIONS = {
    name = true,
    cmd = true,
    filetype = true
}

-- Schema validation helper functions
local function is_string(value)
    return type(value) == "string"
end

local function is_function(value)
    return type(value) == "function"
end

local function is_table(value)
    return type(value) == "table"
end

local function validate_command_entry(command_id, command)
    if not command.name or not is_string(command.name) then
        return false, string.format("Command '%s' must have a string 'name' field", command_id)
    end

    if not command.cmd then
        return false, string.format("Command '%s' must have a 'cmd' field", command_id)
    end

    -- Check for invalid options in command entry
    for key, _ in pairs(command) do
        if not VALID_COMMAND_OPTIONS[key] then
            return false, string.format("Command '%s' contains invalid option '%s'", command_id, key)
        end
    end

    -- Validate cmd field (can be string or function)
    if not (is_string(command.cmd) or is_function(command.cmd)) then
        return false, string.format("Command '%s' 'cmd' field must be a string or function", command_id)
    end

    -- Validate optional fields
    if command.filetype and not is_string(command.filetype) then
        return false, string.format("Command '%s' 'filetype' must be a string", command_id)
    end

    return true, nil
end

--- Validate the run.nvim.lua configuration file
---@param config table The configuration table from run.nvim.lua
---@return boolean is_valid Whether the configuration is valid
---@return string|nil error_message Error message if validation fails
M.validate_config = function(config)
    if not is_table(config) then
        return false, "Configuration must be a table"
    end

    -- Validate each command entry
    for command_id, command in pairs(config) do
        if command_id == "default" then
            -- Validate default command reference
            if not is_string(command) then
                return false, "'default' must be a string referencing a command ID"
            end
            if not config[command] then
                return false, string.format("Default command '%s' does not exist", command)
            end
        else
            -- Validate command entry
            local is_valid, error_msg = validate_command_entry(command_id, command)
            if not is_valid then
                return false, error_msg
            end
        end
    end

    return true, nil
end

return M