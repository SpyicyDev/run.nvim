local M = {}

-- Validate command input
M.validate_cmd = function(cmd)
    local notify = require("run.utils.notify").notify
    
    if not cmd then
        notify("Command is nil", vim.log.levels.ERROR)
        return false
    end
    if type(cmd) ~= "string" then
        notify("Command must be a string", vim.log.levels.ERROR)
        return false
    end
    return true
end

return M
