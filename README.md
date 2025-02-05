# run.nvim

🚀 A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze. Execute shell commands, Vim commands, and Lua functions with ease, all while maintaining project-specific configurations.

[![Lua](https://img.shields.io/badge/Made%20with%20Lua-blue.svg?style=for-the-badge&logo=lua)](http://lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

## ✨ Features

### 🔄 Command Types
- **Shell Commands**
  - Execute any shell command in a terminal buffer
  - Access to environment variables
  - File path substitution with `%f`
  - Terminal output using FTerm.nvim
- **Vim Commands**
  - Execute any Vim command with `:` prefix
  - Direct access to Vim state
  - Buffer manipulation
  - Integration with other plugins
- **Lua Functions**
  - Dynamic command generation
  - Return command strings
  - Access to Neovim API
  - Complex command logic

### 🔗 Command Flow Control
- **Sequential Execution**
  - Run commands in order
  - Single terminal instance
  - Error handling
  - Exit code handling
- **Conditional Execution**
  - `when` functions for control flow
  - Skip conditions
  - Dynamic decision making
- **Error Handling**
  - `continue_on_error` option
  - Error reporting
  - Chain termination control
- **Guaranteed Execution**
  - `always_run` commands
  - Cleanup operations
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
- **System Integration**
  - Automatic PATH merging
  - Shell environment access
  - OS-specific variables

### 🛠️ Development Tools
- **File Integration**
  - Automatic path detection
  - File type recognition
  - Path substitution (`%f`)
  - Working directory handling
- **Project Configuration**
  - `run.nvim.lua` support
  - Hot reload capability
  - Default command setting
  - Project-wide settings

## 📦 Installation

### Requirements
- Neovim >= 0.8.0
- [FTerm.nvim](https://github.com/numToStr/FTerm.nvim) (required for terminal commands)

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'SpyicyDev/run.nvim',
    dependencies = {
        'numToStr/FTerm.nvim', -- Required for terminal commands
    },
    config = function()
        require('run').setup({
            -- your configuration here
        })
    end
}
```

## ⚙️ Configuration

Default configuration:
```lua
require('run').setup({
    keys = {
        run = "<leader>rr",      -- Run current file or project command
        run_proj = "<leader>rt", -- Show project commands menu
    },
    filetype = {
        -- Filetype-specific commands
        -- Example:
        -- python = "python3 %f",
        -- javascript = "node %f",
    }
})
```

## 📝 Project Configuration

Create a `run.nvim.lua` file in your project root:

```lua
return {
    -- Basic command configuration
    test = {
        name = "Run Tests",      -- Display name in selection menu
        cmd = "npm test",        -- Command to execute
        filetype = "javascript", -- Optional, limit to specific filetype
        env = {                  -- Optional environment variables
            NODE_ENV = "test"
        }
    },

    -- Command with function
    build = {
        name = "Build Project",
        cmd = function()
            return "npm run build"
        end
    },

    -- Command chain
    deploy = {
        name = "Deploy",
        cmd = {
            "npm run build",
            {
                cmd = "npm run test",
                continue_on_error = true
            },
            {
                cmd = "npm run deploy",
                when = function()
                    return vim.fn.filereadable("dist/index.js") == 1
                end
            }
        }
    },

    -- Set default command
    default = "test"
}
```

## 🎯 Usage

### Commands
- `:Run` - Run the current file's filetype command or project command
- `:RunSetDefault` - Set a default command from the project configuration (only when project config exists)
- `:RunReloadProj` - Reload the project configuration file

### Key Mappings
Default mappings (can be customized in setup):
- `<leader>rr` - Run the current file or project command
- `<leader>rt` - Open project commands menu (only when project config exists)

Note: All mappings are buffer-local and only set when keys are configured.

### Command Types
1. Shell Commands:
   ```lua
   cmd = "npm test"
   ```

2. Vim Commands:
   ```lua
   cmd = ":write | source %"
   ```

3. Lua Functions:
   ```lua
   cmd = function()
       return "echo " .. vim.fn.expand("%")
   end
   ```

### Command Chain Options
- `continue_on_error` - Continue chain if command fails
- `when` - Only run if condition is true
- `always_run` - Run even if previous commands failed

### Environment Variables
1. Static Values:
   ```lua
   env = {
       NODE_ENV = "development",
       PORT = "3000"
   }
   ```

2. Dynamic Values:
   ```lua
   env = {
       CURRENT_FILE = function()
           return vim.fn.expand("%:p")
       end
   }
   ```

Special Variables:
- `%f` - Expands to the current buffer's file path

## 📚 Documentation

For detailed documentation, see `:help run.nvim` in Neovim.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.