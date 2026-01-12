---@module "filter_do.cmd"

local U = require("filter_do.util")

---@param user_cmd vim.api.keyset.create_user_command.command_args
local function parse_fx_cmd_ctx(user_cmd)
  local bufnr = vim.api.nvim_get_current_buf()
  local sub_cmd = user_cmd.fargs[1]
  local tpl_name, modifier = string.match(sub_cmd, "^(.-)([+-]*)$")
  local code_snip = user_cmd.args:sub(#sub_cmd + 2)
  local edit_scratch = modifier:find("+") ~= nil
  local use_last_code = modifier:find("-") ~= nil
  local v_char_wised = user_cmd.name == "Fxv" and user_cmd.range == 2

  ---@type filter_do.BufRange
  local buf_range = {
    bufnr = bufnr,
    start_row = user_cmd.line1,
    end_row = user_cmd.line2,
    start_col = 1,
    end_col = vim.v.maxcol,
    tail_len = -1,
  }
  if user_cmd.range == 0 then
    -- default range is whole buffer
    buf_range = {
      bufnr = bufnr,
      start_row = 1,
      end_row = vim.api.nvim_buf_line_count(bufnr),
      start_col = 1,
      end_col = vim.v.maxcol,
      tail_len = -1,
    }
  end
  if v_char_wised then
    local _, lnum1, col1 = unpack(vim.fn.getpos("'<"))
    local _, lnum2, col2 = unpack(vim.fn.getpos("'>"))
    if lnum1 == user_cmd.line1 and lnum2 == user_cmd.line2 then
      buf_range = {
        bufnr = bufnr,
        start_row = user_cmd.line1,
        end_row = user_cmd.line2,
        start_col = col1,
        end_col = col2,
      }
    end
  end

  ---@type filter_do.EnvKv
  local env = {
    START_ROW = string.format("%s", buf_range.start_row),
    END_ROW = string.format("%s", buf_range.end_row),
    EX_CMD = user_cmd.name,
  }

  ---@type filter_do.FxCtx
  local ctx = {
    tpl_name = tpl_name,
    code_snip = code_snip,
    v_char_wised = v_char_wised,
    edit_scratch = edit_scratch,
    use_last_code = use_last_code,
    buf_range = buf_range,
    env = env,
  }
  -- print(vim.inspect(ctx))
  return ctx
end

---@param user_cmd vim.api.keyset.create_user_command.command_args
local function fx_fn(user_cmd)
  local ctx = parse_fx_cmd_ctx(user_cmd)
  if ctx.edit_scratch then
    local ui = require("filter_do.ui").new()
    ui:open_scratch_win(ctx)
  else
    return require("filter_do.api").filter_do(ctx)
  end
end

local M = {}

---@param user_cmd vim.api.keyset.create_user_command.command_args
function M.dispatch_cmd(user_cmd)
  local Fn = {
    fx = fx_fn,
    fxv = fx_fn,
  }
  local fn = Fn[string.lower(user_cmd.name)]
  if not fn then
    U.msg_err(string.format("filter_do.nvim: unknown cmd %s", user_cmd.name))
  end
  return fn(user_cmd)
end

return M
