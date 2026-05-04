local helpers = require("tests.helpers")

describe("run.terminal dispatcher", function()
  before_each(helpers.reset)

  it("falls back to builtin when backend = auto and no third-party plugins installed", function()
    require("run").setup({ terminal = { backend = "auto" } })
    assert.equals("builtin", require("run.terminal").detect())
  end)

  it("respects explicit backend = builtin", function()
    require("run").setup({ terminal = { backend = "builtin" } })
    assert.equals("builtin", require("run.terminal").detect())
  end)

  it("respects explicit non-builtin backend even if not installed", function()
    require("run").setup({ terminal = { backend = "snacks" } })
    assert.equals("snacks", require("run.terminal").detect())
  end)

  it("loads each backend module without error", function()
    for _, b in ipairs({ "builtin", "snacks", "toggleterm", "fterm" }) do
      assert.has_no_errors(function()
        local mod = require("run.terminal." .. b)
        assert.is_function(mod.run)
      end)
    end
  end)
end)

describe("run.terminal backend adapters fall back gracefully when plugin missing", function()
  before_each(helpers.reset)

  it("snacks adapter falls back to builtin when snacks not installed", function()
    require("run").setup({})
    package.loaded.snacks = nil
    package.preload.snacks = function() error("missing") end
    local notes = helpers.capture_notify(
      function() pcall(require("run.terminal.snacks").run, "true", require("run.config").values.terminal) end
    )
    assert.is_not_nil(helpers.find_notify(notes, "snacks.terminal not available"))
    package.preload.snacks = nil
  end)

  it("toggleterm adapter falls back to builtin when toggleterm not installed", function()
    require("run").setup({})
    package.loaded.toggleterm = nil
    package.preload.toggleterm = function() error("missing") end
    local notes = helpers.capture_notify(
      function() pcall(require("run.terminal.toggleterm").run, "true", require("run.config").values.terminal) end
    )
    assert.is_not_nil(helpers.find_notify(notes, "toggleterm.nvim not available"))
    package.preload.toggleterm = nil
  end)

  it("fterm adapter falls back to builtin when FTerm not installed", function()
    require("run").setup({})
    package.loaded.FTerm = nil
    package.preload.FTerm = function() error("missing") end
    local notes = helpers.capture_notify(
      function() pcall(require("run.terminal.fterm").run, "true", require("run.config").values.terminal) end
    )
    assert.is_not_nil(helpers.find_notify(notes, "FTerm.nvim not available"))
    package.preload.FTerm = nil
  end)
end)
