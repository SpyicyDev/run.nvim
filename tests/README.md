# tests

Plenary-busted spec suite for `run.nvim`. Run via:

```bash
make test
```

On first run, plenary.nvim is auto-cloned into `.tests/site/pack/deps/start/plenary.nvim/`. Subsequent runs reuse it. Wipe with `make clean`.

## Layout

```
tests/
├── README.md              this file
├── minimal_init.lua       bootstraps rtp, packpath, auto-installs plenary
├── helpers.lua            shared test utilities (reset, capture_notify, hijack_state)
└── run/
    ├── config_spec.lua    defaults, validate, idempotency (B4)
    ├── init_spec.lua      plugin/run.lua bootstrap, dispatch, picker, set_default
    ├── project_spec.lua   discover, validation (B11), persistence (B5), preview API
    ├── runner_spec.lua    %f/%d/%n/%e/%t, $VAR/${VAR}, safety, dispatch
    ├── terminal_spec.lua  backend detection, fallback
    └── util_spec.lua      buffer_path/buffer_filetype (B7, B13), notify
```

## Writing tests

Each spec starts with `local helpers = require("tests.helpers")`. Always wrap your `describe` in `before_each(helpers.reset)` so module state doesn't leak between tests:

```lua
local helpers = require("tests.helpers")

describe("my feature", function()
  before_each(helpers.reset)

  it("does the thing", function()
    require("run").setup({})
    -- ...
  end)
end)
```

### Capturing notifications

```lua
local notes = helpers.capture_notify(function()
  require("run").run()
end)
assert.is_not_nil(helpers.find_notify(notes, "expected substring or pattern"))
```

### Isolating state files

For tests that touch `stdpath('state')` (e.g. project default persistence):

```lua
local _, restore = helpers.hijack_state(tmpdir)
-- ... work that may write to state ...
restore()
```

### macOS path resolution

`/tmp` resolves to `/private/tmp` via symlink on macOS, and `nvim_buf_set_name`
canonicalizes the path. Use `helpers.resolve(path)` (wraps `vim.uv.fs_realpath`)
for any literal absolute path you'll later compare against.
