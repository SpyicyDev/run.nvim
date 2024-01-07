local config = {}

config.opts = {}
local defaults = require("run.defaults")

config.proj_file_exists = nil

config.proj = {}

function config.setup(opts)
    config.opts = vim.tbl_deep_extend("keep", opts or {}, defaults)
end

return config
