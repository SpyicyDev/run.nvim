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

## Command Types

Commands can be specified in three ways:

1. **Shell Commands** (run in terminal):
   ```lua
   cmd = "npm test"
   ```

2. **Vim Commands** (prefixed with `:`):
   ```lua
   cmd = ":Telescope find_files"
   ```

3. **Lua Functions**:
   ```lua
   cmd = function()
     if vim.fn.filereadable("Cargo.toml") then
       return "cargo test"  -- Returns a shell command
     elseif vim.fn.filereadable("package.json") then
       return ":Telescope find_files"  -- Returns a vim command
     end
     return nil  -- Returns nothing, no command will be executed
   end
   ```
   Lua functions can:
   - Return a shell command string
   - Return a vim command string (prefixed with `:`)
   - Return nil to do nothing

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

### Environment Variables

Environment variables are specified at the chain level and apply to all commands in the chain:

```lua
return {
    test = {
        name = "Run Tests",
        -- Environment variables for all commands
        env = {
            NODE_ENV = "test",
            DEBUG = "1",
            TEST_DB = "/path/to/test.db"
        },
        cmd = {
            "npm run lint",    -- Will run with above env
            "npm test",        -- Same env
            "npm run e2e"      -- Same env
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

### Command Chaining

Commands can be chained using an array:

```lua
return {
    build_and_test = {
        name = "Build and Test",
        env = {
            NODE_ENV = "test"
        },
        cmd = {
            -- Basic command chain
            "npm run build",
            "npm test",
            
            -- Command with condition
            {
                cmd = "npm run e2e",
                when = function()
                    return vim.fn.filereadable("e2e.config.js") == 1
                end
            },
            
            -- Command with wait condition
            {
                cmd = "docker-compose up -d db",
                wait_for = function()
                    return vim.fn.system("docker-compose ps db | grep healthy")
                end,
                timeout = 30  -- seconds
            },
            
            -- Callbacks for the chain
            on_success = function()
                vim.notify("All commands completed!", vim.log.levels.INFO)
            end,
            on_error = function(failed_cmd)
                vim.notify("Failed at: " .. failed_cmd, vim.log.levels.ERROR)
            end
        }
    }
}
```

### Command Options

Each command in a chain can have these options:

- `cmd`: The command to run (string or function)
- `when`: Function that returns true if command should run
- `continue_on_error`: Continue chain even if this command fails
- `always_run`: Run this command even if previous commands failed
- `wait_for`: Function that returns true when ready to proceed
- `timeout`: Seconds to wait for wait_for condition (default: 30)

Chain-level options:
- `env`: Environment variables table for all commands
- `on_success`: Function called if all commands succeed
- `on_error`: Function called when a command fails
