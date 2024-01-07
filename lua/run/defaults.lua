local defaults = {
    filetype = {
        python = function()
            if vim.fn.findfile("pyproject.toml", ".;") ~= "" then
                return "poetry run python3 %f"
            else
                return "python3 %f"
            end
        end,
        lua = "lua %f",
    }
}

return defaults
