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

local config_validation = require("run.utils.config_validation")

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
    -- Validate project configuration
    local is_valid, error_msg = config_validation.validate_config(proj_config)
    if not is_valid then
        return false, error_msg
    end

    -- Configuration is valid, store it
    config.proj = proj_config
    config.proj_file_exists = true
    return true, nil
end

return config
