-- Main module for run.nvim
local M = {}

local utils = require("run.utils")
local config = require("run.config")

--- Initialize the plugin with the given options
---@param opts table|nil Configuration options for the plugin
M.setup = function(opts)
    if not opts then opts = {} end
    -- initialize all config variables and stuff
    config.setup(opts)

    M.setup_proj()

    -- run setup_proj on DirChanged
    vim.api.nvim_create_autocmd({ "DirChanged" }, {
        desc = "Setup run.nvim.lua on DirChanged",
        callback = function()
            M.setup_proj()
        end
    })

    -- global stuff if proj file exists
    if config.proj_file_exists then
        -- set default command
        vim.api.nvim_create_user_command("RunSetDefault", function()
            M.set_default()
        end, { desc = "Set a Default Script" })
    end

    -- keymaps and user commands that should only be on in an active buffer
    vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
        desc = "Setup run keymap and user command",
        callback = function()
            -- ensure we have valid keys configured
            if not config.opts or not config.opts.keys then
                utils.notify("Missing key configuration", vim.log.levels.ERROR)
                return
            end

            -- main run keybind
            if config.opts.keys["run"] then
                vim.keymap.set("n", config.opts.keys["run"], function() M.run() end,
                    { buffer = true, noremap = true, silent = false })
            end

            -- main run command
            vim.api.nvim_buf_create_user_command(0, "Run", function()
                M.run()
            end, { desc = "Run a Script" })

            -- proj menu keybind
            if config.proj_file_exists and config.opts.keys["run_proj"] then
                vim.keymap.set("n", config.opts.keys["run_proj"], function() M.run_proj() end,
                    { buffer = true, noremap = true, silent = false })
            end

            -- reload proj command
            vim.api.nvim_create_user_command("RunReloadProj", function()
                M.reload_proj()
            end, { desc = "Reload run.nvim.lua" })
            
            -- preview command
            vim.api.nvim_create_user_command("RunPreview", function()
                M.preview_cmd()
            end, { desc = "Preview command without executing" })
        end
    })

    -- reload proj on write to run.nvim.lua
    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
        pattern = "run.nvim.lua",
        callback = function()
            M.reload_proj()
        end
    })
end

--- Load and parse the project configuration file (run.nvim.lua)
---@return nil
M.setup_proj = function()
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    config.proj_file_exists = proj_file ~= ""
    if config.proj_file_exists then
        local ok, result = pcall(dofile, proj_file)
        if ok then
            local success, error_msg = config.load_proj_config(result)
            if not success then
                utils.notify("Invalid project configuration: " .. error_msg, vim.log.levels.ERROR)
                config.proj = {}
                config.proj_file_exists = false
            end
        else
            utils.notify("Error loading project configuration: " .. tostring(result), vim.log.levels.ERROR)
            config.proj = {}
            config.proj_file_exists = false
        end
    end
end

--- Reload the project configuration file and reset the configuration state
---@return nil
M.reload_proj = function()
    config.proj = {}
    M.setup_proj()
    utils.notify("run.nvim.lua reloaded!", vim.log.levels.INFO)
end

--- Main entry point for running commands
--- Determines whether to run a file-specific command or project command
---@return boolean|nil success Whether the command executed successfully
M.run = function()
    if not config.proj_file_exists then
        return M.run_file()
    end
    
    if config.proj.default then
        return M.run_proj_default()
    else
        return M.run_proj()
    end
end

