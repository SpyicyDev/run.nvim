local M = {}

M.opts = {}
M.defaults = require("run.defaults")

M.setup = function(opts)
    M.opts = vim.tbl_deep_extend("force", M.defaults, opts or {})

    M.proj_file_exists = false

    vim.api.nvim_create_autocmd({ "BufReadPre", "DirChanged" }, {
        callback = function()
            M.setup_proj()
        end
    })
end

local toml = require("toml")

M.proj_file_exists = nil
M.setup_proj = function()
    local proj_file = vim.fn.findfile("run.toml", ".;")
    if proj_file ~= "" then
        local file = io.open(proj_file, "r")
        local toml_content = file:read("*a")
        file:close()

        -- Parse the TOML content
        local parsed_toml = toml.parse(toml_content)

        for title, config in pairs(parsed_toml) do
            M.opts.projects = vim.tbl_deep_extend("keep", M.opts.projects or {}, { [title] = config })
        end

        M.proj_file_exists = true
    end
end

M.reload_proj = function()
    M.opts.projects = {}
    M.setup_proj()
end

local term = require("FTerm")

M.run = function()
    if not M.proj_file_exists then
        local buf = vim.api.nvim_buf_get_name(0)
        local ftype = vim.filetype.match({ filename = buf })
        local exec = M.opts.filetype[ftype]
        exec = M.fmt_cmd(exec)
        if exec ~= nil then
            term.scratch({ cmd = exec })
        end
    else
        local options = {}
        for _, entry in pairs(M.opts.projects) do
            table.insert(options, entry.name)
        end

        vim.ui.select(options, {
            prompt = "Choose a script...",
        }, function(choice)
            local exec = ""
            for _, entry in pairs(M.opts.projects) do
                if entry.name == choice then
                    exec = entry.cmd
                    break
                end
            end
            exec = M.fmt_cmd(exec)
            term.scratch({ cmd = exec })
        end)
    end
end

M.fmt_cmd = function(cmd)
    if string.find(cmd, "%%f") then
        cmd = string.gsub(cmd, "%%f", vim.api.nvim_buf_get_name(0))
    end

    return cmd
end

return M
