---@class run.PublicAPI
local M = {}

M.did_setup = false

---Initialize run.nvim. Idempotent: subsequent calls are no-ops.
---
---When using lazy.nvim with `opts = { ... }`, this is invoked automatically.
---Otherwise, the first public-API call will trigger setup with defaults.
---
---@param opts? run.UserConfig
function M.setup(opts)
  if M.did_setup then return end
  M.did_setup = true

  if vim.fn.has("nvim-0.10") == 0 then
    vim.notify("run.nvim requires Neovim 0.10 or newer", vim.log.levels.ERROR, { title = "run.nvim" })
    return
  end

  local config = require("run.config")
  local ok, err = pcall(config.apply, opts)
  if not ok then
    vim.notify(("run.nvim: invalid config: %s"):format(err), vim.log.levels.ERROR, { title = "run.nvim" })
    return
  end

  -- Autocmds register synchronously; they don't trigger UI prompts themselves.
  local aug = vim.api.nvim_create_augroup("run.nvim", { clear = true })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = aug,
    desc = "run.nvim: rediscover project on cwd change",
    callback = function() require("run.project").discover() end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = aug,
    pattern = config.values.project.filename,
    desc = "run.nvim: reload project on save",
    callback = function() M.reload_proj() end,
  })

  -- Defer the initial discover() so the synchronous load chain (e.g. lazy.nvim's
  -- VeryLazy batch) unwinds first. This lets UI plugins like noice/dressing/snacks
  -- install their cmdline/ui hooks BEFORE vim.secure.read's trust prompt fires —
  -- otherwise the prompt uses raw vim styling regardless of the user's UI setup.
  -- Skipped if a public API call (via ensure_setup) already triggered discover.
  vim.schedule(function()
    local project = require("run.project")
    if not project.did_initial_discover then project.discover() end
  end)
end

---Run the current file's filetype command, or fall back to project default
---if a project file is loaded.
---@return boolean ok
function M.run()
  require("run.config").ensure_setup()
  local project = require("run.project")
  if project.has_project() then
    if project.get_default() then return M.run_proj_default() end
    return M.run_proj()
  end
  return M.run_file()
end

---Run the configured filetype command for the current buffer.
---@return boolean ok
function M.run_file()
  require("run.config").ensure_setup()
  local config = require("run.config")
  local util = require("run.util")
  local runner = require("run.runner")

  local ft = util.buffer_filetype(0)
  if not ft or ft == "" then
    util.notify("could not determine filetype for current buffer", vim.log.levels.ERROR)
    return false
  end

  local entry = config.values.filetype[ft]
  if entry == nil then
    util.notify(("no filetype command configured for '%s'"):format(ft), vim.log.levels.ERROR)
    return false
  end

  if type(entry) == "string" or type(entry) == "function" then return runner.execute({ cmd = entry }) end
  if type(entry) == "table" then
    if entry.cmd == nil then
      util.notify(("filetype '%s' entry missing 'cmd'"):format(ft), vim.log.levels.ERROR)
      return false
    end
    return runner.execute(entry)
  end

  util.notify(("filetype '%s' entry must be string, function, or table"):format(ft), vim.log.levels.ERROR)
  return false
end

---Show project commands menu (and a "filetype default" option if applicable).
---@return boolean ok
function M.run_proj()
  require("run.config").ensure_setup()
  local project = require("run.project")
  local config = require("run.config")
  local util = require("run.util")
  local ui = require("run.ui")
  local runner = require("run.runner")

  if not project.has_project() then
    util.notify("no project configuration found (looking for run.nvim.lua)", vim.log.levels.WARN)
    return false
  end

  local ft = util.buffer_filetype(0)
  local items = {}

  for id, spec in pairs(project.commands()) do
    if spec.filetype == nil or spec.filetype == ft then
      table.insert(items, {
        id = id,
        kind = "project",
        display = spec.name or id,
        spec = spec,
      })
    end
  end

  table.sort(items, function(a, b) return a.display < b.display end)

  if ft and config.values.filetype[ft] then
    table.insert(items, {
      kind = "filetype",
      display = ("[filetype default: %s]"):format(ft),
    })
  end

  local executed = false
  ui.pick(items, "run.nvim — choose a command", function(item)
    if not item then return end
    if item.kind == "filetype" then
      executed = M.run_file()
    else
      executed = runner.execute(item.spec)
    end
  end)
  return executed
