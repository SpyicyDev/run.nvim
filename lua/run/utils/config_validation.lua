local M = {}

-- Valid options for different configuration types
local VALID_COMMAND_OPTIONS = {
    name = true,
    cmd = true,
    filetype = true,
    env = true
}

local VALID_CHAIN_COMMAND_OPTIONS = {
    cmd = true,
    continue_on_error = true,
    when = true,
    always_run = true
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

local function is_boolean(value)
    return type(value) == "boolean"
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

    -- Validate cmd field (can be string, function, or table for command chains)
    if not (is_string(command.cmd) or is_function(command.cmd) or is_table(command.cmd)) then
        return false, string.format("Command '%s' 'cmd' field must be a string, function, or table", command_id)
    end

    -- If cmd is a table (command chain), validate each entry
    if is_table(command.cmd) and not vim.tbl_islist(command.cmd) then
        return false, string.format("Command '%s' 'cmd' table must be an array", command_id)
    end

    -- Validate optional fields
    if command.filetype and not is_string(command.filetype) then
        return false, string.format("Command '%s' 'filetype' must be a string", command_id)
    end

    if command.env and not is_table(command.env) then
        return false, string.format("Command '%s' 'env' must be a table", command_id)
    end

    -- If it's a command chain, validate each command in the chain
    if is_table(command.cmd) then
        for i, cmd_entry in ipairs(command.cmd) do
            if is_string(cmd_entry) then
                -- Simple string command is valid
                goto continue
            end

            if not is_table(cmd_entry) then
                return false, string.format("Command '%s' chain entry %d must be a string or table", command_id, i)
            end

            -- Check for invalid options in chain command entry
            for key, _ in pairs(cmd_entry) do
                if not VALID_CHAIN_COMMAND_OPTIONS[key] then
                    return false, string.format("Command '%s' chain entry %d contains invalid option '%s'", command_id, i, key)
                end
            end

            -- Validate command chain entry
            if not (is_string(cmd_entry.cmd) or is_function(cmd_entry.cmd)) then
                return false, string.format("Command '%s' chain entry %d 'cmd' must be a string or function", command_id, i)
            end

            if cmd_entry.continue_on_error and not is_boolean(cmd_entry.continue_on_error) then
                return false, string.format("Command '%s' chain entry %d 'continue_on_error' must be a boolean", command_id, i)
            end

            if cmd_entry.when and not is_function(cmd_entry.when) then
                return false, string.format("Command '%s' chain entry %d 'when' must be a function", command_id, i)
            end

            if cmd_entry.always_run and not is_boolean(cmd_entry.always_run) then
                return false, string.format("Command '%s' chain entry %d 'always_run' must be a boolean", command_id, i)
            end

            ::continue::
        end
    end

    -- Validate environment variables if present
    if command.env then
        for key, value in pairs(command.env) do
            if not (is_string(value) or is_function(value)) then
                return false, string.format("Command '%s' environment variable '%s' must be a string or function", command_id, key)
            end
        end
    end

    return true, nil
end

--- Validate the run.nvim.lua configuration file
---@param config table The configuration table from run.nvim.lua
---@return boolean is_valid Whether the configuration is valid
---@return string|nil error_message Error message if validation fails
function M.validate_config(config)
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
