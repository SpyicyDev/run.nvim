local M = {}

local utils = require("run.utils")
local config = require("run.config")

M.setup = function(opts)
    config.setup(opts)

    config.proj_file_exists = false

    M.setup_proj()
    vim.api.nvim_create_autocmd({ "DirChanged" }, {
        callback = function()
            M.setup_proj()
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
    exec = utils.fmt_cmd(exec)
    if exec ~= nil then
        term.scratch({ cmd = exec })
    end
end

M.run_proj = function()
    if config.proj.settings["default"] ~= nil then
        local exec = config.proj[config.proj.settings["default"]].cmd
        exec = utils.fmt_cmd(exec)
        term.scratch({ cmd = exec })
    else
        local options = {}
        for _, entry in pairs(config.proj) do
            table.insert(options, entry.name)
        end
        vim.ui.select(options, {
            prompt = "Choose a script...",
        }, function(choice)
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
        vim.ui.select(options, {
            prompt = "Choose a default script..."
        }, function(choice)
            for title, entry in pairs(config.proj) do
                if entry.name == choice then
                    config.proj.settings = vim.tbl_deep_extend("keep", config.proj.settings or {}, { default = title })
                    break
                end
            end

            utils.write_toml(config.proj)

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
