# run.nvim

A Neovim plugin for running scripts and commands with smart context awareness and project-specific configurations.

## Features

- Run commands based on filetype or project configuration
- Command chaining with error handling
- Environment variable support
- Conditional command execution
- Wait conditions for dependent commands

## Installation

Using `lazy.nvim`:
```lua
{
  "SpyicyDev/run.nvim",
  dependencies = {
    "numToStr/FTerm.nvim",
  },
  opts = {},
}
```

## Usage

### Key Bindings

- `<leader>rr`: Smart run command
  - Without project config: Runs filetype-specific default command
  - With project config: Runs project default or shows script menu
- `<leader>rt`: Open project script menu (if project config exists)

### Commands

- `:Run`: Same as `<leader>rr`
- `:RunSetDefault`: Set a default script for the current project
- `:RunReloadProj`: Reload the project configuration file

## Project Configuration

The plugin uses a `run.nvim.lua` file for project-specific configurations. Here are some examples:

### Basic Commands

```lua
return {
    -- Simple command
    test = {
        name = "Run Tests",
        cmd = "npm test"
    },

    -- Command with current file
    compile = {
        name = "Compile File",
        cmd = "gcc %f -o out"  -- %f is replaced with current file path
    }
}
```

### Command Chaining with Environment Variables

Commands can be chained and share environment variables:

```lua
return {
    test = {
        name = "Run Tests",
        -- Chain-wide environment variables
        env = {
            -- Static value
            NODE_ENV = "test",
            
            -- Dynamic value (function)
            TEST_DB = function()
                return vim.fn.getcwd() .. "/test.db"
            end,
            
            -- Conditional value
            DEBUG = {
                value = "1",
                when = function()
                    return vim.fn.filereadable(".debug") == 1
                end
            },
            
            -- Prompt user for value
            API_KEY = {
                prompt = "Enter API Key",
                type = "secret"  -- Won't show in terminal
            }
        },
        -- Commands share the environment
        cmd = {
            "npm run lint",
            "npm test",
            "npm run e2e"
        }
    },

    deploy = {
        name = "Deploy",
        env = {
            NODE_ENV = "production",
            DEPLOY_TARGET = "prod"
        },
        cmd = {
            "npm run build",
            "npm run deploy"
        }
    }
}
```

### Environment Variable Types

Environment variables can be defined in several ways:

```lua
env = {
    -- Static value
    SIMPLE = "value",

    -- Dynamic value (function)
    DYNAMIC = function()
        return "computed_value"
    end,

    -- Conditional value
    CONDITIONAL = {
        value = "value",
        when = function() return true end
    },

    -- User prompt
    PROMPT = {
        prompt = "Enter value",
        type = "string" | "secret"
    }
}
```

### Command Options

Each command in a chain can have these options:

- `when`: Function that returns true if command should run
- `continue_on_error`: Continue chain even if this command fails
- `always_run`: Run this command even if previous commands failed
- `wait_for`: Function that returns true when ready to proceed
- `timeout`: Seconds to wait for wait_for condition (default: 30)

Chain-level options:
- `env`: Environment variables for all commands
- `on_success`: Function called if all commands succeed
- `on_error`: Function called when a command fails
