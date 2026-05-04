# run.nvim

[![CI](https://github.com/SpyicyDev/run.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/SpyicyDev/run.nvim/actions/workflows/ci.yml)

A small, opinionated command runner for Neovim. Run filetype-default commands or per-project commands declared in a single `run.nvim.lua` file at your project root. Shell, Vim, and Lua-function commands are all first-class.

- Zero hard dependencies. Works out of the box with Neovim's built-in `:terminal`.
- Auto-detects [snacks.nvim](https://github.com/folke/snacks.nvim), [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim), or [FTerm.nvim](https://github.com/numToStr/FTerm.nvim) and uses them as the terminal backend if available.
- Project files are loaded through `vim.secure.read` — no surprise code execution.
- Picker UI via `vim.ui.select`, so it integrates with whatever picker you already use (telescope-ui-select, dressing.nvim, fzf-lua, snacks.input, etc.).
- Strict, friendly config validation. Health check via `:checkhealth run`.

## Requirements

- Neovim **0.10** or newer.
- Optional: `snacks.nvim`, `toggleterm.nvim`, or `FTerm.nvim` for fancier terminals.

## Installation

### lazy.nvim

```lua
{
  "SpyicyDev/run.nvim",
  cmd = { "Run", "RunProj", "RunSetDefault", "RunReloadProj" },
  keys = {
    { "<leader>rr", "<cmd>Run<cr>",     desc = "Run" },
    { "<leader>rt", "<cmd>RunProj<cr>", desc = "Run project command" },
  },
  opts = {},
}
```

run.nvim does **not** create any keymaps for you — bind the user commands yourself, either via lazy's `keys =` spec (above) or `vim.keymap.set`.

If you want a specific terminal backend, add it as a dep and configure:

```lua
{
  "SpyicyDev/run.nvim",
  dependencies = { "akinsho/toggleterm.nvim" },
  opts = {
    terminal = { backend = "toggleterm", position = "float" },
  },
}
```

## Configuration

Defaults:

```lua
require("run").setup({
  filetype = {},                -- ft -> string | function | { cmd = ... }
  terminal = {
    backend = "auto",           -- auto|builtin|snacks|toggleterm|fterm
    position = "bottom",        -- bottom|top|left|right|float|tab
    size = 15,                  -- rows for h-splits, cols for v-splits
    close_on_exit = false,      -- close window when shell exits 0
  },
  project = {
    trust = "prompt",           -- prompt|always|never
    filename = "run.nvim.lua",  -- file to look for, walking up from cwd
  },
  notify = true,                -- set false to silence vim.notify
})
```

Filetype commands:

```lua
require("run").setup({
  filetype = {
    -- shell: %f, %d, %n, %e, %t for path bits; $VAR / ${VAR} for env vars
    python     = "python3 %f",
    javascript = "node %f",
    c          = "gcc -o %n %f && ./%n",
    docker     = "docker run -v %d:/app ${DOCKER_IMAGE} %f",

    -- a Vim command
    lua = ":luafile %",

    -- a function returning a string (or nil to skip)
    rust = function()
      return vim.fn.filereadable("Cargo.toml") == 1 and "cargo run" or nil
    end,

    -- table form (equivalent to a string for this filetype-only API)
    typescript = { cmd = "npx tsx %f" },
  },
})
```

## Project configuration: `run.nvim.lua`

Place a `run.nvim.lua` at your project root (or any cwd ancestor):

```lua
return {
  dev = {
    name = "Start dev server",
    cmd  = "npm run dev",
  },

  test = {
    name = "Run tests for this file",
    cmd  = function()
      local file = vim.fn.expand("%:p")
      if file:match("%.test%.ts$") then
        return "npm test -- " .. file
      end
      return "npm test"
    end,
    filetype = "typescript",  -- only listed when current buffer is typescript
  },

  build = {
    name = "Production build",
    cmd  = "npm run build",
  },

  default = "dev",            -- :Run will pick this when set
}
```

### Schema

Each entry (other than `default`) is:

| field      | type                | required | description                                         |
|------------|---------------------|----------|-----------------------------------------------------|
| `name`     | string              | yes      | label shown in the picker                           |
| `cmd`      | string \| function  | yes      | shell, Vim (`:`-prefixed), or function returning so |
| `filetype` | string              | no       | only listed when current buffer matches             |

The top-level `default` (a string command id) is what `:Run` invokes when no menu would otherwise appear.

### Trust

`run.nvim.lua` executes arbitrary Lua, so by default run.nvim shows a single confirm prompt the first time you encounter a given file:

```
[run.nvim] Trust this project config and load it?

  /abs/path/to/run.nvim.lua

It contains executable Lua that runs in your Neovim.
[T]rust & load, [S]kip, [V]iew first:
```

- **Trust & load** — loads it now, persists trust to `$XDG_STATE_HOME/nvim/trust` keyed by content hash. Edits invalidate trust *across sessions* but the in-session cache prevents re-prompts after every save.
- **Skip** — returns nil, no project loaded for this session. Run `:RunReloadProj` to be prompted again.
- **View first** — opens the file in a split for review. Run `:RunReloadProj` after to be prompted again.

The on-disk format is identical to what `vim.secure.read` uses (the same trust DB), so files trusted by run.nvim are also trusted by `:set exrc` and vice versa.

To change behavior:

```lua
opts = { project = { trust = "prompt"|"always"|"never" } }
```

- `prompt` (default) — show the confirm above.
- `always` — load without prompting (UNSAFE; turns off the trust check).
- `never` — never load any project file.

## Commands

| Command                | What it does                                                                                                                         |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `:Run`                 | If a project default is set, run it. Else if a project is loaded, open the picker. Else run the configured filetype command.         |
| `:RunProj`             | Open the project command picker (also offers the filetype default if configured).                                                    |
| `:RunSetDefault`       | Pick a default command for the current project. Persisted to `stdpath('state')/run.nvim/defaults.json` — your `run.nvim.lua` is **not** modified. |
| `:RunReloadProj`       | Re-read `run.nvim.lua` from disk.                                                                                                    |
| `:RunPreview [cmd_id]` | Dry-run: resolve and expand the command, but show it via `vim.notify` instead of executing. With no arg, previews the current filetype command; with an arg, previews the named project command (tab-completes).  |

The plugin auto-reloads the project file on `DirChanged` and on `BufWritePost run.nvim.lua`.

## Substitutions

Before execution, command strings are processed by two passes (env vars first, then path placeholders):

### Environment variables

| Pattern  | Replacement                              |
|----------|------------------------------------------|
| `$VAR`   | value of `VAR` from `vim.env` / `getenv` |
| `${VAR}` | same; explicit braces                    |

If a variable is unset, run.nvim emits a `vim.notify` warning and leaves the literal text untouched (so your shell can still try to resolve it, or fail visibly).

### File path placeholders

| Pattern | Replacement                              |
|---------|------------------------------------------|
| `%f`    | absolute buffer path                     |
| `%d`    | directory of the buffer (`fnamemodify ":h"`) |
| `%n`    | basename without extension (`":t:r"`)    |
| `%e`    | extension, no dot (`":e"`)               |
| `%t`    | basename with extension (`":t"`)         |

If the buffer is unnamed and any `%[fdnet]` pattern is used, run.nvim errors out (no silent fallback).

## Safety check

Before sending to a terminal, run.nvim refuses to execute commands matching obviously-destructive patterns:

- `rm -rf /`
- `rm -rf *`
- `:!rm ...` (Vim shell-out)
- `sudo rm -rf ...`

Use `:RunPreview` to inspect what would run if you're unsure.

## Terminal backends

| backend      | uses                              | notes                                                |
|--------------|-----------------------------------|------------------------------------------------------|
| `auto`       | first installed of snacks/tt/fterm, else builtin | default                                              |
| `builtin`    | Neovim `:terminal` in split/float | zero deps                                            |
| `snacks`     | `snacks.terminal()`               | needs snacks.nvim                                    |
| `toggleterm` | `toggleterm.exec()`               | needs toggleterm.nvim                                |
| `fterm`      | `FTerm.scratch()`                 | needs FTerm.nvim                                     |

If a configured backend isn't installed, run.nvim warns and falls back to the built-in terminal.

## Health

```vim
:checkhealth run
```

Reports the Neovim version, whether `setup()` has run, which backends are available, and which project file (if any) is loaded.

## Lua API

```lua
require("run").setup({...})           -- idempotent
require("run").run()                  -- top-level dispatch
require("run").run_proj()             -- open project picker
require("run").run_proj_default()     -- run persisted default
require("run").run_file()             -- run filetype command for current buffer
require("run").reload_proj()          -- re-read project file
require("run").set_default()          -- open "set default" picker
require("run").preview_cmd()          -- dry-run filetype command (notify)
require("run").preview_cmd("test")    -- dry-run named project command
```

## Development

Run the test suite (auto-installs plenary.nvim into `.tests/` on first run):

```bash
make test
make fmt-check    # stylua --check
make fmt          # stylua format
make clean        # remove .tests/
```

CI runs the suite on Neovim 0.10, 0.11, and nightly across Linux and macOS plus stylua formatting check (`.github/workflows/ci.yml`). See [`tests/README.md`](tests/README.md) for spec layout and authoring patterns.

## License

MIT.
