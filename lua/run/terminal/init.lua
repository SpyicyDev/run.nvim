local M = {}

local DETECTION_ORDER = { "snacks", "toggleterm", "fterm" }

local function module_for(backend)
  if backend == "snacks" then return "snacks" end
  if backend == "toggleterm" then return "toggleterm" end
  if backend == "fterm" then return "FTerm" end
  return nil
end

local function available(backend)
  local mod = module_for(backend)
  if not mod then return false end
  return pcall(require, mod)
end

---Resolve which backend to use given the current config.
---When `backend = "auto"`, walks DETECTION_ORDER and picks the first installed
---third-party plugin, otherwise falls back to "builtin".
---@return "builtin"|"snacks"|"toggleterm"|"fterm"
function M.detect()
  local backend = require("run.config").values.terminal.backend
  if backend == "auto" then
    for _, b in ipairs(DETECTION_ORDER) do
      if available(b) then return b end
    end
    return "builtin"
  end
  ---@cast backend "builtin"|"snacks"|"toggleterm"|"fterm"
  return backend
end

---@param cmd string  shell command
---@return boolean ok
function M.run(cmd)
  local backend = M.detect()
  local ok, mod = pcall(require, "run.terminal." .. backend)
  if not ok then
    require("run.util").notify(("terminal backend '%s' failed to load: %s"):format(backend, mod), vim.log.levels.ERROR)
    return false
  end
  return mod.run(cmd, require("run.config").values.terminal)
end

return M
