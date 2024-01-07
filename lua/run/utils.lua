local M = {}

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

function M.write_toml(toml_content)
    local toml = require("toml")
    local proj_file = vim.fn.findfile("run.toml", ".;")
    local file = io.open(proj_file, "w")

    local toml_string = toml.encode(toml_content)
    local formatted_toml = M.fmt_toml(toml_string)

    file:write(formatted_toml)
    file:close()
end

function M.fmt_toml(toml_string)
    -- Find the [settings] block
    local settings_block = toml_string:match("[^\n]-\n%[settings%].-\n\n")

    -- Remove the [settings] block from the original TOML string
    toml_string = toml_string:gsub("[^\n]-\n%[settings%].-\n\n", "")

    -- Initialize the formatted TOML string with the [settings] block (if it exists)
    local formatted_toml = settings_block or ""

    -- Trim leading and trailing whitespace from the formatted TOML string
    formatted_toml = formatted_toml:match("^%s*(.-)%s*$")

    -- Iterate over each line of the TOML string
    for line in toml_string:gmatch("[^\r\n]+") do
        -- Check if the line is a TOML header (starts with '[')
        if line:sub(1, 1) == "[" then
            -- Add a newline before the TOML header, except for the first header
            if formatted_toml ~= "" then
                formatted_toml = formatted_toml .. "\n"
            end
        end

        -- Append the line to the formatted TOML string
        formatted_toml = formatted_toml .. line .. "\n"
    end

    return formatted_toml
end

return M
