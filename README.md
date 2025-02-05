# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze. Execute shell commands, Vim commands, and Lua functions with ease, all while maintaining project-specific configurations.

## Features

- 🚀 Execute commands based on filetype or project context
- 🔄 Chain multiple commands with conditional execution
- 🌍 Dynamic environment variables and file path substitution
- ⚡ Support for shell commands, Vim commands, and Lua functions
- 📁 Project-specific configuration via `run.nvim.lua`
- 🎯 Default command selection for quick access
- 🔍 Interactive command selection menu
- 📝 Automatic reloading of project configuration on directory change
- 📣 Visual feedback in the terminal for each command execution

## Requirements

- Neovim >= 0.8.0
- [FTerm.nvim](https://github.com/numToStr/FTerm.nvim) (required for terminal command execution)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'SpyicyDev/run.nvim',
    dependencies = {
        'numToStr/FTerm.nvim',
    },
    opts = {
        -- your configuration here
    },
}
```

## Configuration

### Default Configuration

```lua
require('run').setup({
    keys = {
        run = "<leader>rr",      -- Run current file or project command
        run_proj = "<leader>rt", -- Show project commands menu
    },
    filetype = {
        -- Filetype-specific commands
    }
})
```

### Example Configuration with All Features

```lua
require('run').setup({
    keys = {
        run = "<leader>rr",
        run_proj = "<leader>rt",
    },
    filetype = {
        -- Shell command with file substitution
        python = "python3 %f",
        
        -- Vim command (prefixed with :)
        lua = ":luafile %f",
        
        -- Function that returns a command
        javascript = function()
            local file = vim.fn.expand("%:p")
            return string.format("node %s", file)
        end,
        
        -- Command with environment variables
        rust = {
            cmd = "cargo run",
            env = {
                RUST_BACKTRACE = "1"
            }
        }
    }
})
```

## Project Configuration File

The `run.nvim.lua` file in your project root defines project-specific commands and configurations. It should return a Lua table with your command configurations.

### Basic Structure

```lua
return {
    command_id = {
        name = "Display Name",      -- Name shown in selection menu
        cmd = "command to run",     -- Command or command chain
        filetype = "filetype",      -- Optional, limit to specific filetype
        env = {                     -- Optional environment variables
            KEY = "value"
        }
    },
    default = "command_id"          -- Optional default command
}
```

## Commands

- `:Run` - Execute current file or project command
- `:RunSetDefault` - Set default command from project configuration
- `:RunReloadProj` - Reload project configuration file

## Command Types

### Single Commands

1. **Shell Commands**
   ```lua
   cmd = "npm test"
   ```

2. **Vim Commands**
   ```lua
   cmd = ":write | source %"
   ```

3. **Lua Functions**
   ```lua
   cmd = function()
       return "echo " .. vim.fn.expand("%")
   end
   ```

### Command Chains

Command chains allow executing multiple commands in sequence with advanced control flow:

```lua
cmd = {
    "npm run clean",              -- Basic command
    {
        cmd = "npm test",         -- Command with options
        continue_on_error = true  -- Continue chain even if this fails
    },
    {
        cmd = "npm run build",    -- Conditional command
        when = function()         -- Only runs if condition is true
            return vim.fn.filereadable("package.json") == 1
        end
    },
    {
        cmd = "npm run deploy",   -- Always run command
        always_run = true         -- Runs even if previous commands failed
    },
    {
        on_success = function()   -- Success callback
            vim.notify("Build succeeded!")
        end
    },
    {
        on_error = function()     -- Error callback
            vim.notify("Build failed!", vim.log.levels.ERROR)
        end
    }
}
```

Command Chain Features:
- `continue_on_error` - Continue executing chain even if this command fails
- `when` - Conditional execution based on a function return value
- `always_run` - Command runs regardless of previous command failures
- `on_success` - Callback function executed if all commands succeed
- `on_error` - Callback function executed if any command fails

## Environment Variables

Environment variables can be specified in two ways:

### Static Values
```lua
env = {
    NODE_ENV = "development",
    PORT = "3000"
}
```

### Dynamic Values
```lua
env = {
    CURRENT_FILE = function()
        return vim.fn.expand("%:p")
    end,
    GIT_BRANCH = function()
        return vim.fn.system("git branch --show-current"):gsub("\n", "")
    end
}
```

## Configuration Options Reference

| Option | Location | Type | Required | Description |
|--------|----------|------|----------|-------------|
| `name` | Command config | string | No | Display name in selection menu |
| `cmd` | Command config | string \| function \| table | Yes | Command to execute |
| `filetype` | Command config | string | No | Limit command to specific filetype |
| `env` | Command config | table | No | Environment variables |
| `continue_on_error` | Chain command | boolean | No | Continue chain if command fails |
| `when` | Chain command | function | No | Condition for command execution |
| `always_run` | Chain command | boolean | No | Run command even if chain has failed |
| `on_success` | Chain command | function | No | Callback on successful chain completion |
| `on_error` | Chain command | function | No | Callback on chain failure |
| `default` | Root config | string | No | Default command ID |

## Example run.nvim.lua Files

### Web Development Project
```lua
return {
    dev = {
        name = "Start Development Server",
        cmd = {
            {
                cmd = "npm install",
                continue_on_error = true
            },
            "npm run dev"
        },
        env = {
            NODE_ENV = "development",
            PORT = "3000"
        }
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if vim.fn.filereadable(test_file) == 1 then
                return "npm test " .. test_file
            else
                return "npm test"
            end
        end,
        filetype = "javascript"
    },
    
    build = {
        name = "Production Build",
        cmd = {
            "npm run clean",
            {
                cmd = "npm run lint",
                continue_on_error = true
            },
            {
                cmd = "npm run build",
                when = function()
                    return vim.fn.filereadable("package.json") == 1
                end
            }
        },
        env = {
            NODE_ENV = "production"
        }
    },
    
    default = "dev"
}
```

### Rust Project
```lua
return {
    build = {
        name = "Build Project",
        cmd = {
            "cargo clean",
            {
                cmd = "cargo fmt",
                continue_on_error = true
            },
            "cargo build"
        },
        env = {
            RUST_BACKTRACE = "1"
        }
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if string.find(test_file, "test") then
                return string.format("cargo test %s", test_file)
            end
            return "cargo test"
        end
    },
    
    run = {
        name = "Run Current File",
        cmd = ":write | :terminal cargo run",
        filetype = "rust"
    },
    
    doc = {
        name = "Generate Documentation",
        cmd = {
            "cargo doc",
            {
                cmd = ":!open target/doc/$(basename $(pwd))/index.html",
                when = function()
                    return vim.fn.has("mac") == 1
                end
            }
        }
    },
    
    default = "run"
}
```
