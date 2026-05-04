local M = {}

local DIRECTION_MAP = {
  float = "float",
  bottom = "horizontal",
  top = "horizontal",
  left = "vertical",
  right = "vertical",
  tab = "tab",
}

---@param cmd string
---@param opts run.TerminalConfig
---@return boolean ok
function M.run(cmd, opts)
  local ok_mod, toggleterm = pcall(require, "toggleterm")
  if not ok_mod then
    require("run.util").notify(
      "toggleterm.nvim not available; falling back to built-in terminal",
      vim.log.levels.WARN
    )
    return require("run.terminal.builtin").run(cmd, opts)
  end

  local direction = DIRECTION_MAP[opts.position] or "horizontal"
  local ok, err = pcall(toggleterm.exec, cmd, nil, opts.size, nil, direction)
  if not ok then
    require("run.util").notify(
      ("toggleterm.exec failed: %s"):format(err),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

return M
