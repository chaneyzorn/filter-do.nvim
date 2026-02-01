local M = {}

--- wrapping vim.ui.select as async function
---@async
---@param items any[]
---@param opts table
---@return any | nil
function M.ui_select(items, opts)
  opts = opts or { prompt = "Select" }
  local co = coroutine.running()

  vim.ui.select(items, opts, function(choice, _)
    if coroutine.status(co) == "suspended" then
      coroutine.resume(co, choice)
    end
  end)

  return coroutine.yield()
end

return M
