# run.nvim

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
