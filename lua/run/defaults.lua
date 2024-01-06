local defaults = {
    filetype = {
        python = [[
        if [ -f $dir/../pyproject.toml ] || [ -f $dir/pyproject.toml ]; then
            poetry run python3 %f
        else
            python3 %f
        fi
        ]],
    }
}

return defaults
