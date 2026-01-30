---@module "filter_do.api"

local F = require("filter_do.filter")
local U = require("filter_do.util")

local M = {}

--- the core api to do filter execution
---@param ctx filter_do.FxCtx
function M.filter_do(ctx)
  if ctx.edit_scratch then
    local ui = require("filter_do.ui").new()
    ui:open_scratch_win(ctx)
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

---@param ctx_getter filter_do.api.FxCtxGetter
---@return filter_do.FxCtx
function M.get_ctx_from_getter(ctx_getter)
  ---@type filter_do.FxCtx
  local ctx = {
    buf_range = ctx_getter.get_buf_range(),
    tpl_name = ctx_getter.select_tpl(),
    code_snip_spec = ctx_getter.get_code_snip_spec(),
    edit_scratch = ctx_getter.edit_before_apply(),
    env = ctx_getter.get_env(),
  }
  ctx = vim.tbl_deep_extend("force", ctx, ctx_getter.opts or {})
  return ctx
end

---@param ctx_getter filter_do.api.FxCtxGetter
function M.filter_do_wrapper(ctx_getter)
  local ctx = M.get_ctx_from_getter(ctx_getter)
  return M.filter_do(ctx)
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
