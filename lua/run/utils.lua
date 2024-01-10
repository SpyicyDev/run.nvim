local M = {}

local config = require("run.config")

-- do any preprocessing to the cmd string
M.fmt_cmd = function(cmd)
    if string.find(cmd, "%%f") then
        cmd = string.gsub(cmd, "%%f", vim.api.nvim_buf_get_name(0))
    end

    return cmd
end

-- run a cmd, either in term, vim command, or a lua function that optionally returns one of those
M.run_cmd = function(cmd)
    if type(cmd) == "function" then
      cmd = cmd()
      if cmd == nil then
          return
      end
    end

    cmd = M.fmt_cmd(cmd)

    if cmd:sub(1, 1) == ":" then
        vim.cmd(cmd:sub(2))
        return
    end

    local term = require("FTerm")
    term.scratch({ cmd = cmd })
end

-- write config.proj to run.nvim.lua
function M.write_conf()
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    local file = io.open(proj_file, "w")

    local conf_string = require("inspect").inspect(config.proj)
    conf_string = "return " .. conf_string

    file:write(conf_string)
    file:close()
end

return M
