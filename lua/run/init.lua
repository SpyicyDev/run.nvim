local M = {}

local utils = require("run.utils")
local config = require("run.config")

M.setup = function(opts)
    config.setup(opts)

    M.setup_proj()
    vim.api.nvim_create_autocmd({ "DirChanged" }, {
        desc = "Setup run.toml on DirChanged",
        callback = function()
            M.setup_proj()
        end
    })

    vim.api.nvim_create_autocmd("BufReadPre", {
        desc = "Setup run keymap and user command",
        callback = function()
            vim.keymap.set("n", "<leader>rr", function() M.run() end, { buffer = true, noremap = true, silent = false })

            vim.api.nvim_buf_create_user_command(0, "Run", function(args)
                if args.fargs[1] == nil then
                    M.run()
                else
                    require("notify")("Run takes no arguments", "error", {
                        title = "run.nvim"
                    })
                end
            end, { desc = "Run a Script" })
        end
    })
end

M.setup_proj = function()
    local proj_file = vim.fn.findfile("run.toml", ".;")
    if proj_file ~= "" then
        local parsed_toml = utils.read_toml(proj_file)

        for title, conf in pairs(parsed_toml) do
            config.proj = vim.tbl_deep_extend("keep", config.proj or {}, { [title] = conf })
        end

        config.proj_file_exists = true

        vim.api.nvim_create_user_command("RunSetDefault", function(args)
            if args[0] == nil then
                M.set_default()
            else
                require("notify")("RunSetDefault takes no arguments", "error", {
                    title = "run.nvim"
                })
            end
        end, { desc = "Set a Default Script" })
    else
        config.proj_file_exists = false
    end
end

M.reload_proj = function()
    config.proj = {}
    M.setup_proj()
end

local term = require("FTerm")

M.run = function()
    if not config.proj_file_exists then
        M.run_file()
    else
        M.run_proj()
    end
end

M.run_file = function()
    local buf = vim.api.nvim_buf_get_name(0)
    local ftype = vim.filetype.match({ filename = buf })
    local exec = config.opts.filetype[ftype]
    if type(exec) == "function" then
        exec = exec()
    end
    exec = utils.fmt_cmd(exec)
    if exec ~= nil then
        term.scratch({ cmd = exec })
    end
end

M.run_proj = function()
    if config.proj.settings and config.proj.settings["default"] ~= nil then
        local exec = config.proj[config.proj.settings["default"]].cmd
        exec = utils.fmt_cmd(exec)
        term.scratch({ cmd = exec })
    else
        local options = {}
        for _, entry in pairs(config.proj) do
            table.insert(options, entry.name)
        end
        table.insert(options, "Default for Filetype")
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
            exec = utils.fmt_cmd(exec)
            term.scratch({ cmd = exec })
        end)
    end
end

M.set_default = function()
    if config.proj_file_exists ~= false then
        local options = {}
        for _, entry in pairs(config.proj) do
            table.insert(options, entry.name)
        end
        if config.proj.settings ~= nil and config.proj.settings["default"] ~= nil then
            table.insert(options, "Clear Default")
        end

        vim.ui.select(options, {
            prompt = "Choose a default script..."
        }, function(choice)
            if choice == "Clear Default" then
                config.proj.settings = nil
                utils.write_toml(config.proj)
                M.reload_proj()
                require("notify")("Default script cleared", "info", {
                    title = "run.nvim"
                })
                return
            end

            for title, entry in pairs(config.proj) do
                if entry.name == choice then
                    config.proj.settings = vim.tbl_deep_extend("force", config.proj.settings or {}, { default = title })
                    break
                end
            end

            utils.write_toml(config.proj)

            M.reload_proj()

            require("notify")("Default script set to " .. choice, "info", {
                title = "run.nvim"
            })
        end)
    else
        require("notify")("No run.toml file found!", "error", {
            title = "run.nvim"
        })
    end
end

M.dump_opts = function()
    print(require("inspect").inspect(config.opts))
end

M.dump_proj = function()
    print(require("inspect").inspect(config.proj))
end

return M
