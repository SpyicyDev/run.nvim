---Configuration module for run.nvim
---@class Config
---@field opts table Plugin options
---@field proj table Project-specific configuration
---@field proj_file_exists boolean Whether a project configuration file exists
local config = {
    opts = {},
    proj = {},
    proj_file_exists = false
}

---Default configuration values
---@type table
local defaults = {
    keys = {
        run = "<leader>rr",
        run_proj = "<leader>rt",
    },
    filetype = {}
}

---Validate the configuration options
---@param opts table The configuration options to validate
---@return nil
---@error string Error message if validation fails
local function validate_config(opts)
    if opts.keys and type(opts.keys) ~= "table" then
        error("keys configuration must be a table")
    end
    
    if opts.filetype and type(opts.filetype) ~= "table" then
        error("filetype configuration must be a table")
    end
end

---Setup the configuration with user options
---@param opts table|nil User configuration options
---@return nil
function config.setup(opts)
    opts = opts or {}
    validate_config(opts)
    config.opts = vim.tbl_deep_extend("force", defaults, opts)
end

return config
