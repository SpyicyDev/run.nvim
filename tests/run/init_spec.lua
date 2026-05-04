local helpers = require("tests.helpers")

local function in_tmp_project(content, fn)
  local dir = helpers.tmpdir()
  helpers.write(dir .. "/run.nvim.lua", content)
  vim.cmd("cd " .. dir)
  local _, restore = helpers.hijack_state(dir)
  local ok, err = pcall(fn, dir)
  restore()
  if not ok then error(err) end
end

describe("plugin/run.lua bootstrap", function()
  before_each(helpers.reset)

  it("source plugin/run.lua eagerly registers all 5 commands (B1, B2, B3)", function()
    vim.cmd("source plugin/run.lua")
    for _, c in ipairs({ "Run", "RunProj", "RunSetDefault", "RunReloadProj", "RunPreview" }) do
      assert.equals(2, vim.fn.exists(":" .. c), c .. " should exist")
    end
  end)

  it("source plugin/run.lua twice is a no-op (vim.g.loaded_run guard)", function()
    vim.cmd("source plugin/run.lua")
    vim.cmd("source plugin/run.lua")
    assert.equals(1, vim.g.loaded_run)
  end)
end)

describe("M.run dispatch (top-level)", function()
  before_each(helpers.reset)

  it("with project + default → runs default", function()
    in_tmp_project(
      [[return { d = { name = "D", cmd = ":let g:_run_dispatch = 'default'" }, default = "d" }]],
      function()
        require("run").setup({ project = { trust = "always" } })
        vim.g._run_dispatch = nil
        require("run").run()
        assert.equals("default", vim.g._run_dispatch)
      end
    )
  end)

  it("with project but no default → opens picker (we don't drive UI here, just no error)", function()
    in_tmp_project(
      [[return { a = { name = "A", cmd = "echo a" }, b = { name = "B", cmd = "echo b" } }]],
      function()
        require("run").setup({ project = { trust = "always" } })
        local original = vim.ui.select
        vim.ui.select = function(_, _, on_choice) on_choice(nil) end
        local ok = pcall(require("run").run)
        vim.ui.select = original
        assert.is_true(ok)
      end
    )
  end)

  it("no project, has filetype config → runs filetype command", function()
    vim.cmd("enew")
    vim.bo.filetype = "lua"
    require("run").setup({ filetype = { lua = ":let g:_filetype_dispatch = 'ft'" } })
    vim.g._filetype_dispatch = nil
    require("run").run()
    assert.equals("ft", vim.g._filetype_dispatch)
  end)

  it("no project, no filetype config → friendly error notify", function()
    vim.cmd("enew")
    vim.bo.filetype = ""
    require("run").setup({})
    local notes = helpers.capture_notify(function() require("run").run() end)
    assert.is_not_nil(helpers.find_notify(notes, "could not determine filetype"))
  end)
end)

describe("M.run_proj picker", function()
  before_each(helpers.reset)

  it("filters out commands whose filetype != current buffer ft", function()
    in_tmp_project([[
return {
  py_only = { name = "Py only",  cmd = "x", filetype = "python" },
  any1    = { name = "Any one",  cmd = "x" },
  any2    = { name = "Any two",  cmd = "x" },
}
]], function()
      vim.cmd("enew")
      vim.bo.filetype = "lua"
      require("run").setup({ project = { trust = "always" } })

      local seen
      local original = vim.ui.select
      vim.ui.select = function(items) seen = items end
      require("run").run_proj()
      vim.ui.select = original

      local names = {}
      for _, item in ipairs(seen or {}) do table.insert(names, item.display) end
      assert.is_true(vim.tbl_contains(names, "Any one"))
      assert.is_true(vim.tbl_contains(names, "Any two"))
      assert.is_false(vim.tbl_contains(names, "Py only"))
    end)
  end)

  it("appends '[filetype default: ft]' sentinel when filetype config exists", function()
    in_tmp_project([[return { a = { name = "A", cmd = "x" }, b = { name = "B", cmd = "x" } }]],
      function()
        vim.cmd("enew")
        vim.bo.filetype = "python"
        require("run").setup({
          filetype = { python = "python3 %f" },
          project = { trust = "always" },
        })

        local seen
        local original = vim.ui.select
        vim.ui.select = function(items) seen = items end
        require("run").run_proj()
        vim.ui.select = original

        local found = false
        for _, item in ipairs(seen or {}) do
          if item.kind == "filetype" then
            found = true
            assert.matches("filetype default", item.display)
          end
        end
        assert.is_true(found)
      end)
  end)

  it("menu items use kind discriminator (B12: no string collision)", function()
    in_tmp_project(
      [[return { x = { name = "[filetype default: lua]", cmd = ":let g:_b12 = 'project'" } }]],
      function()
        vim.cmd("enew")
        vim.bo.filetype = "lua"
        require("run").setup({
          filetype = { lua = ":let g:_b12 = 'filetype'" },
          project = { trust = "always" },
        })

        vim.g._b12 = nil
        local original = vim.ui.select
        vim.ui.select = function(items, _, on_choice)
          for _, item in ipairs(items) do
            if item.id == "x" then
              assert.equals("project", item.kind)
              on_choice(item)
              return
            end
          end
        end
        require("run").run_proj()
        vim.ui.select = original
        assert.equals("project", vim.g._b12)
      end
    )
  end)
end)

describe("M.set_default UI flow", function()
  before_each(helpers.reset)

  it("picking a command persists it as default", function()
    in_tmp_project([[return { a = { name = "A", cmd = "x" }, b = { name = "B", cmd = "x" } }]],
      function()
        require("run").setup({ project = { trust = "always" } })
        local original = vim.ui.select
        vim.ui.select = function(items, _, on_choice)
          for _, item in ipairs(items) do
            if item.id == "b" then on_choice(item); return end
          end
        end
        require("run").set_default()
        vim.ui.select = original
        assert.equals("b", require("run.project").get_default())
      end)
  end)

  it("picking '[clear default]' clears", function()
    in_tmp_project(
      [[return { a = { name = "A", cmd = "x" }, default = "a" }]],
      function()
        require("run").setup({ project = { trust = "always" } })
        assert.equals("a", require("run.project").get_default())
        local original = vim.ui.select
        vim.ui.select = function(items, _, on_choice)
          for _, item in ipairs(items) do
            if item.kind == "clear" then on_choice(item); return end
          end
        end
        require("run").set_default()
        vim.ui.select = original
        assert.is_nil(require("run.project").get_default())
      end)
  end)

  it("errors politely when no project file (B1)", function()
    require("run").setup({})
    local notes = helpers.capture_notify(function() require("run").set_default() end)
    assert.is_not_nil(helpers.find_notify(notes, "no project configuration found"))
  end)
end)

describe("BufWritePost autoreload", function()
  before_each(helpers.reset)

  it("reloads project file when written", function()
    in_tmp_project(
      [[return { v1 = { name = "V1", cmd = "x" } }]],
      function(dir)
        require("run").setup({ project = { trust = "always" } })
        assert.is_not_nil(require("run.project").commands().v1)

        vim.cmd("edit " .. dir .. "/run.nvim.lua")
        vim.api.nvim_buf_set_lines(0, 0, -1, false,
          { 'return { v2 = { name = "V2", cmd = "x" } }' })
        vim.cmd("write")
        assert.is_nil(require("run.project").commands().v1)
        assert.is_not_nil(require("run.project").commands().v2)
      end)
  end)
end)
