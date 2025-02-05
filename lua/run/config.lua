local config = {
    opts = {},
    proj = {},
    proj_file_exists = false
}

local defaults = {
    keys = {
        run = "<leader>rr",
        run_proj = "<leader>rt",
    },
    filetype = {}
}

-- Validate configuration
local function validate_config(opts)
    if opts.keys and type(opts.keys) ~= "table" then
        error("keys configuration must be a table")
    end
    
    if opts.filetype and type(opts.filetype) ~= "table" then
        error("filetype configuration must be a table")
    end
end

function config.setup(opts)
    opts = opts or {}
    validate_config(opts)
    config.opts = vim.tbl_deep_extend("force", defaults, opts)
end

return config
