local M = {}

local util = require("run.util")

---@class run.ProjectState
---@field path? string                                  absolute path of run.nvim.lua
---@field root? string                                  directory containing run.nvim.lua
---@field commands table<string, run.CommandSpec>       project commands keyed by id
---@field default? string                               id of default command (from run.nvim.lua or persisted state)

---@type run.ProjectState
M.state = { commands = {} }

---True once `discover()` has been called at least once in this nvim session
---(via setup's deferred trigger or via ensure_setup's sync fallback). Lets
---ensure_setup avoid duplicating the deferred discover from setup().
M.did_initial_discover = false

local VALID_COMMAND_KEYS = { name = true, cmd = true, filetype = true }

local function _validate(tbl)
  if type(tbl) ~= "table" then return false, "project config must return a table" end
  for id, entry in pairs(tbl) do
    if id == "default" then
      if type(entry) ~= "string" then return false, "'default' must be a string command id" end
      if rawget(tbl, entry) == nil then return false, ("default command '%s' does not exist"):format(entry) end
    else
      if type(id) ~= "string" then return false, ("command ids must be strings (got %s)"):format(type(id)) end
      if id:sub(1, 1) == "_" then return false, ("command id '%s' is reserved (leading underscore)"):format(id) end
      if type(entry) ~= "table" then return false, ("command '%s' must be a table"):format(id) end
      if type(entry.name) ~= "string" or entry.name == "" then
        return false, ("command '%s' missing string 'name'"):format(id)
      end
      local ct = type(entry.cmd)
      if ct ~= "string" and ct ~= "function" then
        return false, ("command '%s' 'cmd' must be string or function"):format(id)
      end
      if entry.filetype ~= nil and type(entry.filetype) ~= "string" then
        return false, ("command '%s' 'filetype' must be a string"):format(id)
      end
      for k in pairs(entry) do
        if not VALID_COMMAND_KEYS[k] then return false, ("command '%s' has unknown key '%s'"):format(id, k) end
      end
    end
  end
  return true
end

