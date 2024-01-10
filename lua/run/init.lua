local M = {}

local utils = require("run.utils")
local config = require("run.config")

M.setup = function(opts)
    
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

        -- reload proj command
        vim.api.nvim_create_user_command("RunReloadProj", function()
            M.reload_proj()
        end, { desc = "Reload run.nvim.lua" })
    end

    -- keymaps and user commands that should only be on in an active buffer
    vim.api.nvim_create_autocmd("BufReadPre", {
        desc = "Setup run keymap and user command",
        callback = function()
            -- main run keybind
            vim.keymap.set("n", config.opts.keys["run"], function() M.run() end,
                { buffer = true, noremap = true, silent = false })

            -- main run command
            vim.api.nvim_buf_create_user_command(0, "Run", function()
                M.run()
            end, { desc = "Run a Script" })

            -- proj menu keybind
            if config.proj_file_exists then
                vim.keymap.set("n", config.opts.keys["run_proj"], function() M.run_proj() end,
                    { buffer = true, noremap = true, silent = false })
            end
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
        if config.proj.default ~= nil then
            M.run_proj_default()
        else
            M.run_proj()
        end
    end
end

-- run the default script for the filetype
M.run_file = function()
    local buf = vim.api.nvim_buf_get_name(0)
    local ftype = vim.filetype.match({ filename = buf })
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
    local options = {}
    for _, entry in pairs(config.proj) do
        if entry.filetype ~= nil then
            if vim.bo.filetype == entry.filetype then
                table.insert(options, entry.name)
            end
        else
            table.insert(options, entry.name)
        end
    end

    if config.opts.filetype[vim.bo.filetype] ~= nil then
        table.insert(options, "Default for Filetype")
    end

    -- if length of options is 1, run that one script
    -- also make sure to just run M.run_file() if the only option is "Default for Filetype"
    -- and it it isn't, then run the cmd from the proj table
    if #options == 1 then
        if options[1] == "Default for Filetype" then
            M.run_file()
            return
        end

        local exec = ""
        for _, entry in pairs(config.proj) do
            if entry.name == options[1] then
                exec = entry.cmd
                break
            end
        end
        utils.run_cmd(exec)
        return
    end

    vim.ui.select(options, {
        prompt = "Choose a script...",
    }, function(choice)
        if choice == "Default for Filetype" then
            M.run_file()
            return
        end

        local exec = ""
        for _, entry in pairs(config.proj) do
            if entry.name == choice then
                exec = entry.cmd
                break
            end
        end

        utils.run_cmd(exec)
    end)
end

-- run the default script from the proj file
M.run_proj_default = function()
    local exec = config.proj[config.proj.default].cmd
    utils.run_cmd(exec)
end

-- brings up menu to set the default script from proj file
M.set_default = function()
    if config.proj_file_exists ~= false then
        local options = {}
        for _, entry in pairs(config.proj) do
            table.insert(options, entry.name)
        end
        if config.proj.default ~= nil then
            table.insert(options, "Clear Default")
        end

        vim.ui.select(options, {
            prompt = "Choose a default script..."
        }, function(choice)
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
                if entry.name == choice then
                    config.proj.default = title
                    break
                end
            end

            utils.write_conf()

            M.reload_proj()

            vim.notify("Default script set to " .. choice, vim.log.levels.INFO, {
                title = "run.nvim"
            })
        end)
    else
        vim.notify("No run.nvim.lua file found!", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
    end
end

-------------------------

M.dump_opts = function()
    print(require("inspect").inspect(config.opts))
end

M.dump_proj = function()
    print(require("inspect").inspect(config.proj))
end

return M
