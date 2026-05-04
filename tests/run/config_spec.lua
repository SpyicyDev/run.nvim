local helpers = require("tests.helpers")

describe("run.config", function()
  before_each(helpers.reset)

  describe("defaults", function()
    it("apply() with no opts gives full default tree", function()
      require("run.config").apply()
      local v = require("run.config").values
      assert.equals("auto", v.terminal.backend)
      assert.equals("bottom", v.terminal.position)
      assert.equals(15, v.terminal.size)
      assert.equals(false, v.terminal.close_on_exit)
      assert.equals("prompt", v.project.trust)
      assert.equals("run.nvim.lua", v.project.filename)
      assert.equals(true, v.notify)
      assert.same({}, v.filetype)
    end)

    it("apply() merges deep", function()
      require("run.config").apply({
        terminal = { backend = "snacks", position = "float" },
        notify = false,
      })
      local v = require("run.config").values
      assert.equals("snacks", v.terminal.backend)
      assert.equals("float", v.terminal.position)
      assert.equals(15, v.terminal.size)
      assert.equals(false, v.notify)
    end)
  end)

  describe("validation", function()
    it("rejects bad backend", function()
      assert.has_error(function()
        require("run.config").apply({ terminal = { backend = "nonsense" } })
      end)
    end)

    it("rejects bad position", function()
      assert.has_error(function()
        require("run.config").apply({ terminal = { position = "sideways" } })
      end)
    end)

    it("rejects bad trust", function()
      assert.has_error(function()
        require("run.config").apply({ project = { trust = "maybe" } })
      end)
    end)

    it("rejects non-table filetype", function()
      assert.has_error(function()
        require("run.config").apply({ filetype = "not a table" })
      end)
    end)

    it("rejects non-boolean notify", function()
      assert.has_error(function()
        require("run.config").apply({ notify = "yes" })
      end)
    end)

    it("accepts all valid backends", function()
      for _, b in ipairs({ "auto", "builtin", "snacks", "toggleterm", "fterm" }) do
        assert.has_no_errors(function()
          require("run.config").apply({ terminal = { backend = b } })
        end)
      end
    end)

    it("accepts all valid positions", function()
      for _, p in ipairs({ "float", "bottom", "top", "left", "right", "tab" }) do
        assert.has_no_errors(function()
          require("run.config").apply({ terminal = { position = p } })
        end)
      end
    end)
  end)

  describe("ensure_setup", function()
    it("calls setup if did_setup is false", function()
      assert.is_false(require("run").did_setup)
      require("run.config").ensure_setup()
      assert.is_true(require("run").did_setup)
    end)

    it("is no-op if did_setup is true", function()
      require("run").setup({ terminal = { size = 99 } })
      require("run.config").ensure_setup()
      assert.equals(99, require("run.config").values.terminal.size)
    end)
  end)
end)

describe("run.setup idempotency (B4)", function()
  before_each(helpers.reset)

  it("3 calls produce exactly one augroup with 2 autocmds", function()
    require("run").setup({})
    require("run").setup({})
    require("run").setup({})
    local autocmds = vim.api.nvim_get_autocmds({ group = "run.nvim" })
    assert.equals(2, #autocmds)
  end)

  it("does not re-apply opts on subsequent calls", function()
    require("run").setup({ terminal = { size = 42 } })
    require("run").setup({ terminal = { size = 99 } })
    assert.equals(42, require("run.config").values.terminal.size)
  end)

  it("did_setup is true after first call", function()
    assert.is_false(require("run").did_setup)
    require("run").setup({})
    assert.is_true(require("run").did_setup)
  end)
end)
