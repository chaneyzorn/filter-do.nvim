---@module "filter_do.cmd"

local U = require("filter_do.util")

---@param user_cmd vim.api.keyset.create_user_command.command_args
---@return filter_do.BufRange
local function get_buf_range_from_cmd(user_cmd)
  local bufnr = vim.api.nvim_get_current_buf()
  local v_char_wised = user_cmd.name == "Fxv" and user_cmd.range == 2

  ---@type filter_do.BufRange
  local buf_range = {
    bufnr = bufnr,
    v_char_wised = v_char_wised,
    start_row = user_cmd.line1,
    end_row = user_cmd.line2,
    start_col = 1,
    end_col = vim.v.maxcol,
  }

  if v_char_wised then
    local _, lnum1, col1 = unpack(vim.fn.getpos("'<"))
    local _, lnum2, col2 = unpack(vim.fn.getpos("'>"))
    if lnum1 == user_cmd.line1 and lnum2 == user_cmd.line2 then
      buf_range = {
        bufnr = bufnr,
        v_char_wised = v_char_wised,
        start_row = user_cmd.line1,
        end_row = user_cmd.line2,
        start_col = col1,
        end_col = col2,
      }
    end
  end

  return buf_range
end

---@param user_cmd vim.api.keyset.create_user_command.command_args
---@return filter_do.CodeSnipSpec
local function get_code_snip_spec_from_cmd(user_cmd)
  local sub_cmd = user_cmd.fargs[1]
  local _, modifier = string.match(sub_cmd, "^(.-)([+-]*)$")
  local code_snip = user_cmd.args:sub(#sub_cmd + 2)
  local use_last_code = modifier:find("-") ~= nil

  if use_last_code then
    return { type = "use_last_code", value = nil }
  else
    return { type = "code_snip", value = code_snip }
  end
end

---@param user_cmd vim.api.keyset.create_user_command.command_args
---@return filter_do.FxCtx
local function parse_fx_cmd_ctx(user_cmd)
  local sub_cmd = user_cmd.fargs[1]
  local tpl_name, modifier = string.match(sub_cmd, "^(.-)([+-]*)$")
  local edit_scratch = modifier:find("+") ~= nil

  local code_snip_spec = get_code_snip_spec_from_cmd(user_cmd)
  local buf_range = get_buf_range_from_cmd(user_cmd)

  ---@type filter_do.EnvKv
  local env = {
    START_ROW = string.format("%s", buf_range.start_row),
    END_ROW = string.format("%s", buf_range.end_row),
    FX_LOG = U.get_log_path(),
  }

  ---@type filter_do.FxCtx
  local ctx = {
    tpl_name = tpl_name,
    code_snip_spec = code_snip_spec,
    edit_scratch = edit_scratch,
    buf_range = buf_range,
    env = env,
  }
  return ctx
end

local M = {}

---@param user_cmd vim.api.keyset.create_user_command.command_args
function M.fx_cmd(user_cmd)
  local sub_cmds = {
    log = require("filter_do.api").view_log,
  }

  -- check sub_cmds first
  local ctx = parse_fx_cmd_ctx(user_cmd)
  local sub_cmd = ctx.tpl_name
  local sub_cmd_fn = sub_cmds[sub_cmd]
  if sub_cmd_fn then
    return sub_cmd_fn()
  else
    return require("filter_do.api").filter_do(ctx)
  end
end

return M
