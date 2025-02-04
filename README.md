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

## Plugin Flow

### 1. Command Execution Flow

When you trigger a run command (`<leader>rr` or `:Run`), the plugin follows this decision tree:

1. **Check for Project Config**:
   - If no `run.nvim.lua` exists:
     - Run filetype-specific default command
   - If `run.nvim.lua` exists:
     - If project default is set:
       - Run the default project command
     - If no default:
       - Show project script selection menu

2. **Project Script Menu** (`<leader>rt`):
   - Lists all available scripts for current context
   - Filters scripts based on filetype if specified
   - Includes "Default for Filetype" option if available
   - Single option is executed immediately
   - Multiple options show selection menu

### 2. Command Types and Processing

Commands can be specified in three ways:

1. **Shell Commands**:
   ```lua
   cmd = "python3 main.py"
   ```
   - Executed in floating terminal via FTerm
   - Supports `%f` substitution for current file path

2. **Vim Commands**:
   ```lua
   cmd = ":PeekOpen"
   ```
   - Prefixed with `:`
   - Executed directly as Vim commands

3. **Lua Functions**:
   ```lua
   cmd = function()
     -- Do some processing
     if vim.fn.filereadable("tests") == 1 then
       return "cargo test"    -- Return shell command
     elseif vim.fn.filereadable("doc") == 1 then
       return ":Telescope help_tags"  -- Return vim command
     end
     -- Return nil to do nothing
     return nil
   end
   ```
   - Can return:
     - A shell command string (run in terminal)
     - A vim command string (prefixed with `:`)
     - `nil` to perform no action
   - Useful for dynamic command selection based on context

## Project Configuration

### Location and Loading

- Plugin searches for `run.nvim.lua` in current and parent directories
- Reloads configuration on directory changes
- Can be manually reloaded with `:RunReloadProj`

### Configuration Format

```lua
return {
  -- Basic shell command
  cmd_a = {
    name = "Run Python Script",
    cmd = "python3 main.py"
  },

  -- Command with current file
  cmd_b = {
    name = "Compile Current File",
    cmd = "gcc %f -o output"
  },

  -- Filetype-specific command
  cmd_c = {
    name = "Run Tests",
    cmd = "cargo test",
    filetype = "rust"  -- Only shown for Rust files
  },

  -- Vim command
  cmd_d = {
    name = "Format File",
    cmd = ":FormatWrite"
  },

  -- Dynamic command using Lua
  cmd_e = {
    name = "Custom Build",
    cmd = function()
      local file = vim.fn.expand("%:p")
      if vim.fn.filereadable(file) == 0 then
        vim.notify("No file to build", vim.log.levels.ERROR)
        return nil
      end
      return "make " .. file
    end
  },

  -- Optional: Set default command
  default = "cmd_a"  -- Will run "Run Python Script" by default
}
```

### Error Handling

The plugin includes comprehensive error handling for:
- Missing or invalid configurations
- Failed command execution
- Invalid file paths
- Missing dependencies
- Runtime errors in Lua functions

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
    -- Add more as needed
  }
})
