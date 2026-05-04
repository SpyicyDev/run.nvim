if vim.fn.has("nvim-0.10") == 0 then
  vim.api.nvim_echo({
    { "[run.nvim] requires Neovim 0.10 or newer.\n", "ErrorMsg" },
  }, true, {})
  return
end

if vim.g.loaded_run == 1 then
  return
end
vim.g.loaded_run = 1

local function dispatch(method)
  return function() require("run")[method]() end
end

vim.api.nvim_create_user_command("Run", dispatch("run"), {
  desc = "run.nvim: run current file or project command",
  nargs = 0,
})

vim.api.nvim_create_user_command("RunProj", dispatch("run_proj"), {
  desc = "run.nvim: pick a project command to run",
  nargs = 0,
})

vim.api.nvim_create_user_command("RunSetDefault", dispatch("set_default"), {
  desc = "run.nvim: set default project command",
  nargs = 0,
})

vim.api.nvim_create_user_command("RunReloadProj", dispatch("reload_proj"), {
  desc = "run.nvim: reload run.nvim.lua",
  nargs = 0,
})

vim.api.nvim_create_user_command("RunPreview", function(opts)
  require("run").preview_cmd(opts.args ~= "" and opts.args or nil)
end, {
  desc = "run.nvim: dry-run a command (no execution); arg = project command id",
  nargs = "?",
  complete = function()
    local ok, project = pcall(require, "run.project")
    if not ok or not project.has_project() then return {} end
    local ids = vim.tbl_keys(project.commands())
    table.sort(ids)
    return ids
  end,
})
