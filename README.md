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

```lua
require("run").setup({
    -- Your configuration options here
})
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