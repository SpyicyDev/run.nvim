local M = {}

local util = require("run.util")

local function open_window(position, size)
  if position == "float" then
    local width = math.max(40, math.floor(vim.o.columns * 0.8))
    local height = math.max(10, math.floor(vim.o.lines * 0.6))
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      border = "rounded",
      style = "minimal",
      title = " run.nvim ",
      title_pos = "center",
    })
    return buf, win
  end

  if position == "tab" then
    vim.cmd("tabnew")
    return vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  end

  local cmd
  if position == "bottom" then
    cmd = ("botright %dsplit"):format(size)
  elseif position == "top" then
    cmd = ("topleft %dsplit"):format(size)
  elseif position == "left" then
    cmd = ("topleft %dvsplit"):format(size)
  elseif position == "right" then
    cmd = ("botright %dvsplit"):format(size)
  else
    cmd = ("botright %dsplit"):format(size)
  end
  vim.cmd(cmd)
  vim.cmd("enew")
  return vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
end

---@param cmd string
---@param opts run.TerminalConfig
---@return boolean ok
function M.run(cmd, opts)
  local source_win = vim.api.nvim_get_current_win()
  local buf, win = open_window(opts.position, opts.size)

  local close_on_exit = opts.close_on_exit
  local on_exit = function(_, code)
    if close_on_exit and code == 0 and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local ok, err = pcall(vim.fn.jobstart, { vim.o.shell, "-c", cmd }, {
    term = true,
    on_exit = on_exit,
  })
  if not ok then
    util.notify(("failed to start terminal: %s"):format(err), vim.log.levels.ERROR)
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    return false
  end

  vim.bo[buf].buflisted = false
  vim.api.nvim_set_current_win(source_win)
  return true
end

return M
