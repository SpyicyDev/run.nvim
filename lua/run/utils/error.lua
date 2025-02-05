local M = {}

-- Import notify module
local notify = require("run.utils.notify").notify

---Error types enum
M.ERROR_TYPE = {
    CONFIGURATION = "configuration",
    COMMAND = "command",
    PROJECT = "project",
    ENVIRONMENT = "environment",
    SYSTEM = "system",
    VALIDATION = "validation"
}

---Error severity levels
M.SEVERITY = {
    ERROR = vim.log.levels.ERROR,
    WARN = vim.log.levels.WARN,
    INFO = vim.log.levels.INFO
}

---Format error message with context
---@param message string The error message
---@param context table|nil Additional context for the error
---@return string formatted_message The formatted error message
local function format_error(message, context)
    if not context then return message end
    
    local parts = { message }
    
    if context.file then
        table.insert(parts, string.format("File: %s", context.file))
    end
    
    if context.line then
        table.insert(parts, string.format("Line: %d", context.line))
    end
    
    if context.details then
        table.insert(parts, string.format("Details: %s", context.details))
    end
    
    return table.concat(parts, "\n")
end

---Create an error object
---@param error_type string The type of error (from ERROR_TYPE)
---@param message string The error message
---@param context table|nil Additional context for the error
---@return table error The error object
local function create_error(error_type, message, context)
    return {
        type = error_type,
        message = message,
        context = context,
        timestamp = os.time()
    }
end

---Handle an error with optional context
---@param error_type string The type of error (from ERROR_TYPE)
---@param message string The error message
---@param context table|nil Additional context for the error
---@param severity number|nil The severity level (from SEVERITY)
function M.handle_error(error_type, message, context, severity)
    -- Create error object
    local err = create_error(error_type, message, context)
    
    -- Format message
    local formatted_message = format_error(message, context)
    
    -- Default to ERROR severity if not specified
    severity = severity or M.SEVERITY.ERROR
    
    -- Notify user
    notify(formatted_message, severity, {
        title = string.format("run.nvim [%s]", error_type:upper()),
        icon = "⚠️"
    })
    
    -- Log error for debugging
    if _G.debug then
        vim.api.nvim_echo({
            { "run.nvim error: ", "ErrorMsg" },
            { vim.inspect(err), "Normal" }
        }, true, {})
    end
    
    return err
end

---Configuration error helper
---@param message string The error message
---@param context table|nil Additional context
---@return table error The error object
function M.config_error(message, context)
    return M.handle_error(M.ERROR_TYPE.CONFIGURATION, message, context)
end

---Command error helper
---@param message string The error message
---@param context table|nil Additional context
---@return table error The error object
function M.command_error(message, context)
    return M.handle_error(M.ERROR_TYPE.COMMAND, message, context)
end

---Project error helper
---@param message string The error message
---@param context table|nil Additional context
---@return table error The error object
function M.project_error(message, context)
    return M.handle_error(M.ERROR_TYPE.PROJECT, message, context)
end

---Environment error helper
---@param message string The error message
---@param context table|nil Additional context
---@return table error The error object
function M.env_error(message, context)
    return M.handle_error(M.ERROR_TYPE.ENVIRONMENT, message, context)
end

---System error helper
---@param message string The error message
---@param context table|nil Additional context
---@return table error The error object
function M.system_error(message, context)
    return M.handle_error(M.ERROR_TYPE.SYSTEM, message, context)
end

---Validation error helper
---@param message string The error message
---@param context table|nil Additional context
---@return table error The error object
function M.validation_error(message, context)
    return M.handle_error(M.ERROR_TYPE.VALIDATION, message, context)
end

---Warning helper
---@param message string The warning message
---@param context table|nil Additional context
---@return table error The error object
function M.warning(message, context)
    return M.handle_error(M.ERROR_TYPE.SYSTEM, message, context, M.SEVERITY.WARN)
end

---Info helper
---@param message string The info message
---@param context table|nil Additional context
---@return table error The error object
function M.info(message, context)
    return M.handle_error(M.ERROR_TYPE.SYSTEM, message, context, M.SEVERITY.INFO)
end

return M
