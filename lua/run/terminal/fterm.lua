local M = {}

---@param cmd string
---@param opts run.TerminalConfig
---@return boolean ok
function M.run(cmd, opts)
  local ok_mod, fterm = pcall(require, "FTerm")
  if not ok_mod then
    require("run.util").notify(
      "FTerm.nvim not available; falling back to built-in terminal",
      vim.log.levels.WARN
    )
    return require("run.terminal.builtin").run(cmd, opts)
  end

  local ok, err = pcall(fterm.scratch, {
    cmd = cmd,
    auto_close = opts.close_on_exit,
  })
  if not ok then
    require("run.util").notify(
      ("FTerm.scratch failed: %s"):format(err),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

return M
