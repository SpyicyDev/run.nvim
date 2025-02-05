# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze.

## Features

- **Multiple Command Types**
  - Shell commands with environment variables
  - Vim commands (starting with ":")
  - Dynamic Lua functions
  - Command chaining with conditional execution
  
- **Command Chaining**
  - Run multiple commands in sequence
  - All commands execute in a single terminal instance
  - Conditional execution with `when` functions
  - Error handling with `continue_on_error`
  - Guaranteed execution with `always_run`

- **Environment Variables**
  - Project-specific environment variables
  - Dynamic variables using functions
  - Automatic merging with system environment
  - Per-command environment overrides

- **Smart Command Processing**
  - File path substitution (%f)
  - Command validation
  - Error handling and reporting
  - Colorful command execution feedback

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "SpyicyDev/run.nvim",
    dependencies = {
        "numToStr/FTerm.nvim",  -- Required for terminal execution
    },
    opts = {
        keys = {
            run = "<leader>rr",      -- Run default command
            run_proj = "<leader>rt", -- Show project command menu
        },
        filetype = {
            python = "python3 %f",
            lua = "lua %f",
            javascript = "node %f",
        }
    }
}
```

## Configuration

### Plugin Configuration

```lua
opts = {
    -- Default key mappings
    keys = {
        run = "<leader>rr",      -- Run default command
        run_proj = "<leader>rt", -- Show project command menu
    },
    -- Default commands for filetypes
    filetype = {
        -- Basic shell command
        python = "python3 %f",
        
        -- Vim command
        lua = ":luafile %f",
        
        -- Function command
        javascript = function()
            local has_package = vim.fn.filereadable("package.json")
            return has_package and "npm run dev" or "node %f"
        end
    }
})
```

### Command Types

1. **Shell Commands**: basic shell commands
   ```lua
   -- Basic shell command
   cmd = "make build"
   ```

2. **Vim Commands**: Vim commands
   ```lua
   -- Single Vim command
   cmd = ":write"
   ```

3. **Function Commands**: Lua function, can return one of above as a string or nil
   ```lua
   -- Dynamic command based on conditions
   cmd = function()
       if vim.fn.filereadable("Cargo.toml") then
           return "cargo run"
       elseif vim.fn.filereadable("package.json") then
           return "npm start"
       end
       return "echo 'No project file found'"
   end
   ```

### Project Configuration (run.nvim.lua)

Create a `run.nvim.lua` file in your project root:

```lua
return {
    -- Basic command
    build = {
        name = "Build Project",
        cmd = "make",
        env = {
            BUILD_TYPE = "Release"
        }
    },

    -- Command chain
    test = {
        name = "Run Tests",
        cmd = {
            ":write",                                -- Save buffer
            { cmd = "make test", continue_on_error = true },
            {
                cmd = "npm test",
                when = function() return vim.v.shell_error == 0 end
            }
        },
        env = {
            NODE_ENV = "test"
        }
    },

    -- Function command
    dev = {
        name = "Development Server",
        cmd = function()
            local port = vim.fn.input("Port (default 3000): ")
            return string.format("npm run dev -- --port %s", port ~= "" and port or "3000")
        end,
        env = {
            NODE_ENV = "development"
        }
    },

    -- Set default command
    default = "build"
}
```

### Environment Variables

Environment variables can be specified in two ways:

1. **Static Variables**:
   ```lua
   env = {
       NODE_ENV = "development",
       DEBUG = "1",
       PORT = "3000"
   }
   ```

2. **Dynamic Variables**:
   ```lua
   env = {
       -- Function that returns a value
       PATH = function()
           return vim.fn.expand("$PATH") .. ":/usr/local/bin"
       end,
       
       -- Git branch example
       GIT_BRANCH = function()
           return vim.fn.system("git branch --show-current"):gsub("\n", "")
       end,
       
       -- Project-specific path
       PROJECT_ROOT = function()
           return vim.fn.getcwd()
       end
   }
   ```

### Command Chaining

Command chains allow running multiple commands in sequence with advanced control flow:

```lua
cmd = {
    ":write",                                -- Save current buffer
    
    -- Continue chain even if this fails
    { cmd = "npm run lint", continue_on_error = true },
    
    -- Only run if previous command succeeded
    {
        cmd = "npm run test",
        when = function() return vim.v.shell_error == 0 end
    },
    
    -- Always runs, regardless of previous failures
    { cmd = "echo 'Done'", always_run = true }
}
```

Features:
1. **Error Control**:
   - `continue_on_error`: Continue chain if command fails
   - `always_run`: Execute regardless of previous failures

2. **Conditional Execution**:
   - `when`: Function that determines if command should run
   - Access to previous command results
   - Full access to Neovim API

3. **Command Types**:
   - Mix shell and Vim commands
   - Use function commands
   - Access environment variables

## Example Configurations

### Node.js Project
```lua
-- run.nvim.lua
return {
    dev = {
        name = "Development Server",
        cmd = {
            { 
                cmd = "npm install",
                when = function()
                    return vim.fn.filereadable("package-lock.json")
                end
            },
            "npm run dev"
        },
        env = {
            NODE_ENV = "development",
            PORT = "3000"
        }
    },
    
    build = {
        name = "Production Build",
        cmd = {
            "npm run lint",
            { cmd = "npm run test", continue_on_error = true },
            "npm run build"
        },
        env = {
            NODE_ENV = "production"
        }
    }
}
```

### Rust Project
```lua
-- run.nvim.lua
return {
    check = {
        name = "Check and Test",
        cmd = {
            "cargo fmt --all -- --check",
            "cargo clippy",
            { cmd = "cargo test", always_run = true }
        }
    },
    
    release = {
        name = "Release Build",
        cmd = function()
            local target = vim.fn.input("Target: ")
            if target ~= "" then
                return string.format("cargo build --release --target %s", target)
            end
            return "cargo build --release"
        end
    },
    
    default = "check"
}
```

### Python Django Project
```lua
-- run.nvim.lua
return {
    dev = {
        name = "Development Server",
        cmd = {
            {
                cmd = "poetry install",
                when = function()
                    return vim.fn.filereadable("poetry.lock")
                end
            },
            "poetry run python manage.py migrate",
            "poetry run python manage.py runserver"
        },
        env = {
            DJANGO_DEBUG = "1",
            PYTHONPATH = function()
                return vim.fn.getcwd()
            end
        }
    },
    
    test = {
        name = "Run Tests",
        cmd = {
            ":write",
            "poetry run python manage.py test",
            {
                cmd = "poetry run python manage.py test --failfast",
                when = function() return vim.v.shell_error ~= 0 end
            }
        },
        env = {
            DJANGO_SETTINGS_MODULE = "config.settings.test"
        }
    }
}