local M = {}

---Display a notification with the run.nvim title
---@param msg string The message to display
---@param level number|nil The notification level (defaults to INFO)
---@return nil
M.notify = function(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "run.nvim" })
end

return M
