# run.nvim

A Neovim plugin for running scripts and commands with smart context awareness and project-specific configurations.

## Project Description

`run.nvim` is a Neovim plugin that allows you to run scripts and commands directly from your Neovim editor. It provides a flexible and customizable way to execute commands based on:
1. The current filetype
2. Project-specific configurations
3. User-defined defaults

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

## Core Features

- **Filetype-Based Execution**: Automatically runs appropriate commands based on file type
- **Project-Specific Configurations**: Define custom commands per project
- **Default Script Selection**: Set and use default commands for quick access
- **Command Types Support**:
  - Shell commands (run in floating terminal)
  - Vim commands (prefixed with `:`)
  - Lua functions (that return either of the above)
- **Command Chaining**: Run multiple commands in sequence or parallel
- **File Path Substitution**: Use `%f` to reference the current file path

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

## Command Configuration

### Basic Commands

```lua
return {
  -- Simple shell command
  build = {
    name = "Build Project",
    cmd = "make all"
  },

  -- Vim command
  format = {
    name = "Format File",
    cmd = ":FormatWrite"
  },

  -- Dynamic command using Lua
  test = {
    name = "Run Tests",
    cmd = function()
      local file = vim.fn.expand("%:p")
      return "python -m pytest " .. file
    end
  }
}
```

### Command Chaining

The plugin supports running multiple commands either sequentially or in parallel. Here are the different ways to chain commands:

#### Sequential Execution
```lua
return {
  full_build = {
    name = "Full Build Pipeline",
    cmd = {
      sequence = {
        -- Simple command
        "npm run lint",
        
        -- Command with conditions
        {
          cmd = "npm run build",
          -- Only run if condition is met
          when = function()
            return vim.fn.filereadable("package.json") == 1
          end,
          -- Continue chain even if this fails
          continue_on_error = true
        },
        
        -- Command with environment variables
        {
          cmd = "docker build -t myapp .",
          env = {
            DOCKER_BUILDKIT = "1"
          }
        },
        
        -- Command with wait condition
        {
          cmd = "docker-compose up -d",
          -- Wait for service to be ready
          wait_for = function()
            return vim.fn.system("docker-compose ps | grep healthy") ~= ""
          end,
          timeout = 30  -- seconds
        }
      },
      -- Run on successful completion
      on_success = function()
        vim.notify("Build completed successfully!")
      end,
      -- Run if any command fails
      on_error = function(failed_cmd)
        vim.notify("Build failed at: " .. failed_cmd, vim.log.levels.ERROR)
      end
    }
  }
}
```

#### Parallel Execution
```lua
return {
  dev = {
    name = "Start Development Environment",
    cmd = {
      parallel = {
        -- Simple commands run in parallel
        "npm run watch",
        "npm run server",
        
        -- Command with custom terminal configuration
        {
          cmd = "docker-compose up",
          terminal = {
            position = "right",
            size = 0.4
          }
        }
      }
    }
  }
}
```

#### Mixed Execution
```lua
return {
  deploy = {
    name = "Deploy Application",
    cmd = {
      sequence = {
        -- First run tests
        "npm test",
        
        -- Then run build and docs in parallel
        {
          parallel = {
            "npm run build",
            "npm run docs"
          }
        },
        
        -- Finally deploy
        {
          cmd = "npm run deploy",
          -- Always run this command for cleanup
          always_run = true
        }
      }
    }
  }
}
```

### Command Options

#### Sequential Commands
- `when`: Function that returns boolean, determines if command should run
- `continue_on_error`: Boolean, continue chain even if this command fails
- `env`: Table of environment variables for this command
- `wait_for`: Function that returns boolean, waits until condition is met
- `timeout`: Number of seconds to wait for `wait_for` condition
- `always_run`: Boolean, run this command even if previous commands failed

#### Parallel Commands
- `terminal`: Configure terminal display
  - `position`: Where to place terminal ("left", "right", "top", "bottom")
  - `size`: Size of terminal (0-1 for percentage)

#### Chain-Level Options
- `on_success`: Function to run after successful completion
- `on_error`: Function to run when a command fails
- `continue_on_error`: Boolean, apply to all commands in chain

### Environment Variables

Environment variables can be specified in several ways:

```lua
return {
  test = {
    name = "Run Tests",
    cmd = {
      sequence = {
        {
          cmd = "npm test",
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
              condition = function()
                return vim.fn.exists("$CI") == 0
              end
            }
          }
        }
      }
    }
  }
}
```

## Error Handling

The plugin includes comprehensive error handling:
- Failed commands in a chain are reported with specific error messages
- Timeout conditions for long-running commands
- Environment variable validation
- Command validation before execution
- Terminal creation error handling

All errors are reported through Neovim's notification system.

## Customization

The plugin can be customized during setup:

```lua
require('run').setup({
  keys = {
    run = "<leader>rr",      -- Change main run keybinding
    run_proj = "<leader>rt", -- Change project menu keybinding
  },
  -- Add filetype-specific default commands
  filetype = {
    python = "python3 %f",
    rust = "cargo run",
    cpp = "g++ %f -o out && ./out",
  }
})
```
