---@module "filter_do.api"

local F = require("filter_do.filter")
local U = require("filter_do.util")

local M = {}

---@param ctx filter_do.FxCtx
function M.filter_do(ctx)
  local filter = F.get_filter_by_name(ctx.tpl_name)
  if not filter then
    local err_msg = string.format("filter_do.nvim: filter not found for %s", ctx.tpl_name)
    U.msg_err(err_msg)
    return
  end
  return filter:exec_filter(ctx)
end

-- TODO: api for user call

function M.fx_view_log()
  local tmp_path = vim.fs.dirname(vim.fn.tempname())
  local log_path = vim.fs.joinpath(tmp_path, "filter_do.log")
  if not vim.uv.fs_stat(log_path) then
    U.msg_info("filter_do.nvim: log is empty")
    return
  end
  return vim.cmd("vertical sview " .. log_path)
end

return M
