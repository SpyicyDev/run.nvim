-- Example run.nvim.lua configuration
return {
    test = {
        name = "Run Test",
        cmd = "echo 'Testing run.nvim'"
    },
    hello = {
        name = "Hello World",
        cmd = function()
            return "echo 'Hello from run.nvim function!'"
        end
    },
    lua_specific = {
        name = "Lua Command",
        cmd = ":echo 'This is a Vim command'",
        filetype = "lua"
    },
    default = "test"
}