# run.nvim

🚀 A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze. Execute shell commands, Vim commands, and Lua functions with ease, all while maintaining project-specific configurations.

[![Lua](https://img.shields.io/badge/Made%20with%20Lua-blue.svg?style=for-the-badge&logo=lua)](http://lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

## ✨ Features

### 🔄 Command Types
- **Shell Commands**
  - Execute any shell command
  - Access to environment variables
  - File path substitution with `%f`
  - Command output in terminal buffer
- **Vim Commands**
  - Execute any Vim command with `:` prefix
  - Direct access to Vim state
  - Buffer manipulation
  - Integration with other plugins
- **Lua Functions**
  - Dynamic command generation
  - Conditional command execution
  - Access to Neovim API
  - Complex command logic
- **Command Chaining**
  - Sequential execution
  - Conditional chaining
  - Error handling
  - Guaranteed execution options

### 🔗 Command Flow Control
- **Sequential Execution**
  - Run commands in order
  - Single terminal instance
  - Command output preservation
  - Exit code handling
- **Conditional Execution**
  - `when` functions for control flow
  - Access to previous command results
  - Dynamic decision making
  - Skip conditions
- **Error Handling**
  - `continue_on_error` option
  - Error reporting
  - Chain termination control
  - Error status propagation
- **Guaranteed Execution**
  - `always_run` commands
  - Cleanup operations
  - Final status reporting
  - Resource cleanup

### 🌍 Environment Management
- **Project Variables**
  - Project-specific settings
  - Local development configs
  - Environment overrides
  - Path configurations
- **Dynamic Variables**
  - Function-based values
  - Runtime evaluation
  - Context-aware variables
  - System integration
- **System Integration**
  - Automatic PATH merging
  - Shell environment access
  - OS-specific variables
  - Tool-specific configs
- **Scoped Variables**
  - Command-level overrides
  - Chain-specific variables
  - Temporary overrides
  - Inheritance control

### 🛠️ Development Tools
- **File Integration**
  - Automatic path detection
  - File type recognition
  - Path substitution
  - Working directory handling
- **Project Configuration**
  - `run.nvim.lua` support
  - Hot reload capability
  - Default command setting
  - Project-wide settings
- **Command Validation**
  - Syntax checking
  - Dependency verification
  - Environment validation
  - Security checks
- **Execution Feedback**
  - Colorful status output
  - Error highlighting
  - Progress indication
  - Command timing

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

### Configuration Reference

#### Global Configuration Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `keys.run` | `string` | `"<leader>rr"` | Keybinding to run the default command |
| `keys.run_proj` | `string` | `"<leader>rt"` | Keybinding to show project command menu |
| `filetype` | `table` | `{}` | Table of filetype-specific commands |

#### Project Command Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | Yes | Display name for the command |
| `cmd` | `string\|function\|table` | Yes | Command to execute (see Command Options) |
| `env` | `table` | No | Environment variables for this command |

#### Command Chain Options
Commands within the `cmd` table can be either:
- A string for direct execution
- A function that returns a command string
- A table with the following options:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cmd` | `string\|function` | Yes | The command to execute |
| `continue_on_error` | `boolean` | No | Continue chain if this command fails |
| `when` | `function` | No | Function that determines if command should run |
| `always_run` | `boolean` | No | Run command even if previous commands failed |
| `env` | `table` | No | Environment variables for this specific command |

#### Environment Variable Options

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `string` | `string` | `"production"` | Static environment variable value |
| `function` | `function` | `function() return vim.fn.getcwd() end` | Dynamic environment variable value |

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