--- Execute a temporary filetype command safely with proper cleanup
---@param cmd_config any The command configuration (string, function, or table)
---@return boolean success Whether the command executed successfully
local function execute_temp_filetype_cmd(cmd_config)
    local temp_key = "_temp_filetype"
    
    -- Determine the command to execute
    local cmd
    if type(cmd_config) == "string" or type(cmd_config) == "function" then
        cmd = cmd_config
    elseif type(cmd_config) == "table" then
        if not cmd_config.cmd then
            utils.notify("Invalid filetype configuration: missing cmd field", vim.log.levels.ERROR)
            return false
        end
        cmd = cmd_config.cmd
    else
        utils.notify("Invalid filetype configuration format", vim.log.levels.ERROR)
        return false
    end
    
    -- Create temporary command entry
    config.proj[temp_key] = {
        name = "Filetype Command",
        cmd = cmd
    }
    
    -- Execute command with proper cleanup
    local success = utils.run_cmd(temp_key)
    config.proj[temp_key] = nil
    
    return success
end

--- Run the default script for the current file's filetype
---@return boolean|nil success Whether the command executed successfully
M.run_file = function()
    local buf = vim.api.nvim_buf_get_name(0)
    if not buf then
        utils.notify("No buffer name available", vim.log.levels.ERROR)
        return false
    end

    local ftype = vim.filetype.match({ filename = buf })
    if not ftype then
        utils.notify("Could not determine filetype", vim.log.levels.ERROR)
        return false
    end

    if not config.opts or not config.opts.filetype then
        utils.notify("No filetype configurations available", vim.log.levels.ERROR)
        return false
    end

    local exec = config.opts.filetype[ftype]
    if exec == nil then
        utils.notify("No default script found for filetype " .. ftype .. "!", vim.log.levels.ERROR)
        return false
    end

    return execute_temp_filetype_cmd(exec)
end

--- Run a script from the project configuration
--- Shows a selection menu if multiple scripts are available
---@return boolean success Whether a command was selected and executed
M.run_proj = function()
    if not config.proj then
        utils.notify("Project configuration not available", vim.log.levels.ERROR)
        return false
    end

    -- Get all available command options
    local options = {}
    local name_to_id = {}
    
    -- Add project commands
    for id, entry in pairs(config.proj) do
        if type(entry) == "table" and entry.name then
            -- Only show commands for the current filetype, if specified
            if entry.filetype and entry.filetype ~= vim.bo.filetype then
                goto continue
            end
            
            table.insert(options, entry.name)
            name_to_id[entry.name] = id
        end
        ::continue::
    end
    
    -- Add filetype default command if available
    if config.opts and config.opts.filetype and config.opts.filetype[vim.bo.filetype] then
        table.insert(options, "Default for Filetype")
    end

    -- Handle no available commands
    if #options == 0 then
        utils.notify("No available scripts found", vim.log.levels.WARN)
        return false
    end

    -- Handle single command case
    if #options == 1 then
        if options[1] == "Default for Filetype" then
            return M.run_file()
        else
            return utils.run_cmd(name_to_id[options[1]])
        end
    end

    -- Show selection UI for multiple commands
    vim.ui.select(options, {
        prompt = "Choose a script...",
    }, function(choice)
        if not choice then return end

        if choice == "Default for Filetype" then
            M.run_file()
            return
        end

        utils.run_cmd(name_to_id[choice])
    end)
    
    -- Return true for successful UI display (actual execution is async)
    return true
end

--- Run the default script from the project configuration
---@return boolean success Whether the default command executed successfully
M.run_proj_default = function()
    if not config.proj then
        utils.notify("Project configuration not available", vim.log.levels.ERROR)
        return false
    end

    if not config.proj.default then
        utils.notify("No default script set", vim.log.levels.ERROR)
        return false
    end

    local default_entry = config.proj[config.proj.default]
    if not default_entry or not default_entry.cmd then
        utils.notify("Invalid default script configuration", vim.log.levels.ERROR)
        return false
    end

    return utils.run_cmd(config.proj.default)
end

