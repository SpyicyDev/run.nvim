local cwd = vim.fn.getcwd()
local pack_root = cwd .. "/.tests/site"
local plenary_path = pack_root .. "/pack/deps/start/plenary.nvim"

vim.opt.runtimepath:prepend(cwd)
vim.opt.packpath:prepend(pack_root)

if vim.fn.isdirectory(plenary_path) == 0 then
  vim.notify("[run.nvim tests] cloning plenary.nvim into " .. plenary_path)
  vim.fn.mkdir(pack_root .. "/pack/deps/start", "p")
  vim.fn.system({
    "git",
    "clone",
    "--depth=1",
    "--filter=blob:none",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_path,
  })
end

vim.cmd("packloadall!")
require("plenary.busted")
