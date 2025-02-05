local M = {}

-- Common notification wrapper
M.notify = function(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "run.nvim" })
end

return M
