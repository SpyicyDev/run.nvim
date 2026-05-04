return {
  test = {
    name = "Run test command",
    cmd = "echo 'testing run.nvim'",
  },
  hello = {
    name = "Hello world (function)",
    cmd = function()
      return "echo 'Hello from run.nvim function!'"
    end,
  },
  source_lua = {
    name = "Source current Lua file",
    cmd = ":luafile %",
    filetype = "lua",
  },
  default = "test",
}