end

---Run the persisted default project command.
---@return boolean ok
function M.run_proj_default()
  require("run.config").ensure_setup()
  local project = require("run.project")
  local util = require("run.util")
  local runner = require("run.runner")

  if not project.has_project() then
    util.notify("no project configuration found", vim.log.levels.WARN)
    return false
  end

  local default_id = project.get_default()
  if not default_id then
    util.notify("no default command set (use :RunSetDefault)", vim.log.levels.WARN)
    return false
  end

  local spec = project.commands()[default_id]
  if not spec then
    util.notify(("default command '%s' not found in project config"):format(default_id), vim.log.levels.ERROR)
    return false
  end

  return runner.execute(spec)
end

---Reload the project configuration file.
function M.reload_proj()
  require("run.config").ensure_setup()
  local project = require("run.project")
  project.discover()
  require("run.util").notify("project config reloaded", vim.log.levels.INFO)
end

---Show what `:Run` (or a named project command) would execute, without running it.
---@param cmd_id? string  project command id; nil = current filetype command
function M.preview_cmd(cmd_id)
  require("run.config").ensure_setup()
  local config = require("run.config")
  local project = require("run.project")
  local runner = require("run.runner")
  local util = require("run.util")

  local spec, label
  if cmd_id and cmd_id ~= "" then
    spec = project.commands()[cmd_id]
    if not spec then
      util.notify(("project command not found: %s"):format(cmd_id), vim.log.levels.ERROR)
      return
    end
    label = ("project '%s'"):format(cmd_id)
  else
    local ft = util.buffer_filetype(0)
    if not ft or ft == "" then
      util.notify("could not determine filetype for preview", vim.log.levels.ERROR)
      return
    end
    local entry = config.values.filetype[ft]
    if entry == nil then
      util.notify(("no filetype command configured for '%s'"):format(ft), vim.log.levels.ERROR)
      return
    end
    spec = type(entry) == "table" and entry or { cmd = entry }
    label = ("filetype '%s'"):format(ft)
  end

  local resolved = runner.preview(spec)
  if resolved == nil then
    util.notify(("%s: preview unavailable (skip / error / invalid spec)"):format(label), vim.log.levels.WARN)
    return
  end

  local safe, pattern = runner.check_safety(resolved)
  if not safe then
    util.notify(("%s would run (UNSAFE: matches %s): %s"):format(label, pattern, resolved), vim.log.levels.ERROR)
    return
  end

  util.notify(("%s would run: %s"):format(label, resolved), vim.log.levels.INFO)
end

---Pick and persist a default command for the current project.
function M.set_default()
  require("run.config").ensure_setup()
  local project = require("run.project")
  local util = require("run.util")
  local ui = require("run.ui")

  if not project.has_project() then
    util.notify("no project configuration found", vim.log.levels.WARN)
    return
  end

  local items = {}
  for id, spec in pairs(project.commands()) do
    table.insert(items, {
      id = id,
      kind = "project",
      display = spec.name or id,
      spec = spec,
    })
  end
  table.sort(items, function(a, b) return a.display < b.display end)

  if project.get_default() then table.insert(items, { kind = "clear", display = "[clear default]" }) end

  ui.pick(items, "run.nvim — set default", function(item)
    if not item then return end
    if item.kind == "clear" then
      project.persist_default(nil)
      util.notify("default cleared", vim.log.levels.INFO)
    else
      project.persist_default(item.id)
      util.notify(("default set to %s"):format(item.display), vim.log.levels.INFO)
    end
  end)
end

return M
