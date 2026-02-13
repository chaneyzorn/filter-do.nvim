---@module "filter_do.api"

local F = require("filter_do.filter")
local U = require("filter_do.utils")
local Async = require("filter_do.async")
local Cfg = require("filter_do.config").get()

local M = {}

---list all available filters
---@return {tpl_name:string, path:string}[]
function M.list_filters()
  local res = {}
  for _, filter in pairs(F.list_filters()) do
    table.insert(res, {
      tpl_name = filter.tpl_name,
      path = filter.path,
    })
  end
  table.sort(res, function(a, b)
    return a.tpl_name < b.tpl_name
  end)
  return res
end

M.get_filter_by_name = F.get_filter_by_name
M.list_history_by_tpl = F.list_history_by_tpl
M.get_current_buffer_range = U.get_current_buffer_range

--- the core api to do filter execution
---@param ctx filter_do.FxCtx
function M.filter_do(ctx)
  if ctx.edit_scratch then
    vim.schedule(function()
      require("filter_do.ui").new({ ctx }):open_ui()
    end)
    return
  end

  local filter = F.get_filter_by_name(ctx.tpl_name)
  if not filter then
    local err_msg = string.format("filter_do.nvim: filter not found for %s", ctx.tpl_name)
    U.msg_err(err_msg)
    return
  end
  return filter:exec_filter(ctx)
end

---@param ctxs filter_do.FxCtx[]
function M.batch_filter_do(ctxs)
  local sync_ctx = {}
  local async_ctx = {}
  for _, ctx in ipairs(ctxs) do
    if ctx.edit_scratch then
      table.insert(async_ctx, ctx)
    else
      table.insert(sync_ctx, ctx)
    end
  end
  for _, ctx in ipairs(sync_ctx) do
    M.filter_do(ctx)
  end
  if #async_ctx > 0 then
    vim.schedule(function()
      require("filter_do.ui").new(async_ctx):open_ui()
    end)
  end
end

---@async
---@param ctx_getter filter_do.api.FxCtxGetter
---@return filter_do.FxCtx | nil
local function get_ctx_from_getter(ctx_getter)
  local buf_range = ctx_getter.get_buf_range()
  if not buf_range then
    return nil
  end
  local tpl_name = ctx_getter.select_tpl()
  if not tpl_name then
    return nil
  end
  local code_snip_spec = ctx_getter.get_code_snip_spec(tpl_name)
  if not code_snip_spec then
    return nil
  end
  local edit_scratch = ctx_getter.edit_before_apply()
  ---@type filter_do.FxCtx
  local ctx = {
    buf_range = buf_range,
    tpl_name = tpl_name,
    code_snip_spec = code_snip_spec,
    edit_scratch = edit_scratch,
    envs = {},
  }
  local getter_envs = ctx_getter.get_envs(ctx) or {}
  local defaut_envs = U.default_envs(ctx)
  ctx.envs = vim.tbl_deep_extend("force", defaut_envs, getter_envs)
  return ctx
end

---@param ctx_getter filter_do.api.FxCtxGetter
function M.filter_do_wrapper(ctx_getter)
  coroutine.wrap(function()
    local ctx = get_ctx_from_getter(ctx_getter)
    if ctx then
      M.filter_do(ctx)
    end
  end)()
end

---an easy-to-use api to do filter execution with ui selection
---@param opts filter_do.FxCtxOpts|nil
function M.select_filter_do(opts)
  if vim.fn.mode():match("^[nvV]") == nil then
    U.msg_err("filter_do.nvim: can only be called in visual mode and normal mode")
    return
  end

  ---@type filter_do.api.FxCtxGetter
  local ctx_getter = {
    get_buf_range = function()
      if opts and opts.buf_range then
        return opts.buf_range
      end
      return U.get_current_buffer_range()
    end,
    select_tpl = function()
      if opts and opts.tpl_name then
        return opts.tpl_name
      end
      ---@type { tpl_name: string, path: string } | nil
      local filter = Async.ui_select(M.list_filters(), {
        prompt = "filter-do.nvim: Select a filter template",
        format_item = function(item)
          return U.short_path(item.path, 3)
        end,
      })
      return filter and filter.tpl_name
    end,
    get_code_snip_spec = function(tpl_name)
      if opts and opts.code_snip_spec then
        return opts.code_snip_spec
      end
      ---@type filter_do.SnippetHistoryRecord | nil
      local record = Async.ui_select(M.list_history_by_tpl(tpl_name, "desc", Cfg.ui.show_tpl_as_record), {
        prompt = "filter-do.nvim: Select a snippet history record",
        format_item = function(item)
          return F.format_snippet_record(item)
        end,
      })
      return record and { type = "exist_path", value = record.path }
    end,
    edit_before_apply = function()
      if opts and opts.edit_scratch ~= nil then
        return opts.edit_scratch
      end
      return true
    end,
    get_envs = function(ctx)
      if opts and opts.envs then
        return opts.envs
      end
      return ctx.envs or {}
    end,
  }

  return M.filter_do_wrapper(ctx_getter)
end

function M.view_log()
  local log_path = U.get_log_path()
  if not vim.uv.fs_stat(log_path) then
    U.msg_info("filter_do.nvim: log is empty")
    return
  end
  return vim.cmd("vertical sview " .. log_path)
end

return M
