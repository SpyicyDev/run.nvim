local M = {}

local config = require("run.config")

-- do any preprocessing to the cmd string
M.fmt_cmd = function(cmd)
    if not cmd then
        vim.notify("Command string is nil", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return nil
    end

    if type(cmd) ~= "string" then
        vim.notify("Command must be a string", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return nil
    end

    if string.find(cmd, "%%f") then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if not buf_name or buf_name == "" then
            vim.notify("No buffer name available for %f substitution", vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return nil
        end
        cmd = string.gsub(cmd, "%%f", buf_name)
    end

    return cmd
end

-- run a cmd, either in term, vim command, or a lua function that optionally returns one of those
M.run_cmd = function(cmd)
    if not cmd then
        vim.notify("Command is nil", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if type(cmd) == "function" then
        local success, result = pcall(cmd)
        if not success then
            vim.notify("Error executing command function: " .. tostring(result), vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return
        end
        cmd = result
        if cmd == nil then
            return
        end
    end

    cmd = M.fmt_cmd(cmd)
    if not cmd then
        return
    end

    if type(cmd) ~= "string" then
        vim.notify("Command must be a string", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if cmd:sub(1, 1) == ":" then
        local success, err = pcall(vim.cmd, cmd:sub(2))
        if not success then
            vim.notify("Error executing vim command: " .. tostring(err), vim.log.levels.ERROR, {
                title = "run.nvim"
            })
        end
        return
    end

    local term = require("FTerm")
    if not term then
        vim.notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end
    
    term.scratch({ cmd = cmd })
end

-- write config.proj to run.nvim.lua
function M.write_conf()
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    if not proj_file or proj_file == "" then
        vim.notify("Could not find run.nvim.lua file", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local file = io.open(proj_file, "w")
    if not file then
        vim.notify("Could not open run.nvim.lua for writing", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if not config.proj then
        vim.notify("Project configuration is nil", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        file:close()
        return
    end

    local inspect = require("inspect")
    if not inspect then
        vim.notify("Could not load inspect module", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        file:close()
        return
    end

    local conf_string = inspect.inspect(config.proj)
    conf_string = "return " .. conf_string

    local success, err = pcall(function()
        file:write(conf_string)
        file:close()
    end)

    if not success then
        vim.notify("Error writing configuration: " .. tostring(err), vim.log.levels.ERROR, {
            title = "run.nvim"
        })
    end
end

return M
