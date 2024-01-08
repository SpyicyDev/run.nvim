local M = {}

local utils = require("run.utils")
local config = require("run.config")

M.setup = function(opts)
  config.setup(opts)

  M.setup_proj()
  vim.api.nvim_create_autocmd({ "DirChanged" }, {
    desc = "Setup run.toml on DirChanged",
    callback = function()
      M.setup_proj()
    end
  })

  vim.api.nvim_create_autocmd("BufReadPre", {
    desc = "Setup run keymap and user command",
    callback = function()
      vim.keymap.set("n", config.opts.keys["run"], function() M.run() end,
        { buffer = true, noremap = true, silent = false })

      vim.api.nvim_buf_create_user_command(0, "Run", function()
        M.run()
      end, { desc = "Run a Script" })

      if config.proj_file_exists then
        vim.keymap.set("n", config.opts.keys["run_proj"], function() M.run_proj() end,
          { buffer = true, noremap = true, silent = false })
      end
    end
  })
end

M.setup_proj = function()
  local proj_file = vim.fn.findfile("run.toml", ".;")
  if proj_file ~= "" then
    local parsed_toml = utils.read_toml(proj_file)

    for title, conf in pairs(parsed_toml) do
      config.proj = vim.tbl_deep_extend("keep", config.proj or {}, { [title] = conf })
    end

    config.proj_file_exists = true

    vim.api.nvim_create_user_command("RunSetDefault", function()
      M.set_default()
    end, { desc = "Set a Default Script" })
  else
    config.proj_file_exists = false
  end
end

M.reload_proj = function()
  config.proj = {}
  M.setup_proj()
end

local term = require("FTerm")

M.run = function()
  if not config.proj_file_exists then
    M.run_file()
  else
    if config.proj.settings and config.proj.settings["default"] ~= nil then
      M.run_proj_default()
    else
      M.run_proj()
    end
  end
end

M.run_file = function()
  local buf = vim.api.nvim_buf_get_name(0)
  local ftype = vim.filetype.match({ filename = buf })
  local exec = config.opts.filetype[ftype]
  if exec == nil then
    vim.notify("No default script found for filetype " .. ftype .. "!", vim.log.levels.ERROR, {
      title = "run.nvim"
    })
    return
  end
  if type(exec) == "function" then
    exec = exec()
  end
  exec = utils.fmt_cmd(exec)
  -- if exec starts with :
  if exec:sub(1, 1) == ":" then
    vim.cmd(exec:sub(2))
    return
  end
  if exec ~= nil then
    term.scratch({ cmd = exec })
  end
end

M.run_proj = function()
  local options = {}
  for _, entry in pairs(config.proj) do
    table.insert(options, entry.name)
  end
  table.insert(options, "Default for Filetype")
  vim.ui.select(options, {
    prompt = "Choose a script...",
  }, function(choice)
    if choice == "Default for Filetype" then
      M.run_file()
      return
    end

    local exec = ""
    for _, entry in pairs(config.proj) do
      if entry.name == choice then
        exec = entry.cmd
        break
      end
    end
    exec = utils.fmt_cmd(exec)
    if exec:sub(1, 1) == ":" then
      vim.cmd(exec:sub(2))
      return
    end
    term.scratch({ cmd = exec })
  end)
end

M.run_proj_default = function()
  local exec = config.proj[config.proj.settings["default"]].cmd
  exec = utils.fmt_cmd(exec)
  term.scratch({ cmd = exec })
end

M.set_default = function()
  if config.proj_file_exists ~= false then
    local options = {}
    for _, entry in pairs(config.proj) do
      table.insert(options, entry.name)
    end
    if config.proj.settings ~= nil and config.proj.settings["default"] ~= nil then
      table.insert(options, "Clear Default")
    end

    vim.ui.select(options, {
      prompt = "Choose a default script..."
    }, function(choice)
      if choice == "Clear Default" then
        config.proj.settings = nil
        utils.write_toml(config.proj)
        M.reload_proj()
        vim.notify("Default script cleared", vim.log.levels.INFO, {
          title = "run.nvim"
        })
        return
      end

      for title, entry in pairs(config.proj) do
        if entry.name == choice then
          config.proj.settings = vim.tbl_deep_extend("force", config.proj.settings or {}, { default = title })
          break
        end
      end

      utils.write_toml(config.proj)

      M.reload_proj()

      vim.notify("Default script set to " .. choice, vim.log.levels.INFO, {
        title = "run.nvim"
      })
    end)
  else
    vim.notify("No run.toml file found!", vim.log.levels.ERROR, {
      title = "run.nvim"
    })
  end
end

M.dump_opts = function()
  print(require("inspect").inspect(config.opts))
end

M.dump_proj = function()
  print(require("inspect").inspect(config.proj))
end

return M
