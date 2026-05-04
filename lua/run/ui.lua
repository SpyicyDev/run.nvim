local M = {}

---@class run.MenuItem
---@field id? string                 command id (nil for synthetic items)
---@field kind "project"|"filetype"|"clear"
---@field display string             label shown to user
---@field spec? run.CommandSpec      command to execute (for run menus)

---Show a vim.ui.select picker over typed menu items.
---@param items run.MenuItem[]
---@param prompt string
---@param on_choice fun(item: run.MenuItem?)
function M.pick(items, prompt, on_choice)
  if #items == 0 then
    require("run.util").notify("no commands available", vim.log.levels.WARN)
    on_choice(nil)
    return
  end
  if #items == 1 then
    on_choice(items[1])
    return
  end
  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item) return item.display end,
  }, function(choice) on_choice(choice) end)
end

return M
