# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze.

## Features

- 🚀 **Project Command Management**
  - Project-specific command configuration
  - Default command support
  - Filetype-specific commands
  - Command menu for easy selection

- 🔗 **Command Integration**
  - Shell commands
  - Vim commands
  - Per-filetype default commands
  - Automatic command detection

- 🌍 **Project Configuration**
  - Project-specific `run.nvim.lua` file
  - Hot-reloading of configuration
  - Default command settings
  - Environment variable support

- 🎯 **User Experience**
  - Intuitive command menu
  - Keyboard shortcuts
  - Status notifications
  - Automatic file detection

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "SpyicyDev/run.nvim",
    config = function()
        require("run").setup()
    end
}
```

## Configuration

### Plugin Configuration

```lua
require("run").setup({
    -- Default key mappings (set to false to disable)
    keys = {
        run = "<leader>rr",      -- Run default/menu
        run_proj = "<leader>rt", -- Show project menu
    },
    -- Default commands for filetypes
    filetype = {
        python = "python3 %f",
        lua = "lua %f",
        javascript = "node %f",
        -- Add more filetype defaults
    }
})
```

### Project Configuration (run.nvim.lua)

Create a `run.nvim.lua` file in your project root:

```lua
return {
    -- Basic command
    build = {
        name = "Build Project",
        cmd = "make",
    },

    -- Command with environment
    test = {
        name = "Run Tests",
        cmd = "npm test",
        env = {
            NODE_ENV = "test"
        }
    },

    -- Default command setting
    default = "build", -- Sets 'build' as the default command

    -- Filetype-specific command
    dev = {
        name = "Dev Server",
        cmd = "npm run dev",
        filetype = "javascript" -- Only shows for JavaScript files
    }
}
```

## Usage

### Commands

- `:Run` - Run default command or show command menu
- `:RunSetDefault` - Set the default project command
- `:RunReloadProj` - Reload project configuration

### Key Mappings

- `<leader>rr` - Run default command or show menu
- `<leader>rt` - Show project command menu (when project config exists)

### Command Configuration

Each command in your `run.nvim.lua` can have:

1. **Required Fields**:
   - `name` (string): Display name in menu
   - `cmd` (string): Command to execute

2. **Optional Fields**:
   - `env` (table): Environment variables
   - `filetype` (string): Limit to specific filetype

### Special Features

1. **Default Commands**:
   - Set with `default = "command_name"`
   - Override with `:RunSetDefault`

2. **Filetype Commands**:
   - Global defaults in setup()
   - Project-specific in run.nvim.lua

3. **Command Pattern**:
   - `%f` - Current file path

## Examples

### Basic Project

```lua
-- run.nvim.lua
return {
    build = {
        name = "Build",
        cmd = "make"
    },
    run = {
        name = "Run",
        cmd = "./myapp"
    },
    default = "build"
}
```

### Web Project

```lua
-- run.nvim.lua
return {
    dev = {
        name = "Development",
        cmd = "npm run dev",
        env = {
            NODE_ENV = "development"
        }
    },
    build = {
        name = "Production Build",
        cmd = "npm run build",
        env = {
            NODE_ENV = "production"
        }
    },
    test = {
        name = "Run Tests",
        cmd = "npm test",
        filetype = "javascript"
    }
}