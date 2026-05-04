local helpers = require("tests.helpers")

local TMP = helpers.resolve("/tmp")

local function setup_with_named_buffer(name)
  vim.cmd("enew")
  vim.api.nvim_buf_set_name(0, name)
  require("run").setup({})
end

describe("run.runner", function()
  before_each(helpers.reset)

  describe("path substitutions", function()
    local file
    before_each(function()
      file = TMP .. "/foo.bar.txt"
      setup_with_named_buffer(file)
    end)

    it("substitutes %f", function()
      local cmd = require("run.runner").preview({ cmd = "cat %f" })
      assert.equals("cat " .. file, cmd)
    end)

    it(
      "substitutes %d (directory)",
      function() assert.equals("ls " .. TMP, require("run.runner").preview({ cmd = "ls %d" })) end
    )

    it(
      "substitutes %t (basename with extension)",
      function() assert.equals("wc foo.bar.txt", require("run.runner").preview({ cmd = "wc %t" })) end
    )

    it(
      "substitutes %n (basename without extension)",
      function() assert.equals("echo foo.bar", require("run.runner").preview({ cmd = "echo %n" })) end
    )

    it(
      "substitutes %e (extension, no dot)",
      function() assert.equals("echo txt", require("run.runner").preview({ cmd = "echo %e" })) end
    )

    it("substitutes all in one command", function()
      local cmd = require("run.runner").preview({ cmd = "cd %d && wc %t # n=%n e=%e f=%f" })
      assert.equals(("cd %s && wc foo.bar.txt # n=foo.bar e=txt f=%s"):format(TMP, file), cmd)
    end)

    it("returns nil and warns when %f used on unnamed buffer (B13)", function()
      vim.cmd("enew")
      require("run").setup({})
      local cmd
      local notes = helpers.capture_notify(function() cmd = require("run.runner").preview({ cmd = "cat %f" }) end)
      assert.is_nil(cmd)
      assert.is_not_nil(helpers.find_notify(notes, "no file in current buffer"))
    end)

    it(
      "does NOT modify commands without %[fdnet] patterns",
      function() assert.equals("echo hello", require("run.runner").preview({ cmd = "echo hello" })) end
    )

    it("preserves spaces in paths verbatim (shell-escape is the user's job)", function()
      local space_dir = TMP .. "/has space"
      vim.fn.mkdir(space_dir, "p")
      local space_file = space_dir .. "/foo.bar.txt"
      setup_with_named_buffer(space_file)
      assert.equals("cat " .. space_file, require("run.runner").preview({ cmd = "cat %f" }))
      assert.equals("ls " .. space_dir, require("run.runner").preview({ cmd = "ls %d" }))
      assert.equals("wc foo.bar.txt", require("run.runner").preview({ cmd = "wc %t" }))
      vim.fn.delete(space_dir, "rf")
    end)
  end)

  describe("environment variable substitution (PR #2)", function()
    before_each(function()
      vim.env.RUN_TEST_VAR = "vimenv_value"
      vim.env.RUN_TEST_OTHER = "other_value"
      vim.cmd("enew")
      require("run").setup({})
    end)
    after_each(function()
      vim.env.RUN_TEST_VAR = nil
      vim.env.RUN_TEST_OTHER = nil
    end)

    it(
      "substitutes $VAR form",
      function() assert.equals("echo vimenv_value", require("run.runner").preview({ cmd = "echo $RUN_TEST_VAR" })) end
    )

    it(
      "substitutes ${VAR} form",
      function() assert.equals("echo vimenv_value", require("run.runner").preview({ cmd = "echo ${RUN_TEST_VAR}" })) end
    )

    it(
      "substitutes multiple in one command",
      function()
        assert.equals(
          "echo vimenv_value other_value",
          require("run.runner").preview({ cmd = "echo $RUN_TEST_VAR ${RUN_TEST_OTHER}" })
        )
      end
    )

    it("warns and leaves literal text on missing var", function()
      local cmd
      local notes = helpers.capture_notify(
        function() cmd = require("run.runner").preview({ cmd = "echo $RUN_DEFINITELY_NOT_SET_42" }) end
      )
      assert.equals("echo $RUN_DEFINITELY_NOT_SET_42", cmd)
      assert.is_not_nil(helpers.find_notify(notes, "RUN_DEFINITELY_NOT_SET_42 is not set"))
    end)

    it("env subst happens before path subst", function()
      vim.env.RUN_TEST_PATH = "%f"
      local p = TMP .. "/x.lua"
      vim.api.nvim_buf_set_name(0, p)
      assert.equals("cat " .. p, require("run.runner").preview({ cmd = "cat $RUN_TEST_PATH" }))
      vim.env.RUN_TEST_PATH = nil
    end)
  end)

  describe("safety check", function()
    it("blocks rm -rf /", function()
      local ok, pat = require("run.runner").check_safety("rm -rf /")
      assert.is_false(ok)
      assert.is_not_nil(pat)
    end)

    it("blocks rm -rf *", function() assert.is_false((require("run.runner").check_safety("rm -rf *"))) end)

    it("blocks sudo rm -rf", function() assert.is_false((require("run.runner").check_safety("sudo rm -rf /tmp/x"))) end)

    it(
      "blocks Vim shell-out :!rm",
      function() assert.is_false((require("run.runner").check_safety(":!rm something"))) end
    )

    it("permits ordinary commands", function()
      assert.is_true((require("run.runner").check_safety("echo hello")))
      assert.is_true((require("run.runner").check_safety("npm test")))
      assert.is_true((require("run.runner").check_safety("python3 main.py")))
    end)

    it("execute() refuses dangerous commands and notifies", function()
      require("run").setup({})
      local ok
      local notes = helpers.capture_notify(function() ok = require("run.runner").execute({ cmd = "rm -rf /" }) end)
      assert.is_false(ok)
      assert.is_not_nil(helpers.find_notify(notes, "dangerous pattern"))
    end)
  end)

  describe("command spec dispatch", function()
    before_each(function() require("run").setup({}) end)

    it("string spec is treated as cmd", function()
      vim.g._dispatch_test = nil
      local ok = require("run.runner").execute(":let g:_dispatch_test = 1")
      assert.is_true(ok)
      assert.equals(1, vim.g._dispatch_test)
    end)

    it("table spec with vim cmd executes vim.cmd", function()
      vim.g._dispatch_test = nil
      local ok = require("run.runner").execute({ cmd = ":let g:_dispatch_test = 2" })
      assert.is_true(ok)
      assert.equals(2, vim.g._dispatch_test)
    end)

    it("function spec is called and result executed", function()
      vim.g._dispatch_test = nil
      local ok = require("run.runner").execute({
        cmd = function() return ":let g:_dispatch_test = 3" end,
      })
      assert.is_true(ok)
      assert.equals(3, vim.g._dispatch_test)
    end)

    it("function returning nil is treated as success-skip", function()
      local ok = require("run.runner").execute({ cmd = function() return nil end })
      assert.is_true(ok)
    end)

    it("function that errors returns false and notifies", function()
      local ok
      local notes = helpers.capture_notify(function()
        ok = require("run.runner").execute({ cmd = function() error("boom") end })
      end)
      assert.is_false(ok)
      assert.is_not_nil(helpers.find_notify(notes, "command function errored"))
    end)

    it("invalid spec type returns false and notifies", function()
      local ok
      local notes = helpers.capture_notify(function() ok = require("run.runner").execute(42) end)
      assert.is_false(ok)
      assert.is_not_nil(helpers.find_notify(notes, "command spec must be"))
    end)

    it("table spec with bad cmd type returns false and notifies", function()
      local ok
      local notes = helpers.capture_notify(function() ok = require("run.runner").execute({ cmd = 42 }) end)
      assert.is_false(ok)
      assert.is_not_nil(helpers.find_notify(notes, "must be a string, or a function"))
    end)

    it("vim cmd error returns false and notifies", function()
      local ok
      local notes = helpers.capture_notify(
        function() ok = require("run.runner").execute({ cmd = ":NotARealCommand" }) end
      )
      assert.is_false(ok)
      assert.is_not_nil(helpers.find_notify(notes, "vim command failed"))
    end)
  end)

  describe("preview()", function()
    before_each(function()
      vim.cmd("enew")
      require("run").setup({})
    end)

    it("returns expanded cmd without executing", function()
      vim.api.nvim_buf_set_name(0, "/tmp/script.sh")
      vim.g._preview_should_not_run = "untouched"
      local cmd = require("run.runner").preview({ cmd = ":let g:_preview_should_not_run = 'RAN'" })
      assert.equals("untouched", vim.g._preview_should_not_run)
      assert.equals("let g:_preview_should_not_run = 'RAN'", cmd:sub(2))
    end)

    it("returns nil for skip-resolved spec", function()
      assert.is_nil(require("run.runner").preview({ cmd = function() return nil end }))
    end)

    it("returns nil for invalid spec", function()
      helpers.capture_notify(function() assert.is_nil(require("run.runner").preview({ cmd = 42 })) end)
    end)
  end)
end)
