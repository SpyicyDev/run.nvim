local M = {}

local BACKEND_MODULE = {
  snacks = "snacks",
  toggleterm = "toggleterm",
  fterm = "FTerm",
}

function M.check()
  vim.health.start("run.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10+ detected")
  else
    vim.health.error("run.nvim requires Neovim 0.10 or newer")
    return
  end

  local ok, run = pcall(require, "run")
  if not ok then
    vim.health.error(("could not load run: %s"):format(run))
    return
  end
  if run.did_setup then
    vim.health.ok("setup() has been called")
  else
    vim.health.info("setup() not yet called (will lazy-bootstrap on first use)")
  end

  vim.health.start("run.nvim — terminal backends")
  local config = require("run.config")
  local backend_cfg = config.values.terminal.backend
  vim.health.info(("configured backend: %s"):format(backend_cfg))
  vim.health.ok("builtin :terminal — always available")

  for backend, modname in pairs(BACKEND_MODULE) do
    if pcall(require, modname) then
      vim.health.ok(("%s backend available (require '%s' OK)"):format(backend, modname))
    else
      vim.health.info(("%s backend not installed (optional)"):format(backend))
    end
  end

  if backend_cfg ~= "auto" and backend_cfg ~= "builtin" then
    local mod = BACKEND_MODULE[backend_cfg]
    if mod and not pcall(require, mod) then
      vim.health.warn(
        ("configured backend '%s' not installed; will fall back to built-in"):format(backend_cfg)
      )
    end
  end

  vim.health.start("run.nvim — project")
  local project = require("run.project")
  if project.has_project() then
    vim.health.ok(("project file: %s"):format(project.path()))
    vim.health.info(("commands: %d"):format(vim.tbl_count(project.commands())))
    if project.get_default() then
      vim.health.info(("default command: %s"):format(project.get_default()))
    end
  else
    vim.health.info("no run.nvim.lua in cwd or ancestors")
  end
end

return M
