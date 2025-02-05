# run.nvim

A Neovim plugin for running scripts and commands with smart context awareness and project-specific configurations.

## Command Types

The plugin supports several types of commands:

- **Shell Commands**: Simple string commands that run in a terminal (e.g., `"npm test"`).
- **Vim Commands**: Commands prefixed with `:` that execute as Vim commands (e.g., `":w"`).
- **Command Chains**: Arrays of commands that execute sequentially with error handling.
- **Lua Functions**: Functions that can optionally return any of the above command types or nothing at all.

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
    build = {
        name = "Build Project",
        cmd = {
            "npm install",
            "npm run build",
            -- Lua function that returns a command or nil
            function()
                if vim.fn.filereadable("dist/index.js") == 1 then
                    return "npm run test"
                end
            end,
            -- Vim command
            ":echo 'Build complete!'"
        }
    }
}
```

### Conditional Commands

Commands can be made conditional using the `when` property:

```lua
return {
    build = {
        name = "Build and Test",
        cmd = {
            "npm run build",
            {
                cmd = "npm test",
                when = function()
                    return vim.fn.filereadable("dist/index.js") == 1
                end
            }
        }
    }
}
```

### Wait Conditions

Commands can wait for conditions using the `wait_for` property:

```lua
return {
    start = {
        name = "Start Server",
        cmd = {
            "npm start",
            {
                cmd = ":echo 'Server is ready!'",
                wait_for = function()
                    return vim.fn.filereadable(".pid") == 1
                end,
                timeout = 10  -- Timeout in seconds (default: 30)
            }
        }
    }
}
```

### Error Handling

Commands can specify error handling behavior:

```lua
return {
    deploy = {
        name = "Deploy",
        cmd = {
            {
                cmd = "npm run lint",
                continue_on_error = true  -- Continue chain even if this fails
            },
            "npm run build",
            "npm run deploy",
            {
                on_success = function()
                    print("Deployment successful!")
                end,
                on_error = function(err)
                    print("Deployment failed: " .. err)
                end
            }
        }
    }
}
```
