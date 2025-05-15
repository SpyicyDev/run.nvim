# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze. Execute shell commands, Vim commands, and Lua functions with ease, all while maintaining project-specific configurations.

## Features

- 🚀 Execute commands based on filetype or project context
- 📄 File path substitution
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
        
        -- Command with options
        rust = {
            cmd = "cargo run"
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
   - Throw an error to stop the command chain (unless `continue_on_error` is true)


## Automatic Configuration Reloading

The plugin automatically reloads the project configuration in the following cases:
- When changing directories (`:cd`, `:lcd`, etc.)
- When saving the `run.nvim.lua` file
- When manually running `:RunReloadProj`

## Error Handling

The plugin provides helpful error notifications in the following cases:
- Missing key configuration
- Invalid project configuration format
- Project configuration file loading errors
- Command execution errors

## Configuration Options Reference

| Option | Location | Type | Required | Description |
|--------|----------|------|----------|-------------|
| `name` | Command config | string | No | Display name in selection menu |
| `cmd` | Command config | string \| function | Yes | Command to execute |
| `filetype` | Command config | string | No | Limit command to specific filetype |
| `default` | Root config | string | No | Default command ID |

## Example run.nvim.lua Files

### Web Development Project
```lua
return {
    dev = {
        name = "Start Development Server",
        cmd = "npm run dev"
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
        cmd = "npm run build"
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
        cmd = "cargo doc"
    },
    
    default = "run"
}
```

For more information and bug reports, please visit the [GitHub repository](https://github.com/SpyicyDev/run.nvim).