---Try to find the project file by walking up from cwd (NOT from the current
---buffer's directory — `vim.fn.findfile(name, ".;")` would do the latter).
---@return string?  absolute path or nil
local function find_project_file()
  local filename = require("run.config").values.project.filename
  local matches = vim.fs.find(filename, {
    upward = true,
    type = "file",
    path = vim.fn.getcwd(),
  })
  return matches[1]
end

local function read_file_text(path, mode)
  local fd, err = io.open(path, mode or "r")
  if not fd then
    if mode ~= "rb" then util.notify(("could not read %s: %s"):format(path, err), vim.log.levels.ERROR) end
    return nil
  end
  local src = fd:read("*a")
  fd:close()
  return src
end

---SHA-256 of the file's raw bytes (matches what vim.secure stores).
local function file_sha256(path)
  local content = read_file_text(path, "rb")
  if not content then return nil end
  return vim.fn.sha256(content)
end

---Path to Neovim's trust DB (same file vim.secure.read consults).
local function trust_db_path() return vim.fn.stdpath("state") .. "/trust" end

---Check whether the trust DB has a `<hash> <path>` entry for `path` whose
---hash matches the file's current content. Lets us skip the prompt when
---no confirm dialog would be needed.
local function is_trusted(path)
  local data = read_file_text(trust_db_path(), "rb")
  if not data then return false end
  local want = file_sha256(path)
  if not want then return false end
  for line in data:gmatch("[^\n]+") do
    local hash, p = line:match("^(%S+)%s+(.+)$")
    if p == path and hash == want then return true end
  end
  return false
end

---Add `<hash> <path>` to the trust DB (replacing any prior entry for the
---same path). Same on-disk format vim.secure uses, so future
---vim.secure.read calls on this file will short-circuit too.
---
---Write is atomic (write-temp-then-rename) because the trust DB is shared
---with vim.secure across the entire Neovim ecosystem; a partial write here
---would corrupt trust for every plugin that uses vim.secure.read.
---@return boolean ok
local function persist_trust(path)
  local hash = file_sha256(path)
  if not hash then return false end
  local entries = {}
  local existing = read_file_text(trust_db_path(), "rb") or ""
  for line in existing:gmatch("[^\n]+") do
    local _, p = line:match("^(%S+)%s+(.+)$")
    if p ~= path then table.insert(entries, line) end
  end
  table.insert(entries, hash .. " " .. path)
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  local final = trust_db_path()
  local tmp = final .. ".tmp"
  local fd, err = io.open(tmp, "w")
  if not fd then
    util.notify(("could not write trust DB: %s"):format(err), vim.log.levels.ERROR)
    return false
  end
  fd:write(table.concat(entries, "\n") .. "\n")
  fd:close()
  local ok, rename_err = os.rename(tmp, final)
  if not ok then
    util.notify(("could not rename trust DB: %s"):format(rename_err), vim.log.levels.ERROR)
    return false
  end
  return true
end

---In-session trust cache: maps absolute project file path -> true once the
---user has approved it. Avoids re-prompting on BufWritePost / DirChanged
---within the same Neovim session, since the trust DB is keyed by file
---content and any edit invalidates the entry. Cleared at next nvim restart,
---so cross-session security is preserved.
local _session_trusted = {}

---Show our own trust confirm prompt — single dialog with full context,
---routed through whatever UI is hooked (noice, dressing, raw vim).
---@param path string
---@return 1|2|3  1 = trust+load, 2 = skip, 3 = view first
local function prompt_trust(path)
  local msg = ("[run.nvim] Trust this project config and load it?\n\n  %s\n\nIt contains executable Lua that runs in your Neovim."):format(
    path
  )
  local choice = vim.fn.confirm(msg, "&Trust && load\n&Skip\n&View first", 2)
  return choice == 0 and 2 or choice
end

---Read the project file source, respecting the trust setting.
---@param path string  absolute path
---@return string?  source code, or nil if untrusted/unreadable
local function read_source(path)
  local trust = require("run.config").values.project.trust
  if trust == "never" then return nil end
  if trust == "always" then return read_file_text(path) end

  path = vim.fs.normalize(path)
  if _session_trusted[path] or is_trusted(path) then
    _session_trusted[path] = true
    return read_file_text(path)
  end

  local choice = prompt_trust(path)
  if choice == 1 then
    persist_trust(path)
    _session_trusted[path] = true
    return read_file_text(path)
  end
  if choice == 3 then
    vim.cmd("split " .. vim.fn.fnameescape(path))
    util.notify("review the file, then run :RunReloadProj to be prompted again", vim.log.levels.INFO)
  end
  return nil
end

---@return string  absolute path to defaults.json
local function defaults_state_file()
  local dir = vim.fn.stdpath("state") .. "/run.nvim"
  vim.fn.mkdir(dir, "p")
  return dir .. "/defaults.json"
end

---@return table<string, string>  map of project_root -> default command id
local function load_defaults_db()
  local path = defaults_state_file()
  local fd = io.open(path, "r")
  if not fd then return {} end
  local raw = fd:read("*a")
  fd:close()
  if raw == nil or raw == "" then return {} end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    util.notify(("defaults state file is corrupt: %s"):format(path), vim.log.levels.WARN)
    return {}
  end
  return decoded
end

---@param db table<string, string>
local function save_defaults_db(db)
  local path = defaults_state_file()
  local tmp = path .. ".tmp"
  local fd, err = io.open(tmp, "w")
  if not fd then
    util.notify(("could not write defaults: %s"):format(err), vim.log.levels.ERROR)
    return
  end
  fd:write(vim.json.encode(db))
  fd:close()
  local ok, rename_err = os.rename(tmp, path)
  if not ok then util.notify(("could not rename defaults state file: %s"):format(rename_err), vim.log.levels.ERROR) end
end

---Reset cached project state.
local function reset() M.state = { commands = {} } end

---Load the project file (if any) and populate `M.state`.
---Idempotent: safe to call repeatedly.
function M.discover()
  M.did_initial_discover = true
  reset()
  local path = find_project_file()
  if not path then return end

  local source = read_source(path)
  if not source then return end

  local chunk, load_err = loadstring(source, "@" .. path)
  if not chunk then
    util.notify(("error parsing %s: %s"):format(path, load_err), vim.log.levels.ERROR)
    return
  end

  local ok, result = pcall(chunk)
  if not ok then
    util.notify(("error executing %s: %s"):format(path, result), vim.log.levels.ERROR)
    return
  end

  local valid, validate_err = _validate(result)
  if not valid then
    util.notify(("invalid project config: %s"):format(validate_err), vim.log.levels.ERROR)
    return
  end

  local commands = {}
  for id, entry in pairs(result) do
    if id ~= "default" then commands[id] = entry end
  end

  M.state.path = path
  M.state.root = vim.fn.fnamemodify(path, ":h")
  M.state.commands = commands
  M.state.default = result.default

  local persisted = load_defaults_db()[M.state.root]
  if persisted and commands[persisted] then M.state.default = persisted end
end

---Persist a chosen default to the state DB. Pass nil to clear.
---@param id? string
function M.persist_default(id)
  if not M.state.root then return end
  local db = load_defaults_db()
  if id == nil then
    db[M.state.root] = nil
  else
    db[M.state.root] = id
  end
  save_defaults_db(db)
  M.state.default = id
end

---Whether a project file is currently loaded.
---@return boolean
function M.has_project() return M.state.path ~= nil end

---@return string?
function M.path() return M.state.path end

---@return table<string, run.CommandSpec>
function M.commands() return M.state.commands end

---@return string?
function M.get_default() return M.state.default end

return M
