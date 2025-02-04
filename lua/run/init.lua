local M = {}

local utils = require("run.utils")
local config = require("run.config")

M.setup = function(opts)
    if not opts then opts = {} end
    -- initialize all config variables and stuff
    config.setup(opts)

    M.setup_proj()

    --- KEYBINDS AND AUTOCOMMANDS AND USER COMMANDS ---

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
    vim.api.nvim_create_autocmd("BufReadPre", {
        desc = "Setup run keymap and user command",
        callback = function()
            -- ensure we have valid keys configured
            if not config.opts or not config.opts.keys then
                vim.notify("run.nvim: Missing key configuration", vim.log.levels.ERROR)
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
end

-- look for run.nvim.lua, if there load it into config.proj
M.setup_proj = function()
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    if proj_file ~= "" then
        config.proj = dofile(proj_file)

        config.proj_file_exists = true
    else
        config.proj_file_exists = false
    end
end

-- reload proj file
M.reload_proj = function()
    config.proj = {}
    M.setup_proj()

    vim.notify("run.nvim.lua reloaded!", vim.log.levels.INFO, {
        title = "run.nvim"
    })
end

-- main run method, delegates to either run_file, run_proj, or run_proj_default
M.run = function()
    if not config.proj_file_exists then
        M.run_file()
    else
        if config.proj and config.proj.default ~= nil then
            M.run_proj_default()
        else
            M.run_proj()
        end
    end
end

-- run the default script for the filetype
M.run_file = function()
    local buf = vim.api.nvim_buf_get_name(0)
    if not buf then
        vim.notify("No buffer name available", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local ftype = vim.filetype.match({ filename = buf })
    if not ftype then
        vim.notify("Could not determine filetype", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if not config.opts or not config.opts.filetype then
        vim.notify("No filetype configurations available", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local exec = config.opts.filetype[ftype]

    -- don't do anything if filetype is not set
    if exec ~= nil then
        utils.run_cmd(exec)
    else
        vim.notify("No default script found for filetype " .. ftype .. "!", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end
end

-- run a script from the proj table
M.run_proj = function()
    if not config.proj then
        vim.notify("Project configuration not available", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local options = {}
    for _, entry in pairs(config.proj) do
        if type(entry) ~= "table" then
            goto continue
        end

        if entry.filetype ~= nil then
            if vim.bo.filetype == entry.filetype then
                if entry.name then
                    table.insert(options, entry.name)
                end
            end
        else
            if entry.name then
                table.insert(options, entry.name)
            end
        end
        ::continue::
    end

    if config.opts and config.opts.filetype and config.opts.filetype[vim.bo.filetype] then
        table.insert(options, "Default for Filetype")
    end

    -- if no options available, notify user
    if #options == 0 then
        vim.notify("No available scripts found", vim.log.levels.WARN, {
            title = "run.nvim"
        })
        return
    end

    -- if length of options is 1, run that one script
    if #options == 1 then
        if options[1] == "Default for Filetype" then
            M.run_file()
            return
        end

        local exec
        for _, entry in pairs(config.proj) do
            if type(entry) == "table" and entry.name == options[1] and entry.cmd then
                exec = entry.cmd
                break
            end
        end

        if not exec then
            vim.notify("Command not found for " .. options[1], vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return
        end

        utils.run_cmd(exec)
        return
    end

    vim.ui.select(options, {
        prompt = "Choose a script...",
    }, function(choice)
        if not choice then return end

        if choice == "Default for Filetype" then
            M.run_file()
            return
        end

        local exec
        for _, entry in pairs(config.proj) do
            if type(entry) == "table" and entry.name == choice and entry.cmd then
                exec = entry.cmd
                break
            end
        end

        if not exec then
            vim.notify("Command not found for " .. choice, vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return
        end

        utils.run_cmd(exec)
    end)
end

-- run the default script from the proj file
M.run_proj_default = function()
    if not config.proj then
        vim.notify("Project configuration not available", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if not config.proj.default then
        vim.notify("No default script set", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local default_entry = config.proj[config.proj.default]
    if not default_entry or not default_entry.cmd then
        vim.notify("Invalid default script configuration", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    utils.run_cmd(default_entry.cmd)
end

-- brings up menu to set the default script from proj file
M.set_default = function()
    if not config.proj_file_exists then
        vim.notify("No project configuration file found", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if not config.proj then
        vim.notify("Project configuration not available", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local options = {}
    for _, entry in pairs(config.proj) do
        if type(entry) == "table" and entry.name then
            table.insert(options, entry.name)
        end
    end

    if #options == 0 then
        vim.notify("No available scripts found", vim.log.levels.WARN, {
            title = "run.nvim"
        })
        return
    end

    if config.proj.default ~= nil then
        table.insert(options, "Clear Default")
    end

    vim.ui.select(options, {
        prompt = "Choose a default script..."
    }, function(choice)
        if not choice then return end

        if choice == "Clear Default" then
            config.proj.default = nil
            utils.write_conf()
            M.reload_proj()
            vim.notify("Default script cleared", vim.log.levels.INFO, {
                title = "run.nvim"
            })
            return
        end

        for title, entry in pairs(config.proj) do
            if type(entry) == "table" and entry.name == choice then
                config.proj.default = title
                break
            end
        end

        if not config.proj.default then
            vim.notify("Failed to set default script", vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return
        end

        utils.write_conf()
        M.reload_proj()
        vim.notify("Default script set to " .. choice, vim.log.levels.INFO, {
            title = "run.nvim"
        })
    end)
end

-------------------------

M.dump_opts = function()
    print(require("inspect").inspect(config.opts))
end

M.dump_proj = function()
    print(require("inspect").inspect(config.proj))
end

return M
