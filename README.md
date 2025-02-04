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
- `<leader>rt`: Open project script menu (if project config exists)

### Commands

- `:Run`: Same as `<leader>rr`
- `:RunSetDefault`: Set a default script for the current project
- `:RunReloadProj`: Reload the project configuration file

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

## Command Chaining

Commands can be chained to run sequentially in the same terminal:

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
                    return vim.fn.filereadable("e2e") == 1
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
            
            -- Error handling
            {
                cmd = "npm run lint",
                continue_on_error = true
            },
            
            -- Callbacks
            {
                on_success = function()
                    vim.notify("Build and test completed!")
                end,
                on_error = function(failed_cmd)
                    vim.notify("Failed at: " .. failed_cmd)
                end
            }
        }
    }
}
```

### Chain Options

- `when`: Function that returns true if command should run
- `wait_for`: Function that returns true when ready to proceed
- `timeout`: Seconds to wait for wait_for condition (default: 30)
- `continue_on_error`: Continue chain even if this command fails
- `on_success`: Function called if all commands succeed
- `on_error`: Function called when a command fails

## Environment Variables

Environment variables are specified at the chain level and apply to all commands in the chain:

```lua
return {
    test = {
        name = "Run Tests",
        -- Chain-wide environment
        env = {
            -- Static value
            NODE_ENV = "test",
            
            -- Dynamic value
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
            
            -- Prompt value
            API_KEY = {
                prompt = "Enter test API key",
                type = "secret"  -- Uses inputsecret
            }
        },
        cmd = {
            "npm run lint",
            "npm test",
            "npm run e2e"
        }
    }
}
```

### Environment Value Types

1. **Static Values**:
   ```lua
   KEY = "value"
   ```

2. **Dynamic Values**:
   ```lua
   KEY = function()
       return "computed_value"
   end
   ```

3. **Conditional Values**:
   ```lua
   KEY = {
       value = "value",
       when = function()
           return vim.fn.filereadable(".env") == 1
       end
   }
   ```

4. **Prompt Values**:
   ```lua
   KEY = {
       prompt = "Enter value",
       type = "string" | "secret"
   }
   ```
