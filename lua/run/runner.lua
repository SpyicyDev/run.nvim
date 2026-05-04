local M = {}

local util = require("run.util")

local FILE_PATTERN = "%%[fdnet]"

local DANGEROUS_PATTERNS = {
  "rm%s+%-rf%s+/",
  "rm%s+%-rf%s+%*",
  ":%s*!%s*rm",
  "sudo%s+rm%s+%-rf",
}

---Substitute environment variables (`$VAR`, `${VAR}`).
---Missing vars stay literal so the shell can decide what to do; a one-shot
---warning is emitted per name to surface likely typos.
---@param cmd string
---@return string
local function expand_env(cmd)
  local function lookup(name)
    return vim.env[name] or os.getenv(name)
  end
  cmd = cmd:gsub("%${([%w_]+)}", function(name)
    local v = lookup(name)
    if v then return v end
    util.notify(("environment variable $%s is not set"):format(name), vim.log.levels.WARN)
    return "${" .. name .. "}"
  end)
  cmd = cmd:gsub("%$([%w_]+)", function(name)
    local v = lookup(name)
    if v then return v end
    util.notify(("environment variable $%s is not set"):format(name), vim.log.levels.WARN)
    return "$" .. name
  end)
  return cmd
end

---Substitute file path placeholders.
---  `%f` → absolute buffer path
---  `%d` → directory of buffer file
---  `%n` → basename without extension
---  `%e` → extension (no dot)
---  `%t` → basename with extension
---@param cmd string
---@return string?
local function expand_file(cmd)
  if not cmd:find(FILE_PATTERN) then
    return cmd
  end
  local path = util.buffer_path(0)
  if not path then
    util.notify("no file in current buffer for %f/%d/%n/%e/%t substitution", vim.log.levels.ERROR)
    return nil
  end
  local subs = {
    ["%%f"] = path,
    ["%%d"] = vim.fn.fnamemodify(path, ":h"),
    ["%%n"] = vim.fn.fnamemodify(path, ":t:r"),
    ["%%e"] = vim.fn.fnamemodify(path, ":e"),
    ["%%t"] = vim.fn.fnamemodify(path, ":t"),
  }
  for pat, val in pairs(subs) do
    cmd = cmd:gsub(pat, (val:gsub("%%", "%%%%")))
  end
  return cmd
end

---Apply env-var then file-path expansion.
---@param cmd string
---@return string?
local function expand(cmd)
  cmd = expand_env(cmd)
  return expand_file(cmd)
end

---Reject obviously destructive patterns (`rm -rf /`, etc).
---Returns false plus the matching pattern when the command should be blocked.
---@param cmd string
---@return boolean ok
---@return string? matched_pattern
function M.check_safety(cmd)
  local lowered = cmd:lower()
  for _, pat in ipairs(DANGEROUS_PATTERNS) do
    if lowered:find(pat) then
      return false, pat
    end
  end
  return true
end

local function exec_vim(vim_cmd)
  local ok, err = pcall(vim.cmd, vim_cmd)
  if not ok then
    util.notify(("vim command failed: %s"):format(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function exec_shell(shell_cmd)
  return require("run.terminal").run(shell_cmd)
end

---Resolve a command spec into one of three outcomes:
---  "run"   — execute `cmd` (a string)
---  "skip"  — function explicitly returned nil; treat as success no-op
---  "error" — invalid spec; error already notified
---@param spec run.CommandSpec|string
---@return "run"|"skip"|"error" status
---@return string? cmd
local function resolve(spec)
  if type(spec) == "string" then
    return "run", spec
  end
  if type(spec) ~= "table" then
    util.notify(("command spec must be table or string, got %s"):format(type(spec)), vim.log.levels.ERROR)
    return "error"
  end
  local cmd = spec.cmd
  if type(cmd) == "function" then
    local ok, ret = pcall(cmd)
    if not ok then
      util.notify(("command function errored: %s"):format(ret), vim.log.levels.ERROR)
      return "error"
    end
    if ret == nil then return "skip" end
    cmd = ret
  end
  if type(cmd) ~= "string" then
    util.notify("'cmd' must be a string, or a function returning string|nil", vim.log.levels.ERROR)
    return "error"
  end
  return "run", cmd
end

---Resolve and fully expand a spec without running it.
---Used by :RunPreview / M.preview.
---@param spec run.CommandSpec|string
---@return string?  expanded_cmd  nil if invalid or skip-resolved
function M.preview(spec)
  local status, raw_cmd = resolve(spec)
  if status ~= "run" or raw_cmd == nil then return nil end
  return expand(raw_cmd)
end

---Execute a command spec.
---@param spec run.CommandSpec|string
---@return boolean ok
function M.execute(spec)
  local status, raw_cmd = resolve(spec)
  if status == "skip" then return true end
  if status == "error" or raw_cmd == nil then return false end
  local cmd = expand(raw_cmd)
  if cmd == nil then return false end
  local safe, pattern = M.check_safety(cmd)
  if not safe then
    util.notify(("refusing to run command matching dangerous pattern: %s"):format(pattern), vim.log.levels.ERROR)
    return false
  end
  if cmd:sub(1, 1) == ":" then
    return exec_vim(cmd:sub(2))
  end
  return exec_shell(cmd)
end

return M
