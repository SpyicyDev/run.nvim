# run.nvim

A Neovim plugin for running scripts and commands with smart context awareness and project-specific configurations.

## Features

- Run commands based on filetype or project configuration
- Command chaining with error handling
- Environment variable support per command
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

### Command Chaining

Commands can be chained by using an array:

```lua
return {
    -- Basic command chain
    build_and_test = {
        name = "Build and Test",
        cmd = {
            "npm run build",
            "npm test"
        }
    },

    -- Advanced chain with error handling
    deploy = {
        name = "Deploy Application",
        cmd = {
            {
                cmd = "npm run lint",
                continue_on_error = true  -- Continue even if linting fails
            },
            {
                cmd = "npm run build",
                -- Only run if package.json exists
                when = function()
                    return vim.fn.filereadable("package.json") == 1
                end,
                -- Set environment for this command
                env = {
                    NODE_ENV = "production"
                }
            },
            -- Callbacks for the chain
            on_success = function()
                vim.notify("Deploy completed!", vim.log.levels.INFO)
            end,
            on_error = function(failed_cmd)
                vim.notify("Deploy failed at: " .. failed_cmd, vim.log.levels.ERROR)
            end
        }
    },

    -- Chain with dependencies
    test_with_db = {
        name = "Test with Database",
        cmd = {
            {
                cmd = "docker-compose up -d db",
                -- Wait for database to be ready
                wait_for = function()
                    return vim.fn.system("docker-compose ps db | grep healthy")
                end,
                timeout = 30  -- seconds
            },
            "npm run test",
            {
                cmd = "docker-compose down",
                always_run = true  -- Run even if tests fail
            }
        }
    }
}
```

### Command Options

When using command chains, each command can have these options:

- `cmd`: The command to run (string or function)
- `when`: Function that returns true if command should run
- `continue_on_error`: Continue chain even if this command fails
- `always_run`: Run this command even if previous commands failed
- `env`: Environment variables for this command
- `wait_for`: Function that returns true when ready to proceed
- `timeout`: Seconds to wait for wait_for condition (default: 30)

Chain-level options:
- `on_success`: Function called if all commands succeed
- `on_error`: Function called when a command fails

## Environment Variables

The plugin supports several ways to handle environment variables:

1. **Static Environment Variables**:
```lua
return {
    build = {
        name = "Build Project",
        cmd = "npm run build",
        env = {
            NODE_ENV = "production",
            DEBUG = "0"
        }
    }
}
```

2. **Dynamic Environment Variables**:
```lua
return {
    test = {
        name = "Run Tests",
        cmd = "npm test",
        env = {
            -- Function that returns a value
            TEST_DIR = function()
                return vim.fn.expand("%:p:h")
            end,
            -- Conditional environment variable
            DEBUG = {
                condition = function()
                    return vim.fn.filereadable(".debug") == 1
                end,
                value = "1"
            }
        }
    }
}
```

3. **Interactive Environment Variables**:
```lua
return {
    deploy = {
        name = "Deploy to Server",
        cmd = "deploy.sh",
        env_prompt = {
            SERVER_URL = {
                description = "Server URL",
                required = true,
                default = "https://staging.example.com",
                validate = function(value)
                    return value:match("^https?://") ~= nil
                end
            },
            API_KEY = {
                description = "API Key",
                required = true,
                force = true  -- Always prompt, even if already set
            },
            ENV = {
                description = "Environment",
                default = "staging",
                completion = "customlist,CompletionFunction"
            }
        }
    }
}
```

Environment variable options:

- **Static Values**: Direct string assignments
- **Dynamic Values**: Functions that return values
- **Conditional Values**: Tables with `condition` and `value`
- **Interactive Prompts**:
  - `description`: Prompt text
  - `required`: If true, value must be provided
  - `default`: Default value
  - `force`: Always prompt, even if variable exists
  - `completion`: Vim completion function
  - `validate`: Function to validate input

Environment variables are:
1. Set before command execution
2. Available to all commands in a chain
3. Automatically escaped for shell safety
4. Cleared after command completion

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

3. **Lua Functions** (return command or nil):
   ```lua
   cmd = function()
     if vim.fn.filereadable("Cargo.toml") then
       return "cargo test"
     end
     return nil  -- Do nothing
   end
   ```
