---@module "xdo.cmd"

local U = require("xdo.util")

local function parse_xdo_cmd_ctx(user_cmd)
  local bufnr = vim.api.nvim_get_current_buf()
  local sub_cmd = user_cmd.fargs[1]
  local provider, scratch = string.match(sub_cmd, "^(%a+)(%+?)$")
  local code_snip = user_cmd.args:sub(#sub_cmd + 2)

  local v_block_wised = user_cmd.name == "Vdo" or user_cmd.name == "Vdov"
  local v_char_wised = (user_cmd.name == "Xdov" or user_cmd.name == "Vdov") and user_cmd.range == 2

  ---@type Xdo.BufRange
  local buf_range = {
    bufnr = bufnr,
    start_row = user_cmd.line1,
    end_row = user_cmd.line2,
    start_col = 1,
    end_col = vim.v.maxcol,
    tail_len = -1,
  }
  if user_cmd.range == 0 then
    buf_range = {
      bufnr = bufnr,
      start_row = 1,
      end_row = vim.fn.line("$"),
      start_col = 1,
      end_col = vim.v.maxcol,
      tail_len = -1,
    }
  end
  if v_char_wised then
    local _, lnum1, col1 = unpack(vim.fn.getcharpos("'<"))
    local _, lnum2, col2 = unpack(vim.fn.getcharpos("'>"))
    if lnum1 == user_cmd.line1 and lnum2 == user_cmd.line2 then
      --- get line content without line-ending
      local last_line_len = vim.fn.strchars(vim.fn.getbufoneline(bufnr, lnum2))
      --- cursor can move onto line-ending, which cause -1
      local tail_len = math.max(last_line_len - col2, -1)
      buf_range = {
        bufnr = bufnr,
        start_row = user_cmd.line1,
        end_row = user_cmd.line2,
        start_col = col1,
        end_col = col2,
        tail_len = tail_len,
      }
    end
  end

  ---@type xdo.EnvKv
  local env = {
    START_ROW = string.format("%s", buf_range.start_row),
    END_ROW = string.format("%s", buf_range.end_row),
    START_COL = string.format("%s", buf_range.start_col),
    END_COL = string.format("%s", buf_range.end_col),
    TAIL_LEN = string.format("%s", buf_range.tail_len),
    EX_CMD = user_cmd.name,
  }

  ---@type xdo.XdoCtx
  local ctx = {
    provider = provider,
    code_snip = code_snip,
    v_block_wised = v_block_wised,
    v_char_wised = v_char_wised,
    edit_scratch = scratch == "+",
    buf_range = buf_range,
    env = env,
  }
  -- print(vim.inspect(ctx))
  return ctx
end

local function xdo_fn(cmd)
  local ctx = parse_xdo_cmd_ctx(cmd)
  return require("xdo.api").xdo(ctx)
end

local M = {}

function M.dispatch_cmd(user_cmd)
  local Fn = {
    xdo = xdo_fn,
    xdov = xdo_fn,
    vdo = xdo_fn,
    vdov = xdo_fn,
  }
  local fn = Fn[string.lower(user_cmd.name)]
  if not fn then
    U.msg_err(string.format("xdo: unknown cmd %s", user_cmd.name))
  end
  return fn(user_cmd)
end

return M
