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
      helpers.setup_sync({ project = { trust = "always" } })
      local project = require("run.project")
      assert.is_true(project.has_project())
      assert.is_not_nil(project.commands().hi)
    end)

    it("returns no-project when trust = never", function()
      make_project([[return { hi = { name = "Hi", cmd = "echo hi" } }]])
      helpers.setup_sync({ project = { trust = "never" } })
      assert.is_false(require("run.project").has_project())
    end)

    it("walks up from cwd to find project file", function()
      local dir = make_project([[return { up = { name = "Up", cmd = "echo up" } }]])
      vim.fn.mkdir(dir .. "/sub/sub2", "p")
      vim.cmd("cd " .. dir .. "/sub/sub2")
      helpers.setup_sync({ project = { trust = "always" } })
      assert.is_true(require("run.project").has_project())
    end)

    it("respects custom filename", function()
      local dir = helpers.tmpdir()
      helpers.write(dir .. "/.run.lua", [[return { x = { name = "X", cmd = "echo x" } }]])
      vim.cmd("cd " .. dir)
      helpers.setup_sync({
        project = { trust = "always", filename = ".run.lua" },
      })
      assert.is_true(require("run.project").has_project())
    end)
  end)

  describe("validation (B11)", function()
    local function load_invalid(content)
      make_project(content)
      local notes = helpers.capture_notify(function() helpers.setup_sync({ project = { trust = "always" } }) end)
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

      helpers.setup_sync({ project = { trust = "always" } })
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

      helpers.setup_sync({ project = { trust = "always" } })
      require("run.project").persist_default("b")
      assert.equals("b", require("run.project").get_default())

      helpers.reset()
      helpers.setup_sync({ project = { trust = "always" } })
      assert.equals("b", require("run.project").get_default())

      restore()
    end)

    it("clears default with persist_default(nil)", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" }, default = "x" }]])
      local _, restore = helpers.hijack_state(dir)

      helpers.setup_sync({ project = { trust = "always" } })
      assert.equals("x", require("run.project").get_default())
      require("run.project").persist_default(nil)
      assert.is_nil(require("run.project").get_default())

      restore()
    end)

    it("persisted default keyed by absolute project root", function()
      local dir1 = make_project([[return { a = { name = "A", cmd = "a" } }]])
      local _, restore = helpers.hijack_state(dir1)
      helpers.setup_sync({ project = { trust = "always" } })
      require("run.project").persist_default("a")

      local dir2 = make_project([[return { b = { name = "B", cmd = "b" } }]])
      helpers.reset()
      helpers.setup_sync({ project = { trust = "always" } })
      assert.is_nil(require("run.project").get_default(), "should not inherit default from a different project")

      restore()
    end)
  end)

  describe("trust prompt", function()
    -- Every test in this block must restore vim.fn.confirm even if the assertion
    -- inside throws — otherwise a stub leaks into the next test.
    local function with_confirm_stub(stub, fn)
      local original = vim.fn.confirm
      vim.fn.confirm = stub
      local ok, err = pcall(fn)
      vim.fn.confirm = original
      if not ok then error(err) end
    end

    it("'Trust && load' (choice 1) loads file and writes hash to trust DB", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" } }]])
      local _, restore = helpers.hijack_state(dir)
      with_confirm_stub(function() return 1 end, function() helpers.setup_sync({ project = { trust = "prompt" } }) end)
      restore()
      assert.is_true(require("run.project").has_project())
      local trust_db = vim.fs.normalize(dir .. "/state/trust")
      local content = helpers.read(trust_db) or ""
      assert.is_truthy(content:find("run.nvim.lua", 1, true), "trust DB should record the project file path")
    end)

    it("'Skip' (choice 2) returns nil and leaves no project loaded", function()
      make_project([[return { x = { name = "X", cmd = "x" } }]])
      with_confirm_stub(function() return 2 end, function() helpers.setup_sync({ project = { trust = "prompt" } }) end)
      assert.is_false(require("run.project").has_project())
    end)

    it("ESC / cancel (choice 0) is treated as Skip", function()
      make_project([[return { x = { name = "X", cmd = "x" } }]])
      with_confirm_stub(function() return 0 end, function() helpers.setup_sync({ project = { trust = "prompt" } }) end)
      assert.is_false(require("run.project").has_project())
    end)

    it("'View first' (choice 3) opens file in split, returns nil, notifies how to retry", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" } }]])
      local notes
      with_confirm_stub(function() return 3 end, function()
        notes = helpers.capture_notify(function() helpers.setup_sync({ project = { trust = "prompt" } }) end)
      end)
      assert.is_false(require("run.project").has_project())
      assert.is_not_nil(helpers.find_notify(notes, "RunReloadProj"), "should advise how to re-trigger")
      local found_split = false
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(b):find("run.nvim.lua", 1, true) then
          found_split = true
          break
        end
      end
      assert.is_true(found_split, "the project file should be opened for review")
    end)

    it("trusted file (entry exists in trust DB) skips prompt entirely", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" } }]])
      local _, restore = helpers.hijack_state(dir)

      -- Pre-trust the file using the same on-disk format the plugin uses.
      local proj = vim.fs.normalize(vim.fn.getcwd() .. "/run.nvim.lua")
      local fd = io.open(proj, "rb")
      local content = fd:read("*a")
      fd:close()
      local hash = vim.fn.sha256(content)
      local state_dir = vim.fn.stdpath("state")
      vim.fn.mkdir(state_dir, "p")
      local tfd = io.open(state_dir .. "/trust", "w")
      tfd:write(hash .. " " .. proj .. "\n")
      tfd:close()

      with_confirm_stub(
        function() error("should not prompt when already trusted") end,
        function() helpers.setup_sync({ project = { trust = "prompt" } }) end
      )
      restore()
      assert.is_true(require("run.project").has_project())
    end)

    it("after Trust+load, second discover within session does not re-prompt", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" } }]])
      local _, restore = helpers.hijack_state(dir)

      local prompts = 0
      with_confirm_stub(function()
        prompts = prompts + 1
        return 1
      end, function()
        helpers.setup_sync({ project = { trust = "prompt" } })
        require("run.project").discover()
        require("run.project").discover()
      end)
      restore()
      assert.equals(1, prompts, "session cache + persisted DB hash should both prevent re-prompt")
    end)

    it("after Trust+load, content edits within session bypass re-prompt (session cache)", function()
      local dir = make_project([[return { v1 = { name = "V1", cmd = "x" } }]])
      local _, restore = helpers.hijack_state(dir)

      local prompts = 0
      with_confirm_stub(function()
        prompts = prompts + 1
        return 1
      end, function()
        helpers.setup_sync({ project = { trust = "prompt" } })
        helpers.write(dir .. "/run.nvim.lua", [[return { v2 = { name = "V2", cmd = "x" } }]])
        require("run.project").discover()
      end)
      restore()
      assert.equals(1, prompts, "edits within session reuse session cache, no re-prompt")
      assert.is_not_nil(require("run.project").commands().v2)
    end)
  end)

  describe("reload", function()
    it("re-reads project file from disk", function()
      local dir = make_project([[return { v1 = { name = "V1", cmd = "echo 1" } }]])
      helpers.setup_sync({ project = { trust = "always" } })
      assert.is_not_nil(require("run.project").commands().v1)

      helpers.write(dir .. "/run.nvim.lua", [[return { v2 = { name = "V2", cmd = "echo 2" } }]])
      require("run.project").discover()
      assert.is_nil(require("run.project").commands().v1)
      assert.is_not_nil(require("run.project").commands().v2)
    end)

    it("clears state when project file removed", function()
      local dir = make_project([[return { x = { name = "X", cmd = "x" } }]])
      helpers.setup_sync({ project = { trust = "always" } })
      assert.is_true(require("run.project").has_project())

      vim.fn.delete(dir .. "/run.nvim.lua")
      require("run.project").discover()
      assert.is_false(require("run.project").has_project())
    end)
  end)

  describe("preview API (PR #2)", function()
    it("preview_cmd(id) for project command resolves without executing", function()
      make_project([[return { build = { name = "Build", cmd = "make build" } }]])
      helpers.setup_sync({ project = { trust = "always" } })
      local notes = helpers.capture_notify(function() require("run").preview_cmd("build") end)
      assert.is_not_nil(helpers.find_notify(notes, "would run: make build"))
    end)

    it("preview_cmd() with no arg uses filetype command", function()
      vim.cmd("enew")
      local p = helpers.resolve("/tmp") .. "/x.lua"
      vim.api.nvim_buf_set_name(0, p)
      vim.bo.filetype = "lua"
      helpers.setup_sync({ filetype = { lua = "lua %f" } })
      local notes = helpers.capture_notify(function() require("run").preview_cmd() end)
      assert.is_not_nil(helpers.find_notify(notes, "would run: lua " .. vim.pesc(p)))
    end)

    it("preview_cmd(unknown) errors politely", function()
      make_project([[return { build = { name = "Build", cmd = "x" } }]])
      helpers.setup_sync({ project = { trust = "always" } })
      local notes = helpers.capture_notify(function() require("run").preview_cmd("nonexistent") end)
      assert.is_not_nil(helpers.find_notify(notes, "project command not found"))
    end)

    it("preview flags dangerous commands as UNSAFE", function()
      make_project([[return { evil = { name = "Evil", cmd = "rm -rf /" } }]])
      helpers.setup_sync({ project = { trust = "always" } })
      local notes = helpers.capture_notify(function() require("run").preview_cmd("evil") end)
      assert.is_not_nil(helpers.find_notify(notes, "UNSAFE"))
    end)
  end)
end)
