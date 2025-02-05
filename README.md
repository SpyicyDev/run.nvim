# run.nvim

A powerful and flexible command execution plugin for Neovim that makes running project commands a breeze.

## Features

- 🚀 **Multiple Command Types**
  - Shell commands
  - Vim commands (starting with ":")
  - Dynamic Lua functions
  
- 🔗 **Command Chaining**
  - Run multiple commands in sequence
  - All commands execute in a single terminal instance
  - Colorful execution feedback
  - Error handling with continue_on_error
  - Conditional execution with when functions

- 🌍 **Environment Variables**
  - Project-specific environment variables
  - Dynamic environment variables using functions
  - Automatic merging with system environment

- 🎯 **Smart Command Processing**
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
        run = "<leader>rr",      -- Run default command
        run_proj = "<leader>rt", -- Show project command menu
    },
    -- Default commands for filetypes
    filetype = {
        python = "python3 %f",
        lua = "lua %f",
        rust = "cargo run",
        javascript = "node %f",
        -- Add more filetype defaults
    }
})
```

### Project Configuration (run.nvim.lua)

Create a `run.nvim.lua` file in your project root. This file should return a table with your project-specific commands:

```lua
-- run.nvim.lua
return {
    -- Basic command
    build = {
        name = "Build Project",    -- Display name in command menu
        cmd = "make",             -- Shell command to execute
        env = {                   -- Optional environment variables
            BUILD_TYPE = "Debug"
        }
    },

    -- Command chain
    test = {
        name = "Run Tests",
        cmd = {
            ":write",                                -- Save before testing
            { cmd = "make test", continue_on_error = true },
            {
                cmd = "npm test",
                when = function() return vim.v.shell_error == 0 end
            },
            { cmd = "echo 'Tests completed'", always_run = true }
        },
        env = {
            TEST_ENV = "development",
            NODE_ENV = "test"
        }
    },

    -- Dynamic command
    run = {
        name = "Smart Run",
        cmd = function()
            local file = vim.fn.expand("%:p")
            if vim.fn.executable(file) then
                return "./" .. file
            elseif vim.fn.filereadable("Cargo.toml") then
                return "cargo run"
            elseif vim.fn.filereadable("package.json") then
                return "npm start"
            end
            return nil  -- Skip if no valid command found
        end,
        env = {
            -- Dynamic environment variables
            PATH = function()
                return vim.fn.expand("$PATH") .. ":/usr/local/bin"
            end,
            -- Static environment variables
            DEBUG = "1"
        }
    }
}
```

### Configuration Fields

Each command in your `run.nvim.lua` can have the following fields:

1. **Required Fields**:
   - `name` (string): Display name for the command menu
   - `cmd` (string|function|table): Command(s) to execute

2. **Optional Fields**:
   - `env` (table): Environment variables for the command

3. **Command Types**:
   - String: Direct shell or Vim command
   - Function: Returns a command string or nil
   - Table: Array of commands to chain

4. **Chain Command Options**:
   ```lua
   {
       cmd = "command",              -- The command to run
       continue_on_error = true,     -- Continue chain if this fails
       always_run = true,            -- Run even if previous commands failed
       when = function() return true end  -- Condition for execution
   }
   ```

### Command Patterns

The following patterns in commands will be automatically replaced:
- `%f`: Current file path

### Environment Variables

Environment variables can be specified in two ways:

1. **Static Variables**:
   ```lua
   env = {
       NODE_ENV = "development",
       DEBUG = "1"
   }
   ```

2. **Dynamic Variables**:
   ```lua
   env = {
       PATH = function()
           return vim.fn.expand("$PATH") .. ":/custom/path"
       end,
       GIT_BRANCH = function()
           return vim.fn.system("git branch --show-current"):gsub("\n", "")
       end
   }
   ```

### Example Configurations

1. **Node.js Project**:
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
               { cmd = "npm run test", continue_on_error = true },
               "npm run build"
           },
           env = {
               NODE_ENV = "production"
           }
       }
   }
   ```

2. **Rust Project**:
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
       }
   }
   ```

3. **Python Project**:
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
               "poetry run python manage.py runserver"
           },
           env = {
               DJANGO_DEBUG = "1",
               PYTHONPATH = function()
                   return vim.fn.getcwd()
               end
           }
       }
   }
   ```

## Usage

### Basic Commands

```lua
-- Define commands in your project configuration
local config = {
    build = {
        cmd = "make",              -- Simple shell command
        env = {                    -- Project environment variables
            BUILD_ENV = "debug"
        }
    },
    test = {
        cmd = ":write | make test" -- Vim command followed by shell command
    }
}
```

### Command Chains

```lua
-- Chain multiple commands with error handling
local config = {
    build_and_test = {
        cmd = {
            ":write",                                -- Save current buffer
            { cmd = "make", continue_on_error = true }, -- Continue even if make fails
            {
                cmd = "npm test",
                when = function() return vim.v.shell_error == 0 end -- Only run if make succeeded
            },
            { cmd = "echo 'Done'", always_run = true }  -- Always runs at the end
        }
    }
}
```

### Dynamic Commands

```lua
-- Use functions for dynamic commands
local config = {
    run_file = {
        cmd = function()
            local file = vim.fn.expand("%:p")
            if vim.fn.executable(file) then
                return "./" .. file
            end
            return nil  -- Skip execution if file is not executable
        end
    }
}
```

### Environment Variables

```lua
-- Dynamic environment variables
local config = {
    build = {
        cmd = "make",
        env = {
            PATH = function()
                return vim.fn.expand("$PATH") .. ":/usr/local/bin"
            end,
            BUILD_DIR = "${PWD}/build",
            DEBUG = "1"
        }
    }
}
```

## Commands

- `:RunProject` - Run the default project command
- `:RunCommand {cmd}` - Run a specific command from your configuration
- `:RunSetDefault {cmd}` - Set the default command for the project

## Features in Detail

### Command Types

1. **Shell Commands**
   - Regular shell commands (e.g., "make", "npm test")
   - Executed in a persistent terminal window
   - Environment variables are properly merged

2. **Vim Commands**
   - Start with ":" (e.g., ":write", ":make")
   - Automatically converted to shell commands for chain execution
   - Can be mixed with other command types

3. **Function Commands**
   - Lua functions that return commands
   - Can return nil to skip execution
   - Full access to Neovim API

### Command Chain Options

1. **continue_on_error**
   ```lua
   { cmd = "risky-command", continue_on_error = true }
   ```
   - Chain continues even if this command fails

2. **always_run**
   ```lua
   { cmd = "cleanup", always_run = true }
   ```
   - Command runs regardless of previous failures

3. **when**
   ```lua
   {
       cmd = "npm test",
       when = function() return vim.v.shell_error == 0 end
   }
   ```
   - Conditional execution based on a function

### Environment Variables

1. **Static Variables**
   ```lua
   env = {
       DEBUG = "1",
       BUILD_TYPE = "Release"
   }
   ```

2. **Dynamic Variables**
   ```lua
   env = {
       PATH = function()
           return vim.fn.expand("$PATH") .. ":/custom/path"
       end
   }
   ```

## Contributing

Contributions are welcome! Please check out our [Contributing Guide](CONTRIBUTING.md) and [Developer Documentation](DEVELOPER.md).

## License

MIT License - see [LICENSE](LICENSE) for details