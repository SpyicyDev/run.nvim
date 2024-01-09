local M = {}

local config = require("run.config")

M.deep_copy = function(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[M.deep_copy(k, s)] = M.deep_copy(v, s) end
    return setmetatable(res, getmetatable(obj))
end

M.fmt_cmd = function(cmd)
    if string.find(cmd, "%%f") then
        cmd = string.gsub(cmd, "%%f", vim.api.nvim_buf_get_name(0))
    end

    return cmd
end

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

function M.write_conf()
    local proj_file = vim.fn.findfile("run.lua", ".;")
    local file = io.open(proj_file, "w")

    local conf_string = require("inspect").inspect(config.proj)
    conf_string = "return " .. conf_string

    file:write(conf_string)
    file:close()
end

return M
