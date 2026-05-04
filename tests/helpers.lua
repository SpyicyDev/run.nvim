local M = {}

---Reset internal plugin state between tests.
---Plenary loads each spec fresh, but Lua's package cache persists module
---tables across `require` calls within the same nvim invocation.
function M.reset()
  for _, mod in ipairs({
    "run",
    "run.config",
    "run.project",
    "run.runner",
    "run.terminal",
    "run.terminal.builtin",
    "run.terminal.snacks",
    "run.terminal.toggleterm",
    "run.terminal.fterm",
    "run.ui",
    "run.util",
    "run.health",
  }) do
    package.loaded[mod] = nil
  end
  pcall(vim.api.nvim_del_augroup_by_name, "run.nvim")
  for _, c in ipairs({ "Run", "RunProj", "RunSetDefault", "RunReloadProj", "RunPreview" }) do
    pcall(vim.api.nvim_del_user_command, c)
  end
  vim.g.loaded_run = nil
  -- Wipe non-current listed buffers AND clear the current buffer's name to
  -- prevent E95 when a subsequent test sets the same name on a fresh buffer.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= vim.api.nvim_get_current_buf() and vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  pcall(vim.api.nvim_buf_set_name, vim.api.nvim_get_current_buf(), "")
end

---Resolve a path through filesystem symlinks (handles macOS `/tmp` → `/private/tmp`).
---@param path string
---@return string
function M.resolve(path) return vim.uv.fs_realpath(path) or path end

---Make a fresh tmpdir and register cleanup.
---@return string  absolute path
function M.tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

---Write a file with the given content.
function M.write(path, content)
  local fd = assert(io.open(path, "w"))
  fd:write(content)
  fd:close()
end

---Read a file's content (or nil).
function M.read(path)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local s = fd:read("*a")
  fd:close()
  return s
end

---Override stdpath('state') for the duration of a test by hijacking
---vim.fn.stdpath. Returns the new state dir and a restore function.
---@param tmpdir string
---@return string state_dir, function restore
function M.hijack_state(tmpdir)
  local original = vim.fn.stdpath
  local state_dir = tmpdir .. "/state"
  vim.fn.mkdir(state_dir, "p")
  vim.fn.stdpath = function(what)
    if what == "state" then return state_dir end
    return original(what)
  end
  return state_dir, function() vim.fn.stdpath = original end
end

---Capture vim.notify calls for the duration of a function.
---@param fn function
---@return table[] notifications  list of { msg = ..., level = ... }
function M.capture_notify(fn)
  local original = vim.notify
  local notifications = {}
  vim.notify = function(msg, level, _opts) table.insert(notifications, { msg = msg, level = level }) end
  local ok, err = pcall(fn)
  vim.notify = original
  if not ok then error(err) end
  return notifications
end

---Find a notification matching `pattern` (Lua pattern). Returns matching entry or nil.
function M.find_notify(notifications, pattern)
  for _, n in ipairs(notifications) do
    if n.msg and n.msg:find(pattern) then return n end
  end
  return nil
end

return M
