local M = {}
local C = require("filter_do.config")

--- wrapping vim.ui.select as async function
---@async
---@generic T
---@param items T[]
---@param opts table
---@return T | nil
function M.ui_select(items, opts)
  opts = opts or { prompt = "Select" }
  local co = coroutine.running()
  local ui_select_fn = C.ui_select_fn

  --- vim.ui.select is synchronous
  --- telescope and snacks.picker is asynchronous
  --- so the ui_select_fn is **potentially** asynchronous
  --- use vim.schedule to make it awlays asynchronous
  vim.schedule(function()
    ui_select_fn(items, opts, function(choice, _)
      if coroutine.status(co) == "suspended" then
        coroutine.resume(co, choice)
      end
    end)
  end)

  --- `yield` is expected to be called before `resume`.
  return coroutine.yield()
end

return M
