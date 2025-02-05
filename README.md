# run.nvim

A Neovim plugin for running scripts and commands with smart context awareness and project-specific configurations.

## Features

- Run commands based on filetype or project-specific configuration
- Command chaining with error handling
- Environment variable support

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

## Configuration

The following can be passed into opts:

- `keys` (table): Customize key mappings
  - `run` (string): Key for smart run command (default: `<leader>rr`)
  - `run_proj` (string): Key for opening project script menu (default: `<leader>rt`)
- `filetype` (table): Filetype-specific default commands mapping filetype strings to either string commands or functions that return string commands

This is an example configuration using the default keybinds:

```lua
opts = {
    filetype = {
        scala = function ()
            vim.notify("Execute 'sbt run' in a separate tmux window!")
        end,
        python = function()
            if vim.fn.findfile("pyproject.toml", ".;") ~= "" then
                return "poetry run python3 %f"
            else
                return "python3 %f"
            end
        end,
        rust = "cargo run",
        lua = "lua %f",
        markdown = ":MarkdownPreview",
        java = function()
            if vim.fn.findfile("build.gradle", ".;") ~= "" then
                return "./gradlew run"
            else
                return "java %f"
            end
        end,
        r = "rscript %f",
    },
},
```

## Usage

### Key Bindings

- run (default: `<leader>rr`): Smart run command
  - Without project config: Runs filetype-specific default command
  - With project config: Runs project default or shows script menu
- run_proj (default: `<leader>rt`): Open project script menu (if project config exists)

### Commands

- `:Run`: Same as run keybind
- `:RunSetDefault`: Set a default script for the current project
- `:RunReloadProj`: Reload the project configuration file

## Project Configuration

The plugin uses a `run.nvim.lua` file for project-specific configurations. It should be a simple file that returns a lua table. Here is the basic structure:

```lua
return {
    commandA = {
        name = "Command A",
        cmd = "make run"
    },
    commandB = {
        name = "Command B",
        cmd = ":PeekOpen"
    },
    commandC = {
        name = "Command C",
        cmd = function ()
            return "python3 %f"
        end
    }
}
```

Moving forward, this is the terminology and field types to be used:
- **Run Configuration**: an entry in the `run.nvim.lua` file with the following fields:
  - `name` (string): Display name for the command
  - `cmd` (string|function|table): The command(s) to execute
  - `env` (table, optional): Key-value pairs of environment variables
- **Command**: the command or one of the commands that will be run
- **Chain**: a series of commands to be run in sequence

### Basic Command Types and Auto Replacements

Commands can be specified in three ways:

1. **Shell Commands** (run in terminal):
   ```lua
   cmd = "npm test"
   ```

2. **Vim Commands** (prefixed with `:`):
   ```lua
   cmd = ":Telescope find_files"
   ```

3. **Lua Functions** (return nil or one of the above as a string):
   ```lua
   cmd = function()
     if vim.fn.filereadable("Cargo.toml") then
       return "cargo test"
     end
     return nil  -- Do nothing
   end
   ```

There can also be patterns that are replaced by things:

1. **File Path**: `%f` will be replaced with the current file path.

So far, this is the only replacement.

### Command Chaining

Commands can be chained using an array in the `cmd` field:

```lua
return {
    build_and_test = {
        name = "Build and Test",
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

- `cmd` (string|function): The command to run
- `when` (function, optional): Function that returns boolean indicating if command should run
- `continue_on_error` (boolean, optional): Continue chain even if this command fails
- `always_run` (boolean, optional): Run this command even if previous commands failed
- `wait_for` (function, optional): Function that returns boolean when ready to proceed
- `timeout` (number, optional): Seconds to wait for wait_for condition (default: 30)

Chain-level options:
- `on_success` (function, optional): Function called if all commands succeed
- `on_error` (function, optional): Function called when a command fails with the failed command string as parameter

### Environment Variables

Environment variables can be specified at the run configuration level and apply to the entire configuration's environment (all commands in a chain execute in this environment). The environment variables system supports both static and dynamic configurations:

1. **Static Environment Variables**:
```lua
return {
    test = {
        name = "Run Tests",
        env = {
            NODE_ENV = "test",
            DEBUG = "1"
        },
        cmd = "npm test"
    }
}
```

2. **Dynamic Environment Variables** using Lua functions:
```lua
return {
    build = {
        name = "Build Project",
        env = {
            BUILD_TIME = function()
                return os.date("%Y%m%d_%H%M%S")
            end,
            GIT_BRANCH = function()
                local handle = io.popen("git branch --show-current")
                local branch = handle:read("*a")
                handle:close()
                return string.gsub(branch, "\n", "")
            end
        },
        cmd = "npm run build"
    }
}
```

3. **Conditional Environment Variables** using tables with conditions:
```lua
return {
    deploy = {
        name = "Deploy",
        env = {
            NODE_ENV = {
                value = "production",
                when = function()
                    return vim.fn.getcwd():match("production")
                end,
                default = "development"
            },
            DEBUG = {
                value = "1",
                when = function()
                    return vim.fn.filereadable(".debug")
                end
            }
        },
        cmd = "npm run deploy"
    }
}
```

Environment variables are processed before command execution. For dynamic variables, the functions are called just before the command runs, ensuring up-to-date values. Conditional variables are evaluated based on their `when` function, falling back to their `default` value (if specified) when the condition is not met.
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
        cmd = "npm run build"
    }
}