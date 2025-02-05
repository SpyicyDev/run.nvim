local M = {}

local config = require("run.config")

---Write the current project configuration to the run.nvim.lua file
---@return nil
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