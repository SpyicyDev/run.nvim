local helpers = require("tests.helpers")

local function make_project(content)
  local dir = helpers.tmpdir()
  helpers.write(dir .. "/run.nvim.lua", content)
  vim.cmd("cd " .. dir)
  return dir
end

describe("run.project", function()
  before_each(helpers.reset)

  describe("discover() with trust modes", function()
    it("loads file when trust = always", function()
      make_project([[return { hi = { name = "Hi", cmd = "echo hi" } }]])
      require("run").setup({ project = { trust = "always" } })
      local project = require("run.project")
      assert.is_true(project.has_project())
      assert.is_not_nil(project.commands().hi)
    end)

    it("returns no-project when trust = never", function()
      make_project([[return { hi = { name = "Hi", cmd = "echo hi" } }]])
      require("run").setup({ project = { trust = "never" } })
      assert.is_false(require("run.project").has_project())
    end)

    it("walks up from cwd to find project file", function()
      local dir = make_project([[return { up = { name = "Up", cmd = "echo up" } }]])
      vim.fn.mkdir(dir .. "/sub/sub2", "p")
      vim.cmd("cd " .. dir .. "/sub/sub2")
      require("run").setup({ project = { trust = "always" } })
      assert.is_true(require("run.project").has_project())
    end)

    it("respects custom filename", function()
      local dir = helpers.tmpdir()
      helpers.write(dir .. "/.run.lua", [[return { x = { name = "X", cmd = "echo x" } }]])
      vim.cmd("cd " .. dir)
      require("run").setup({
        project = { trust = "always", filename = ".run.lua" },
      })
      assert.is_true(require("run.project").has_project())
    end)
  end)

  describe("validation (B11)", function()
    local function load_invalid(content)
      make_project(content)
      local notes = helpers.capture_notify(function()
        require("run").setup({ project = { trust = "always" } })
      end)
      return notes
    end

    it("rejects bad default reference", function()
      local notes = load_invalid([[return { hi = { name = "Hi", cmd = "x" }, default = "missing" }]])
      assert.is_not_nil(helpers.find_notify(notes, "default command 'missing' does not exist"))
      assert.is_false(require("run.project").has_project())
    end)

    it("rejects missing name", function()
      local notes = load_invalid([[return { hi = { cmd = "x" } }]])
      assert.is_not_nil(helpers.find_notify(notes, "command 'hi' missing string 'name'"))
    end)

    it("rejects bad cmd type", function()
      local notes = load_invalid([[return { hi = { name = "Hi", cmd = 42 } }]])
      assert.is_not_nil(helpers.find_notify(notes, "'cmd' must be string or function"))
    end)

    it("rejects unknown key in command", function()
      local notes = load_invalid([[return { hi = { name = "Hi", cmd = "x", typo = 1 } }]])
      assert.is_not_nil(helpers.find_notify(notes, "unknown key 'typo'"))
    end)

    it("reports parse errors distinctly from runtime errors", function()
      local notes = load_invalid([[this is not lua]])
      assert.is_not_nil(helpers.find_notify(notes, "error parsing"))
    end)

    it("reports runtime errors distinctly from parse errors", function()
      local notes = load_invalid([[error("boom")]])
      assert.is_not_nil(helpers.find_notify(notes, "error executing"))
      assert.is_not_nil(helpers.find_notify(notes, "boom"))
    end)

    it("rejects reserved leading-underscore ids", function()
      local notes = load_invalid([[return { _x = { name = "X", cmd = "x" } }]])
      assert.is_not_nil(helpers.find_notify(notes, "reserved"))
    end)
  end)

  describe("default persistence (B5)", function()
    it("does NOT modify run.nvim.lua when persisting default", function()
      local dir = make_project([[
return {
  fn_cmd = {
    name = "Function",
    cmd = function() return "echo via_function" end,
  },
  default = "fn_cmd",
}
]])
      local original_content = helpers.read(dir .. "/run.nvim.lua")
      local _, restore = helpers.hijack_state(dir)

      require("run").setup({ project = { trust = "always" } })
      require("run.project").persist_default("fn_cmd")
      restore()

      local after_content = helpers.read(dir .. "/run.nvim.lua")
      assert.equals(original_content, after_content)
    end)

    it("survives setup -> persist -> reset -> setup cycle", function()
      local dir = make_project([[
return {
  a = { name = "A", cmd = "echo a" },
  b = { name = "B", cmd = "echo b" },
}
]])
      local _, restore = helpers.hijack_state(dir)

      require("run").setup({ project = { trust = "always" } })
      require("run.project").persist_default("b")
      assert.equals("b", require("run.project").get_default())

      helpers.reset()
      require("run").setup({ project = { trust = "always" } })
      assert.equals("b", require("run.project").get_default())

      restore()
    end)

    it("clears default with persist_default(nil)", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" }, default = "x" }]])
      local _, restore = helpers.hijack_state(dir)

      require("run").setup({ project = { trust = "always" } })
      assert.equals("x", require("run.project").get_default())
      require("run.project").persist_default(nil)
      assert.is_nil(require("run.project").get_default())

      restore()
    end)

    it("persisted default keyed by absolute project root", function()
      local dir1 = make_project([[return { a = { name = "A", cmd = "a" } }]])
      local _, restore = helpers.hijack_state(dir1)
      require("run").setup({ project = { trust = "always" } })
      require("run.project").persist_default("a")

      local dir2 = make_project([[return { b = { name = "B", cmd = "b" } }]])
      helpers.reset()
      require("run").setup({ project = { trust = "always" } })
      assert.is_nil(require("run.project").get_default(),
        "should not inherit default from a different project")

      restore()
    end)
  end)

  describe("reload", function()
    it("re-reads project file from disk", function()
      local dir = make_project([[return { v1 = { name = "V1", cmd = "echo 1" } }]])
      require("run").setup({ project = { trust = "always" } })
      assert.is_not_nil(require("run.project").commands().v1)

      helpers.write(dir .. "/run.nvim.lua",
        [[return { v2 = { name = "V2", cmd = "echo 2" } }]])
      require("run.project").discover()
      assert.is_nil(require("run.project").commands().v1)
      assert.is_not_nil(require("run.project").commands().v2)
    end)

    it("clears state when project file removed", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" } }]])
      require("run").setup({ project = { trust = "always" } })
      assert.is_true(require("run.project").has_project())

      vim.fn.delete(dir .. "/run.nvim.lua")
      require("run.project").discover()
      assert.is_false(require("run.project").has_project())
    end)
  end)

  describe("preview API (PR #2)", function()
    it("preview_cmd(id) for project command resolves without executing", function()
      make_project([[return { build = { name = "Build", cmd = "make build" } }]])
      require("run").setup({ project = { trust = "always" } })
      local notes = helpers.capture_notify(function()
        require("run").preview_cmd("build")
      end)
      assert.is_not_nil(helpers.find_notify(notes, "would run: make build"))
    end)

    it("preview_cmd() with no arg uses filetype command", function()
      vim.cmd("enew")
      local p = helpers.resolve("/tmp") .. "/x.lua"
      vim.api.nvim_buf_set_name(0, p)
      vim.bo.filetype = "lua"
      require("run").setup({ filetype = { lua = "lua %f" } })
      local notes = helpers.capture_notify(function()
        require("run").preview_cmd()
      end)
      assert.is_not_nil(helpers.find_notify(notes, "would run: lua " .. vim.pesc(p)))
    end)

    it("preview_cmd(unknown) errors politely", function()
      make_project([[return { build = { name = "Build", cmd = "x" } }]])
      require("run").setup({ project = { trust = "always" } })
      local notes = helpers.capture_notify(function()
        require("run").preview_cmd("nonexistent")
      end)
      assert.is_not_nil(helpers.find_notify(notes, "project command not found"))
    end)

    it("preview flags dangerous commands as UNSAFE", function()
      make_project([[return { evil = { name = "Evil", cmd = "rm -rf /" } }]])
      require("run").setup({ project = { trust = "always" } })
      local notes = helpers.capture_notify(function()
        require("run").preview_cmd("evil")
      end)
      assert.is_not_nil(helpers.find_notify(notes, "UNSAFE"))
    end)
  end)
end)
