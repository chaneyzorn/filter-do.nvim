local P = require("xdo.provider")
local U = require("xdo.util")

local M = {}

---@param ctx xdo.XdoCtx
function M.xdo(ctx)
  local p = P.get_provider(ctx.provider)
  if not p then
    local err_msg = string.format("xdo.nvim: provider not found for %s", ctx.provider)
    U.msg_err(err_msg)
    return
  end
  return p:exec_filter(ctx)
end

function M.xdo_view_log()
  local tmp_path = vim.fs.dirname(vim.fn.tempname())
  local log_path = vim.fs.joinpath(tmp_path, "xdo_stub.log")
  if not vim.uv.fs_stat(log_path) then
    U.msg_info("xdo.nvim: log is empty")
    return
  end
  return vim.cmd("vertical sview " .. log_path)
end

return M
