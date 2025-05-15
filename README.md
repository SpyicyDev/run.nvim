# 🚀 run.nvim

> A powerful and flexible command execution plugin for Neovim

[![Lua](https://img.shields.io/badge/Lua-blue.svg?logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.8+-57A143?logo=neovim)](https://neovim.io)

Run project commands, filetype-specific scripts, or custom commands with ease directly from Neovim. Supports shell commands, Vim commands, and dynamic Lua functions.

https://github.com/SpyicyDev/run.nvim/assets/your-username/your-repo/assets/demo.gif

## ✨ Features

- **Project-Aware Commands**: Define project-specific commands in `run.nvim.lua`
- **Filetype Support**: Automatic command selection based on file type
- **Multiple Command Types**:
  - Shell commands
  - Vim commands
  - Dynamic Lua functions
- **Smart Path Substitution**: Automatic `%f` replacement with current file path
- **Interactive Menu**: Easy command selection with Telescope/fzf-lua
- **Automatic Reloading**: Project config reloads on change or directory switch
- **Terminal Integration**: Seamless terminal execution with FTerm.nvim

## 📦 Requirements

- Neovim >= 0.8.0
- [FTerm.nvim](https://github.com/numToStr/FTerm.nvim) (for terminal command execution)

## ⚙️ Installation

Install with your favorite package manager:

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'SpyicyDev/run.nvim',
    dependencies = {
        'numToStr/FTerm.nvim',
    },
    config = function()
        require('run').setup({
            -- Your configuration here
        })
    end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'SpyicyDev/run.nvim',
    requires = {
        'numToStr/FTerm.nvim',
    },
    config = function()
        require('run').setup({
            -- Your configuration here
        })
    end
}
```

## 🔧 Configuration

### Default Configuration

```lua
require('run').setup({
    -- Key mappings
    keys = {
        run = "<leader>rr",      -- Run current file or project command
        run_proj = "<leader>rt", -- Show project commands menu
    },
    
    -- Filetype-specific commands
    -- Used when no project configuration exists
    filetype = {
        -- Your filetype commands here
    }
})
```

### Example Configuration

```lua
local function has_package_json()
    return vim.fn.filereadable("package.json") == 1
end

require('run').setup({
    keys = {
        run = "<leader>rr",
        run_proj = "<leader>rt",
    },
    filetype = {
        -- Simple shell command
        python = "python3 %f",
        
        -- Vim command
        lua = ":luafile %f",
        
        -- Dynamic Lua function
        javascript = function()
            local file = vim.fn.expand("%:p")
            return string.format("node %s", file)
        end,
        
        -- Table configuration
        rust = {
            cmd = "cargo run",
            name = "Run with Cargo"
        },
        
        -- Conditional command
        typescript = {
            cmd = function()
                if has_package_json() then
                    return "npm run start"
                end
                return "npx ts-node %f"
            end
        },
        
        -- C/C++ compilation
        c = "gcc -o %:r %f && ./%:r",
        cpp = "g++ -o %:r %f && ./%:r",
        
        -- Run tests if test file, otherwise run main file
        go = function()
            local filename = vim.fn.expand("%:t")
            if string.find(filename, "_test.go$") then
                return "go test -v"
            end
            return "go run %f"
        end
    }
})
```

## 📁 Project Configuration

Create a `run.nvim.lua` file in your project root to define project-specific commands:

```lua
return {
    -- Simple command
    test = {
        name = "Run Tests",
        cmd = "npm test"
    },
    
    -- Command with filetype restriction
    format = {
        name = "Format Code",
        cmd = "prettier --write %f",
        filetype = {"javascript", "typescript", "css", "json"}
    },
    
    -- Dynamic command
    start_dev = {
        name = "Start Dev Server",
        cmd = function()
            if vim.fn.filereadable("package.json") == 1 then
                return "npm run dev"
            end
            return "echo 'No dev script found in package.json'"
        end
    },
    
    -- Set default command
    default = "test"
}
```

## 🚀 Usage

### Commands

| Command           | Description                                      |
|-------------------|--------------------------------------------------|
| `:Run`           | Execute current file or project command         |
| `:RunSetDefault` | Set default command from project configuration   |
| `:RunReloadProj` | Reload project configuration file               |


### Key Mappings

| Key          | Mode | Description                                  |
|--------------|------|----------------------------------------------|
| `<leader>rr` | n    | Run current file or project command         |
| `<leader>rt` | n    | Show project commands menu (if configured)   |


## 🔄 Command Types

### 1. Shell Commands

Run any shell command in a terminal buffer:

```lua
cmd = "npm start"
```

### 2. Vim Commands

Execute Vim commands directly (prefix with `:`):

```lua
cmd = ":write | source % | echo 'File reloaded!'"
```

### 3. Lua Functions

Dynamic commands with Lua functions:

```lua
cmd = function()
    local file = vim.fn.expand("%:p")
    if vim.fn.filereadable("package.json") == 1 then
        return "npm test"
    end
    return string.format("echo 'No tests for %s'", file)
end
```

## 📝 Tips

- Use `%f` in your commands to get the current file path
- Return `nil` from a Lua function to skip command execution
- The project configuration automatically reloads when you save `run.nvim.lua`
- Set a `default` command in your project config to skip the selection menu

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

|--------|----------|------|-------------|
| `keys.run` | Setup | string | Keybinding to run current file or project command |
| `keys.run_proj` | Setup | string | Keybinding to show project commands menu |
| `filetype` | Setup | table | Map of filetype to commands |
| `name` | Command config | string | Display name in selection menu |
| `cmd` | Command config | string \| function | Command to execute |
| `filetype` | Command config | string | Limit command to specific filetype |
| `default` | Project config | string | Default command ID |

## Example Project Configuration Files

### JavaScript/TypeScript Project

```lua
return {
    dev = {
        name = "Start Development Server",
        cmd = "npm run dev"
    },
    
    build = {
        name = "Production Build",
        cmd = "npm run build"
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if vim.bo.filetype == "typescript" and string.match(test_file, "%.test%.ts$") then
                return "npm test -- " .. test_file
            else
                return "npm test"
            end
        end,
        filetype = "typescript"
    },
    
    lint = {
        name = "Lint Project",
        cmd = "npm run lint"
    },
    
    default = "dev"
}
```

### Rust Project

```lua
return {
    build = {
        name = "Build Project",
        cmd = "cargo build"
    },
    
    run = {
        name = "Run Project",
        cmd = "cargo run"
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if string.find(test_file, "_test%.rs$") or string.find(test_file, "/tests/") then
                return string.format("cargo test -- %s", vim.fn.fnamemodify(test_file, ":t:r"))
            end
            return "cargo test"
        end
    },
    
    check = {
        name = "Type Check",
        cmd = "cargo check"
    },
    
    doc = {
        name = "Generate Documentation",
        cmd = "cargo doc --open"
    },
    
    default = "run"
}
```

### Python Project

```lua
return {
    run = {
        name = "Run File",
        cmd = "python3 %f"
    },
    
    test = {
        name = "Run Tests",
        cmd = function()
            local test_file = vim.fn.expand("%:p")
            if string.find(test_file, "test_") or string.find(test_file, "_test") then
                return string.format("python -m pytest %s -v", test_file)
            end
            return "python -m pytest"
        end
    },
    
    lint = {
        name = "Lint File",
        cmd = "flake8 %f"
    },
    
    venv = {
        name = "Activate Virtual Environment",
        cmd = ":term source venv/bin/activate"
    },
    
    default = "run"
}
```

## API

The plugin provides a Lua API for programmatic control:

```lua
-- Initialize the plugin with configuration options
require('run').setup({...})

-- Run the current file or project command
require('run').run()

-- Show the project commands menu
require('run').run_proj()

-- Run the default project command
require('run').run_proj_default()

-- Reload the project configuration file
require('run').reload_proj()

-- Set the default command from project configuration
require('run').set_default()
```

## Error Handling

The plugin provides helpful error notifications in the following cases:
- Missing key configuration
- Invalid project configuration format
- Project configuration file loading errors
- Command execution errors

For more information and bug reports, please visit the [GitHub repository](https://github.com/SpyicyDev/run.nvim).