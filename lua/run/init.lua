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

--- Run the default script for the current file's filetype
---@return nil
M.run_file = function()
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

    if not config.opts or not config.opts.filetype then
        utils.notify("No filetype configurations available", vim.log.levels.ERROR)
        return
    end

    local exec = config.opts.filetype[ftype]

    -- don't do anything if filetype is not set
    if exec ~= nil then
        if type(exec) == "string" or type(exec) == "function" then
            -- Create a temporary command section for direct command strings
            config.proj["_temp_filetype"] = { 
                name = "Filetype Command", 
                cmd = exec 
            }
            utils.run_cmd("_temp_filetype")
            config.proj["_temp_filetype"] = nil
        elseif type(exec) == "table" then
            -- Handle table configuration with cmd
            if not exec.cmd then
                utils.notify("Invalid filetype configuration: missing cmd field", vim.log.levels.ERROR)
                return
            end
            config.proj["_temp_filetype"] = {
                name = "Filetype Command",
                cmd = exec.cmd
            }
            utils.run_cmd("_temp_filetype")
            config.proj["_temp_filetype"] = nil
        end
    else
        utils.notify("No default script found for filetype " .. ftype .. "!", vim.log.levels.ERROR)
        return
    end
end

--- Run a script from the project configuration
--- Shows a selection menu if multiple scripts are available
---@return nil
M.run_proj = function()
    if not config.proj then
        utils.notify("Project configuration not available", vim.log.levels.ERROR)
        return
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
        return
    end

    -- Handle single command case
    if #options == 1 then
        if options[1] == "Default for Filetype" then
            M.run_file()
        else
            utils.run_cmd(name_to_id[options[1]])
        end
        return
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
end

--- Run the default script from the project configuration
---@return nil
M.run_proj_default = function()
    if not config.proj then
        utils.notify("Project configuration not available", vim.log.levels.ERROR)
        return
    end

    if not config.proj.default then
        utils.notify("No default script set", vim.log.levels.ERROR)
        return
    end

    local default_entry = config.proj[config.proj.default]
    if not default_entry or not default_entry.cmd then
        utils.notify("Invalid default script configuration", vim.log.levels.ERROR)
        return
    end

    utils.run_cmd(config.proj.default)
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

return M