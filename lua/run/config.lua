-- Configuration module for run.nvim
local config = {
    opts = {},
    proj = {},
    proj_file_exists = false
}

-- Default configuration values
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

---Load and validate project configuration from run.nvim.lua
---@param proj_config table The project configuration from run.nvim.lua
---@return boolean success Whether the configuration was loaded successfully
---@return string|nil error_message Error message if loading failed
function config.load_proj_config(proj_config)
    -- Validation is now done in utils.lua
    local utils = require("run.utils")
    local is_valid, error_msg = utils.validate_config(proj_config)
    if not is_valid then
        return false, error_msg
    end

    -- Configuration is valid, store it
    config.proj = proj_config
    config.proj_file_exists = true
    return true, nil
end

return config