# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze. Execute shell commands, Vim commands, and Lua functions with ease, all while maintaining project-specific configurations.

## Features

- 🚀 Execute commands based on filetype or project context
- 📄 File path substitution (`%f` gets replaced with the current file path)
- ⚡ Support for shell commands, Vim commands, and Lua functions
- 📁 Project-specific configuration via `run.nvim.lua`
- 🎯 Default command selection for quick access
- 🔍 Interactive command selection menu
- 📝 Automatic reloading of project configuration on directory change
- 📣 Terminal integration with FTerm.nvim

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
        -- your configuration here (see below)
    },
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'SpyicyDev/run.nvim',
    requires = {
        'numToStr/FTerm.nvim',
    },
    config = function()
        require('run').setup({
            -- your configuration here (see below)
        })
    end
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
        -- Will be used when no project configuration exists
    }
})
```

### Example Configuration

```lua
require('run').setup({
    keys = {
        run = "<leader>rr",      -- Run current file or project command
        run_proj = "<leader>rt", -- Show project commands menu
    },
    filetype = {
        -- Shell command with file substitution (%f becomes the current file path)
        python = "python3 %f",
        
        -- Vim command (prefixed with :)
        lua = ":luafile %f",
        
        -- Function that returns a command
        javascript = function()
            local file = vim.fn.expand("%:p")
            return string.format("node %s", file)
        end,
        
        -- Table configuration
        rust = {
            cmd = "cargo run"
        },
        
        -- TypeScript project commands
        typescript = {
            cmd = "npx ts-node %f"
        },

        -- C/C++ compilation
        c = "gcc -o %:r %f && ./%:r",
        cpp = "g++ -o %:r %f && ./%:r"
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
        cmd = "command to run",     -- Command to execute
        filetype = "filetype",      -- Optional, limit to specific filetype
    },
    default = "command_id"          -- Optional default command
}
```

## Commands

- `:Run` - Execute current file or project command
- `:RunSetDefault` - Set default command from project configuration (only available if project config exists)
- `:RunReloadProj` - Reload project configuration file

## Command Types

### Shell Commands

Regular shell commands are executed in a terminal via FTerm:

```lua
cmd = "npm test"
```

### Vim Commands

Vim commands (prefixed with `:`) are executed directly in Neovim:

```lua
cmd = ":write | source %"
```

### Lua Functions

Functions that return a command string:

```lua
-- Return a shell command
cmd = function()
    return "echo " .. vim.fn.expand("%")
end

-- Return a Vim command
cmd = function()
    return ":luafile " .. vim.fn.expand("%")
end

-- Return nil to skip execution
cmd = function()
    if vim.fn.filereadable("package.json") == 1 then
        return "npm test"
    end
    return nil  -- Skip if no package.json
end
```

Functions can:
- Return a shell command string
- Return a Vim command string (prefixed with `:`)
- Return `nil` to skip execution
- Perform complex logic to determine the appropriate command

## Automatic Configuration Reloading

The plugin automatically reloads the project configuration in the following cases:
- When changing directories (`:cd`, `:lcd`, etc.)
- When saving the `run.nvim.lua` file
- When manually running `:RunReloadProj`

## Command Execution Logic

When you run `:Run` or press the configured keybinding:

1. If no project configuration exists (`run.nvim.lua`):
   - The plugin tries to run the filetype-specific command for the current file
   - If no filetype command exists, it shows an error

2. If project configuration exists:
   - If a default command is set, it runs that command
   - If no default is set, it shows the command selection menu

## Configuration Options Reference

| Option | Location | Type | Description |
|--------|----------|------|-------------|
| `keys.run` | Setup | string | Keybinding to run current file or project command |
| `keys.run_proj` | Setup | string | Keybinding to show project commands menu |
| `filetype` | Setup | table | Map of filetype to commands |
| `name` | Command config | string | Display name in selection menu |
| `cmd` | Command config | string \| function | Command to execute |
| `filetype` | Command config | string | Limit command to specific filetype |
| `default` | Project config | string | Default command ID |

## Example Project Configuration Files

### JavaScript/TypeScript Project

```lua
return {
    dev = {
        name = "Start Development Server",
        cmd = "npm run dev"
    },
    
    build = {
        name = "Production Build",
        cmd = "npm run build"
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if vim.bo.filetype == "typescript" and string.match(test_file, "%.test%.ts$") then
                return "npm test -- " .. test_file
            else
                return "npm test"
            end
        end,
        filetype = "typescript"
    },
    
    lint = {
        name = "Lint Project",
        cmd = "npm run lint"
    },
    
    default = "dev"
}
```

### Rust Project

```lua
return {
    build = {
        name = "Build Project",
        cmd = "cargo build"
    },
    
    run = {
        name = "Run Project",
        cmd = "cargo run"
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if string.find(test_file, "_test%.rs$") or string.find(test_file, "/tests/") then
                return string.format("cargo test -- %s", vim.fn.fnamemodify(test_file, ":t:r"))
            end
            return "cargo test"
        end
    },
    
    check = {
        name = "Type Check",
        cmd = "cargo check"
    },
    
    doc = {
        name = "Generate Documentation",
        cmd = "cargo doc --open"
    },
    
    default = "run"
}
```

### Python Project

```lua
return {
    run = {
        name = "Run File",
        cmd = "python3 %f"
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if string.find(test_file, "test_") or string.find(test_file, "_test") then
                return string.format("python -m pytest %s -v", test_file)
            end
            return "python -m pytest"
        end
    },
    
    lint = {
        name = "Lint File",
        cmd = "flake8 %f"
    },
    
    venv = {
        name = "Activate Virtual Environment",
        cmd = ":term source venv/bin/activate"
    },
    
    default = "run"
}
```

## API

The plugin provides a Lua API for programmatic control:

```lua
-- Initialize the plugin with configuration options
require('run').setup({...})

-- Run the current file or project command
require('run').run()

-- Show the project commands menu
require('run').run_proj()

-- Run the default project command
require('run').run_proj_default()

-- Reload the project configuration file
require('run').reload_proj()

-- Set the default command from project configuration
require('run').set_default()
```

## Error Handling

The plugin provides helpful error notifications in the following cases:
- Missing key configuration
- Invalid project configuration format
- Project configuration file loading errors
- Command execution errors

For more information and bug reports, please visit the [GitHub repository](https://github.com/SpyicyDev/run.nvim).