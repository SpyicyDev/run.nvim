# run.nvim Developer Documentation

## Overview
run.nvim is a Neovim plugin that provides a flexible command execution framework, focusing on project-specific commands, filetype integration, and user experience.

## Project Structure

```
run.nvim/
├── lua/
│   └── run/
│       ├── init.lua           # Plugin entry point and main functionality
│       ├── config.lua         # Configuration management
│       └── utils/
│           ├── init.lua       # Utils module aggregator
│           ├── notify.lua     # Notification utilities
│           ├── validation.lua # Input validation
│           └── path.lua       # Path and config file utilities
```

## Core Components

### 1. Main Module (init.lua)
The main module handles:
- Plugin initialization and setup
- Command execution and menu interface
- Project configuration management
- Keybinding and command registration

Key functions:
```lua
M.setup(opts)          -- Plugin initialization
M.run()               -- Main command execution
M.run_proj()          -- Project command menu
M.run_file()          -- Filetype-specific execution
M.set_default()       -- Set default command
```

### 2. Configuration (config.lua)
Manages plugin state and configuration:

```lua
local config = {
    opts = {},            -- Plugin options
    proj = {},            -- Project configuration
    proj_file_exists = false
}

-- Default configuration
local defaults = {
    keys = {
        run = "<leader>rr",
        run_proj = "<leader>rt",
    },
    filetype = {}
}
```

### 3. Utilities

#### Notification (notify.lua)
```lua
M.notify(msg, level)  -- Consistent notification interface
```

#### Validation (validation.lua)
```lua
M.validate_cmd(cmd)   -- Command validation
```

#### Path (path.lua)
```lua
M.write_conf()        -- Project config file handling
```

## Command Execution Flow

1. **Command Entry Points**:
   ```
   User Input
   ├── Key Mapping
   │   ├── <leader>rr → M.run()
   │   └── <leader>rt → M.run_proj()
   └── Commands
       ├── :Run → M.run()
       └── :RunSetDefault → M.set_default()
   ```

2. **Command Processing**:
   ```
   M.run()
   ├── Check Project Config
   │   ├── Yes → Use Project Command
   │   └── No → Use Filetype Command
   └── Execute Command
       ├── Validate
       ├── Process
       └── Execute
   ```

## Project Configuration

### 1. Structure
```lua
{
    command_name = {
        name = "Display Name",
        cmd = "command string",
        env = { -- optional
            VAR = "value"
        },
        filetype = "specific_type" -- optional
    },
    default = "command_name" -- optional
}
```

### 2. Loading Process
```
1. Find run.nvim.lua
2. Load configuration
3. Validate structure
4. Store in config.proj
```

## Best Practices

1. **Command Organization**:
   - Use descriptive command names
   - Group related commands
   - Set appropriate defaults

2. **Error Handling**:
   - Validate all inputs
   - Provide clear error messages
   - Handle missing configurations gracefully

3. **User Experience**:
   - Clear command names
   - Consistent notifications
   - Intuitive menu organization

## Contributing

When contributing to run.nvim:

1. **Code Style**:
   - Clear function names
   - Consistent error handling
   - Proper documentation

2. **Testing**:
   - Test command execution
   - Verify configuration loading
   - Check error cases

3. **Documentation**:
   - Update README.md
   - Update DEVELOPER.md
   - Add inline documentation

## Common Patterns

### 1. Project Configuration
```lua
return {
    build = {
        name = "Build Project",
        cmd = "make"
    },
    test = {
        name = "Run Tests",
        cmd = "npm test",
        filetype = "javascript"
    },
    default = "build"
}
```

### 2. Command Execution
```lua
-- Direct execution
M.run_cmd("command_name")

-- Menu selection
M.run_proj()

-- Filetype handling
M.run_file()
```

### 3. Configuration Validation
```lua
local function validate_config(opts)
    if opts.keys and type(opts.keys) ~= "table" then
        error("keys configuration must be a table")
    end
    
    if opts.filetype and type(opts.filetype) ~= "table" then
        error("filetype configuration must be a table")
    end
end
