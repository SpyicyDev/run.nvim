---@class run.TerminalConfig
---@field backend? "auto"|"builtin"|"snacks"|"toggleterm"|"fterm"
---@field position? "float"|"bottom"|"top"|"left"|"right"|"tab"
---@field size? integer
---@field close_on_exit? boolean

---@class run.ProjectConfig
---@field trust? "prompt"|"always"|"never"
---@field filename? string

---@class run.UserConfig
---@field filetype? table<string, string|fun():string?|run.CommandSpec>
---@field terminal? run.TerminalConfig
---@field project? run.ProjectConfig
---@field notify? boolean

---@class run.CommandSpec
---@field name? string
---@field cmd string|fun():string?
---@field filetype? string

local M = {}

---@type run.UserConfig
M.defaults = {
  filetype = {},
  terminal = {
    backend = "auto",
    position = "bottom",
    size = 15,
    close_on_exit = false,
  },
  project = {
    trust = "prompt",
    filename = "run.nvim.lua",
  },
  notify = true,
}

---Active, fully-merged configuration. Re-assigned by `apply()`.
---@type run.UserConfig
M.values = vim.deepcopy(M.defaults)

local VALID_BACKENDS = { auto = true, builtin = true, snacks = true, toggleterm = true, fterm = true }
local VALID_POSITIONS = { float = true, bottom = true, top = true, left = true, right = true, tab = true }
local VALID_TRUST = { prompt = true, always = true, never = true }

local function _validate(c)
  vim.validate({
    filetype = { c.filetype, "table" },
    terminal = { c.terminal, "table" },
    project = { c.project, "table" },
    notify = { c.notify, "boolean" },
  })
  vim.validate({
    ["terminal.backend"] = {
      c.terminal.backend,
      function(v) return VALID_BACKENDS[v] == true end,
      "auto|builtin|snacks|toggleterm|fterm",
    },
    ["terminal.position"] = {
      c.terminal.position,
      function(v) return VALID_POSITIONS[v] == true end,
      "float|bottom|top|left|right|tab",
    },
    ["terminal.size"] = { c.terminal.size, "number" },
    ["terminal.close_on_exit"] = { c.terminal.close_on_exit, "boolean" },
    ["project.trust"] = {
      c.project.trust,
      function(v) return VALID_TRUST[v] == true end,
      "prompt|always|never",
    },
    ["project.filename"] = { c.project.filename, "string" },
  })
end

---Merge user opts into defaults and validate.
---@param opts? run.UserConfig
function M.apply(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  _validate(M.values)
end

---Lazy-bootstrap: if `setup()` was never called, run it with defaults.
---Lets users skip `setup({})` entirely and still hit the public API.
function M.ensure_setup()
  local run = require("run")
  if not run.did_setup then run.setup({}) end
end

return M