--- Brings up a menu to set the default script from the project configuration
---@return nil
M.set_default = function()
    if not config.proj_file_exists then
        utils.notify("No project configuration file found", vim.log.levels.ERROR)
        return
    end

    if not config.proj then
        utils.notify("Project configuration not available", vim.log.levels.ERROR)
        return
    end

    -- Get all available command names
    local options = {}
    local name_to_id = {}
    for id, entry in pairs(config.proj) do
        if type(entry) == "table" and entry.name then
            table.insert(options, entry.name)
            name_to_id[entry.name] = id
        end
    end

    if #options == 0 then
        utils.notify("No available scripts found", vim.log.levels.WARN)
        return
    end

    -- Add option to clear default
    if config.proj.default ~= nil then
        table.insert(options, "Clear Default")
    end

    -- Show selection UI
    vim.ui.select(options, {
        prompt = "Choose a default script..."
    }, function(choice)
        if not choice then return end

        if choice == "Clear Default" then
            config.proj.default = nil
            utils.write_conf()
            M.reload_proj()
            utils.notify("Default script cleared", vim.log.levels.INFO)
            return
        end

        config.proj.default = name_to_id[choice]
        
        if not config.proj.default then
            utils.notify("Failed to set default script", vim.log.levels.ERROR)
            return
        end

        utils.write_conf()
        M.reload_proj()
        utils.notify("Default script set to " .. choice, vim.log.levels.INFO)
    end)
end

--- Dump the plugin's configuration options
---@return nil
M.dump_opts = function()
    print(require("inspect").inspect(config.opts))
end

--- Dump the project configuration
---@return nil
M.dump_proj = function()
    print(require("inspect").inspect(config.proj))
end

--- Preview what command would be executed without actually running it
---@param cmd_section string|nil The command section to preview (nil for current filetype)
---@return nil
M.preview_cmd = function(cmd_section)
    if cmd_section then
        -- Preview project command
        if not config.proj or not config.proj[cmd_section] then
            utils.notify("Command section not found: " .. cmd_section, vim.log.levels.ERROR)
            return
        end
        
        local cmd_config = config.proj[cmd_section]
        local cmd = cmd_config.cmd
        
        if type(cmd) == "function" then
            local success, result = pcall(cmd)
            if success then
                cmd = result
            else
                utils.notify("Error in command function: " .. tostring(result), vim.log.levels.ERROR)
                return
            end
        end
        
        if type(cmd) == "string" then
            local formatted_cmd = utils.fmt_cmd(cmd)
            if formatted_cmd then
                utils.notify("Would execute: " .. formatted_cmd, vim.log.levels.INFO)
            else
                utils.notify("Command failed validation", vim.log.levels.ERROR)
            end
        else
            utils.notify("Invalid command type", vim.log.levels.ERROR)
        end
    else
        -- Preview filetype command
        local buf = vim.api.nvim_buf_get_name(0)
        if not buf then
            utils.notify("No buffer name available", vim.log.levels.ERROR)
            return
        end

        local ftype = vim.filetype.match({ filename = buf })
        if not ftype then
            utils.notify("Could not determine filetype", vim.log.levels.ERROR)
            return
        end

        if not config.opts or not config.opts.filetype or not config.opts.filetype[ftype] then
            utils.notify("No command configured for filetype: " .. ftype, vim.log.levels.ERROR)
            return
        end

        local exec = config.opts.filetype[ftype]
        local cmd = exec
        
        if type(exec) == "table" then
            cmd = exec.cmd
        elseif type(exec) == "function" then
            local success, result = pcall(exec)
            if success then
                cmd = result
            else
                utils.notify("Error in command function: " .. tostring(result), vim.log.levels.ERROR)
                return
            end
        end
        
        if type(cmd) == "string" then
            local formatted_cmd = utils.fmt_cmd(cmd)
            if formatted_cmd then
                utils.notify("Would execute: " .. formatted_cmd, vim.log.levels.INFO)
            else
                utils.notify("Command failed validation", vim.log.levels.ERROR)
            end
        else
            utils.notify("Invalid command type", vim.log.levels.ERROR)
        end
    end
end

return M