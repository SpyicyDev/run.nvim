local M = {}

local POSITION_MAP = {
  float = "float",
  bottom = "bottom",
  top = "top",
  left = "left",
  right = "right",
  tab = "float",
}

---@param cmd string
---@param opts run.TerminalConfig
---@return boolean ok
function M.run(cmd, opts)
  local snacks_ok, snacks = pcall(require, "snacks")
  if not snacks_ok or not snacks.terminal then
    require("run.util").notify(
      "snacks.terminal not available; falling back to built-in terminal",
      vim.log.levels.WARN
    )
    return require("run.terminal.builtin").run(cmd, opts)
  end

  local ok, err = pcall(snacks.terminal, cmd, {
    win = {
      position = POSITION_MAP[opts.position] or "bottom",
      height = opts.size,
      width = opts.size,
    },
    auto_close = opts.close_on_exit,
  })
  if not ok then
    require("run.util").notify(
      ("snacks.terminal failed: %s"):format(err),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

return M
