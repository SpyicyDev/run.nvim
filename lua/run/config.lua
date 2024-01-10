local config = {}

local defaults = {
    keys = {
        run = "<leader>rr",
        run_proj = "<leader>rt",
    }
}

function config.setup(opts)
    config.opts = {}

    config.proj_file_exists = nil

    config.proj = {}

    config.opts = vim.tbl_deep_extend("force", defaults, opts or {})
end

return config
