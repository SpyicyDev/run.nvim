local M = {}

---Notify the user with the run.nvim title prefix.
---
---Honors `config.notify` so users can silence the plugin entirely.
---
---@param msg string
---@param level? integer  vim.log.levels.* (default INFO)
function M.notify(msg, level)
  -- Avoid a hard `require("run.config")` cycle at module load: only resolve
  -- the config table when we actually emit a notification.
  local ok, config = pcall(require, "run.config")
  if ok and config.values and config.values.notify == false then return end
  vim.notify(msg, level or vim.log.levels.INFO, { title = "run.nvim" })
end

---Return the absolute path of the current buffer, or nil if it's unnamed.
---@param bufnr? integer  default 0 (current)
---@return string?
function M.buffer_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == nil or name == "" then return nil end
  return name
end

---Return the effective filetype for `bufnr`, preferring `vim.bo.filetype`
---(which is reliable for unsaved buffers) and falling back to `vim.filetype.match`.
---@param bufnr? integer  default 0
---@return string?
function M.buffer_filetype(bufnr)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  if ft and ft ~= "" then return ft end
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return nil end
  return vim.filetype.match({ filename = name })
end

return M
