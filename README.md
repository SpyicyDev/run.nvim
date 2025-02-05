# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze.

## Features

- 🚀 **Command Management**
  - Project-specific commands
  - Filetype-specific defaults
  - Command chaining with conditions
  - Environment variable support
  - Vim and shell command integration

- 🎯 **Smart Execution**
  - Conditional command execution
  - Error handling and recovery
  - Command output in terminal
  - Pattern substitution (%f)

- 🌍 **Project Configuration**
  - Per-project command definitions
  - Hot-reloadable configuration
  - Default command selection
  - Environment variable inheritance

- 🛠️ **Developer Experience**
  - Intuitive command menu
  - Quick keyboard shortcuts
  - Status notifications
  - Automatic filetype detection

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "SpyicyDev/run.nvim",
    opts = {
        keys = {
            run = "<leader>rr",      -- Run default/menu
            run_proj = "<leader>rt", -- Show project menu
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

### Plugin Options

```lua
{
    -- Key mappings (set to false to disable)
    keys = {
        run = "<leader>rr",      -- Run default/menu
        run_proj = "<leader>rt", -- Show project menu
    },
    
    -- Default commands for filetypes
    filetype = {
        python = "python3 %f",
        lua = "lua %f",
        javascript = "node %f",
        -- Add more defaults...
    }
}
```

### Command Types

1. **Basic Shell Command**:
```lua
build = {
    name = "Build Project",
    cmd = "make"
}
```

2. **Command with Environment**:
```lua
test = {
    name = "Run Tests",
    cmd = "npm test",
    env = {
        NODE_ENV = "test"
    }
}
```

3. **Command Chain**:
```lua
deploy = {
    name = "Deploy",
    cmd = {
        "npm run build",
        { cmd = "npm run test", continue_on_error = true },
        "npm run deploy"
    }
}
```

4. **Conditional Command**:
```lua
lint = {
    name = "Lint",
    cmd = {
        { 
            cmd = "eslint .",
            when = function() 
                return vim.fn.filereadable(".eslintrc") 
            end
        }
    }
}
```

### Project Configuration (run.nvim.lua)

Create a `run.nvim.lua` file in your project root:

```lua
return {
    -- Commands
    build = {
        name = "Build",          -- Display name
        cmd = "make",           -- Command to run
        env = {                 -- Optional environment
            DEBUG = "1"
        }
    },

    -- Command chain
    test = {
        name = "Test",
        cmd = {
            "npm run lint",
            { cmd = "npm test", continue_on_error = true }
        }
    },

    -- Default command
    default = "build"           -- Sets default command
}
```

### Environment Variables

Environment variables can be defined in two ways:

1. **Static Values**:
```lua
env = {
    NODE_ENV = "development",
    DEBUG = "1"
}
```

2. **Dynamic Values**:
```lua
env = {
    PATH = function()
        return vim.fn.expand("$PATH") .. ":/usr/local/bin"
    end,
    TIMESTAMP = function()
        return os.date("%Y%m%d")
    end
}
```

Features:
- Inherits system environment
- Supports dynamic values via functions
- Project-specific overrides
- Command-specific variables

### Command Chaining

Command chains allow running multiple commands in sequence:

```lua
cmd = {
    "echo 'Starting...'",                        -- Basic command
    { cmd = "npm run build", continue_on_error = true }, -- Continue on error
    { 
        cmd = "npm test",                        -- Conditional execution
        when = function() return vim.v.shell_error == 0 end
    },
    { cmd = "echo 'Done'", always_run = true }   -- Always runs
}
```

Features:
- Sequential execution
- Error handling with `continue_on_error`
- Conditional execution with `when`
- Guaranteed execution with `always_run`
- Single terminal instance
- Environment inheritance

## Example Configurations

### Node.js Project
```lua
-- run.nvim.lua
return {
    dev = {
        name = "Development Server",
        cmd = "npm run dev",
        env = {
            NODE_ENV = "development",
            PORT = "3000"
        }
    },
    build = {
        name = "Production Build",
        cmd = {
            "npm run lint",
            { cmd = "npm test", continue_on_error = true },
            "npm run build"
        },
        env = {
            NODE_ENV = "production"
        }
    },
    default = "dev"
}
```

### Python Django Project
```lua
-- run.nvim.lua
return {
    server = {
        name = "Development Server",
        cmd = {
            { 
                cmd = "poetry install",
                when = function()
                    return vim.fn.filereadable("poetry.lock")
                end
            },
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
            "poetry run python manage.py test",
            { 
                cmd = "poetry run python manage.py migrate",
                when = function()
                    return vim.v.shell_error == 0
                end
            }
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
            { cmd = "cargo clippy", continue_on_error = true },
            "cargo test"
        }
    },
    run = {
        name = "Run with Args",
        cmd = function()
            local args = vim.fn.input("Args: ")
            return string.format("cargo run -- %s", args)
        end,
        env = {
            RUST_BACKTRACE = "1"
        }
    },
    default = "check"
}
```

## Usage

### Commands

- `:Run` - Run default command or show menu
- `:RunSetDefault` - Set default project command
- `:RunReloadProj` - Reload project configuration

### Key Mappings

- `<leader>rr` - Run default command or show menu
- `<leader>rt` - Show project command menu