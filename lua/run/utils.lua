local M = {}

M.deep_copy = function(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[M.deep_copy(k, s)] = M.deep_copy(v, s) end
    return setmetatable(res, getmetatable(obj))
end

M.fmt_cmd = function(cmd)
    if string.find(cmd, "%%f") then
        cmd = string.gsub(cmd, "%%f", vim.api.nvim_buf_get_name(0))
    end

    return cmd
end

function M.read_toml(proj_file)
    local toml = require("toml")

    local file = io.open(proj_file, "r")
    local toml_content = file:read("*a")
    file:close()

    -- Parse the TOML content
    local parsed_toml = toml.parse(toml_content)

    return parsed_toml
end

---Writes TOML to run.toml
---@param toml_content table
function M.write_toml(toml_content)
    local toml = require("toml")
    local proj_file = vim.fn.findfile("run.toml", ".;")
    local file = io.open(proj_file, "w")

    local toml_string = toml.encode(toml_content)
    local formatted_toml = M.fmt_toml(toml_string)

    file:write(formatted_toml)
    file:close()
end

---Formats a TOML string
---@param toml_string string
---@return string
function M.fmt_toml(toml_string)
    -- Move the settings block to the top
    local settings_block = toml_string:match("%[settings%][^%[]*")
    if settings_block then
        toml_string = toml_string:gsub("%[settings%][^%[]*", "")
        -- put newline at end if not there
        if not settings_block:match("\n$") then
            settings_block = settings_block .. "\n"
        end
        toml_string = settings_block .. toml_string
    end

    toml_string = toml_string:gsub("\n%[", "\n\n[")

    return toml_string
end

return M
