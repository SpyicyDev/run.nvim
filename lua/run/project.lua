local M = {}

local util = require("run.util")

---@class run.ProjectState
---@field path? string                                  absolute path of run.nvim.lua
---@field root? string                                  directory containing run.nvim.lua
---@field commands table<string, run.CommandSpec>       project commands keyed by id
---@field default? string                               id of default command (from run.nvim.lua or persisted state)

---@type run.ProjectState
M.state = { commands = {} }

local VALID_COMMAND_KEYS = { name = true, cmd = true, filetype = true }

local function _validate(tbl)
  if type(tbl) ~= "table" then
    return false, "project config must return a table"
  end
  for id, entry in pairs(tbl) do
    if id == "default" then
      if type(entry) ~= "string" then
        return false, "'default' must be a string command id"
      end
      if rawget(tbl, entry) == nil then
        return false, ("default command '%s' does not exist"):format(entry)
      end
    else
      if type(id) ~= "string" then
        return false, ("command ids must be strings (got %s)"):format(type(id))
      end
      if id:sub(1, 1) == "_" then
        return false, ("command id '%s' is reserved (leading underscore)"):format(id)
      end
      if type(entry) ~= "table" then
        return false, ("command '%s' must be a table"):format(id)
      end
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
        if not VALID_COMMAND_KEYS[k] then
          return false, ("command '%s' has unknown key '%s'"):format(id, k)
        end
      end
    end
  end
  return true
end

---Try to find the project file by walking up from cwd.
---@return string?  absolute path or nil
local function find_project_file()
  local filename = require("run.config").values.project.filename
  local found = vim.fn.findfile(filename, ".;")
  if found == "" then return nil end
  return vim.fn.fnamemodify(found, ":p")
end

---Read the project file source, respecting the trust setting.
---@param path string
---@return string?  source code, or nil if untrusted/unreadable
local function read_source(path)
  local trust = require("run.config").values.project.trust
  if trust == "never" then
    return nil
  end
  if trust == "always" then
    local fd, err = io.open(path, "r")
    if not fd then
      util.notify(("could not read %s: %s"):format(path, err), vim.log.levels.ERROR)
      return nil
    end
    local src = fd:read("*a")
    fd:close()
    return src
  end
  return vim.secure.read(path)
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
  if not ok then
    util.notify(("could not rename defaults state file: %s"):format(rename_err), vim.log.levels.ERROR)
  end
end

---Reset cached project state.
local function reset()
  M.state = { commands = {} }
end

---Load the project file (if any) and populate `M.state`.
---Idempotent: safe to call repeatedly.
function M.discover()
  reset()
  local path = find_project_file()
  if not path then return end

  local source = read_source(path)
  if not source then
    return
  end

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
    if id ~= "default" then
      commands[id] = entry
    end
  end

  M.state.path = path
  M.state.root = vim.fn.fnamemodify(path, ":h")
  M.state.commands = commands
  M.state.default = result.default

  local persisted = load_defaults_db()[M.state.root]
  if persisted and commands[persisted] then
    M.state.default = persisted
  end
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
function M.has_project()
  return M.state.path ~= nil
end

---@return string?
function M.path()
  return M.state.path
end

---@return table<string, run.CommandSpec>
function M.commands()
  return M.state.commands
end

---@return string?
function M.get_default()
  return M.state.default
end

return M
