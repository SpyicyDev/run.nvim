# run.nvim

## Project Description

`run.nvim` is a Neovim plugin that allows you to run scripts and commands directly from your Neovim editor. It provides a flexible and customizable way to execute commands based on the current filetype or project-specific configurations.

Commands can be regular bash, vim commands, or a lua function that returns one of or neither of the previous two. If the command is bash, it is run in a floating terminal window.

## Installation

To install `run.nvim` using `lazy.nvim`, add the following to your `lazy.nvim` configuration:

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

After installing `run.nvim`, you can use the following keybindings and commands:

- `<leader>rr`: Run the default script for the current filetype or project.
- `<leader>rt`: Open the project-specific script menu (if a project configuration file exists).
- `:Run`: Run the default script for the current filetype or project.
- `:RunSetDefault`: Set a default script for the current project.
- `:RunReloadProj`: Reload the project configuration file.

## Project-specific config file format

```lua
return {
  cmd_a = {
    name = "Command A",
    cmd = "python3 main.py" -- default type is a regular bash command
  },

  cmd_b = {
    name = "Command B",
    cmd = "rustc %f" -- %f is the current file's path
  },

  cmd_c = {
    name = "Command C",
    cmd = ":PeekOpen" -- prefix with : to run a Neovim command
  },

  cmd_d = {
    name = "Command D",
    cmd = function () -- write as a lua function and return one of the two other types as a string
      println("yay")

      return "python3 %f"
    end
  }
}
```
