local helpers = require("tests.helpers")

describe("run.util", function()
  before_each(helpers.reset)

  describe("buffer_filetype", function()
    it("returns vim.bo.filetype for unsaved buffers (B7)", function()
      vim.cmd("enew")
      vim.bo.filetype = "python"
      assert.equals("python", require("run.util").buffer_filetype(0))
    end)

    it("falls back to vim.filetype.match for buffers without ft set", function()
      vim.cmd("enew")
      vim.api.nvim_buf_set_name(0, helpers.resolve("/tmp") .. "/somefile.py")
      vim.bo.filetype = ""
      assert.equals("python", require("run.util").buffer_filetype(0))
    end)

    it("returns nil for unnamed scratch buffer with no ft", function()
      vim.cmd("enew")
      vim.bo.filetype = ""
      assert.is_nil(require("run.util").buffer_filetype(0))
    end)
  end)

  describe("buffer_path", function()
    it("returns absolute path for named buffer (B13)", function()
      vim.cmd("enew")
      local p = helpers.resolve("/tmp") .. "/hello.txt"
      vim.api.nvim_buf_set_name(0, p)
      assert.equals(p, require("run.util").buffer_path(0))
    end)

    it("returns nil for unnamed buffer (B13)", function()
      vim.cmd("enew")
      assert.is_nil(require("run.util").buffer_path(0))
    end)
  end)

  describe("notify", function()
    it("respects config.notify = false", function()
      require("run").setup({ notify = false })
      local got = helpers.capture_notify(function()
        require("run.util").notify("hello", vim.log.levels.INFO)
      end)
      assert.equals(0, #got)
    end)

    it("emits when config.notify = true", function()
      require("run").setup({ notify = true })
      local got = helpers.capture_notify(function()
        require("run.util").notify("hello", vim.log.levels.INFO)
      end)
      assert.equals(1, #got)
      assert.equals("hello", got[1].msg)
    end)
  end)
end)
