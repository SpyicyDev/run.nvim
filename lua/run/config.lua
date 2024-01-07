local config = {}

local defaults = require("run.defaults")

function config.setup(opts)
    config.opts = {}

    config.proj_file_exists = nil

    config.proj = {}

    config.opts = vim.tbl_deep_extend("keep", opts or {}, defaults)
end

return config
