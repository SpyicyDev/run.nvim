# run.nvim

🚀 A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze. Execute shell commands, Vim commands, and Lua functions with ease, all while maintaining project-specific configurations.

[![Lua](https://img.shields.io/badge/Made%20with%20Lua-blue.svg?style=for-the-badge&logo=lua)](http://lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

## ✨ Features

- 🔄 **Multiple Command Types**
  - Shell commands with environment variables
  - Vim commands (starting with ":")
  - Dynamic Lua functions
  - Command chaining with conditional execution

- 🔗 **Smart Command Chaining**
  - Run multiple commands in sequence
  - Single terminal instance for all commands
  - Conditional execution with `when` functions
  - Error handling with `continue_on_error`
  - Guaranteed execution with `always_run`

- 🌍 **Environment Variables**
  - Project-specific environment variables
  - Dynamic variables using Lua functions
  - Automatic merging with system environment
  - Per-command environment overrides

- 🛠️ **Smart Features**
  - File path substitution with `%f`
  - Command validation and error handling
  - Colorful execution feedback
  - Project-specific configurations
  - Filetype-based command execution

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "SpyicyDev/run.nvim",
    dependencies = {
        "numToStr/FTerm.nvim",  -- Required for terminal execution
    },
    opts = {
        keys = {
            run = "<leader>rr",      -- Run default command
            run_proj = "<leader>rt", -- Show project command menu
        },
        filetype = {
            python = "python3 %f",
            lua = "lua %f",
            javascript = "node %f",
        }
    }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'SpyicyDev/run.nvim',
    requires = { 'numToStr/FTerm.nvim' },
    config = function()
        require('run').setup({
            -- Your configuration here
        })
    end
}
```

## ⚙️ Configuration

### Global Plugin Configuration

Configure default behavior in your Neovim config:

```lua
require('run').setup({
    -- Default key mappings
    keys = {
        run = "<leader>rr",      -- Run default command
        run_proj = "<leader>rt", -- Show project command menu
    },
    
    -- Default commands for filetypes
    filetype = {
        -- Basic shell command
        python = "python3 %f",
        
        -- Vim command
        lua = ":luafile %f",
        
        -- Function command
        javascript = function()
            local has_package = vim.fn.filereadable("package.json")
            return has_package and "npm run dev" or "node %f"
        end
    }
})
```

### Project Configuration

Create a `run.nvim.lua` file in your project root:

```lua
return {
    -- Basic command
    build = {
        name = "Build Project",
        cmd = "make",
        env = { BUILD_TYPE = "Release" }
    },

    -- Command chain with conditions
    test = {
        name = "Run Tests",
        cmd = {
            ":write",                                -- Save buffer
            { cmd = "make test", continue_on_error = true },
            {
                cmd = "npm test",
                when = function() return vim.v.shell_error == 0 end
            }
        },
        env = { NODE_ENV = "test" }
    },

    -- Interactive command
    dev = {
        name = "Development Server",
        cmd = function()
            local port = vim.fn.input("Port (default 3000): ")
            return string.format("npm run dev -- --port %s", port ~= "" and port or "3000")
        end,
        env = { NODE_ENV = "development" }
    },

    -- Set default command
    default = "build"
}
```

## 🎯 Usage

### Commands

- `:Run` - Execute the default command for current filetype or show project commands
- `:RunSetDefault` - Set a default command from project commands
- `:RunReloadProj` - Reload project configuration

### Default Keybindings

- `<leader>rr` - Run default command for current file/project
- `<leader>rt` - Show project command menu

### Command Types

1. **Shell Commands**
```lua
cmd = "make build"
```

2. **Vim Commands**
```lua
cmd = ":write"
```

3. **Lua Functions**
```lua
cmd = function()
    if vim.fn.filereadable("Cargo.toml") then
        return "cargo run"
    elseif vim.fn.filereadable("package.json") then
        return "npm start"
    end
    return "echo 'No project file found'"
end
```

### Environment Variables

1. **Static Variables**
```lua
env = {
    NODE_ENV = "development",
    DEBUG = "1"
}
```

2. **Dynamic Variables**
```lua
env = {
    -- Function that returns a value
    PATH = function()
        return vim.fn.expand("$PATH") .. ":/usr/local/bin"
    end,
    
    -- Git branch example
    GIT_BRANCH = function()
        return vim.fn.system("git branch --show-current"):gsub("\n", "")
    end
}
```

### Advanced Command Chaining

```lua
cmd = {
    ":write",                                -- Save current buffer
    { cmd = "npm run lint", continue_on_error = true },
    { 
        cmd = "npm test",
        when = function() 
            return vim.v.shell_error == 0 
        end
    },
    {
        cmd = "git push",
        always_run = true  -- Will run even if previous commands fail
    }
}
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT License - See [LICENSE](LICENSE) for details.