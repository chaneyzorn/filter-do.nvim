---@module "filter_do.cmd"

local U = require("filter_do.util")

---@param user_cmd vim.api.keyset.create_user_command.command_args
---@return filter_do.BufRange
local function get_buf_range_from_cmd(user_cmd)
  local bufnr = vim.api.nvim_get_current_buf()
  local undotree_seq = vim.fn.undotree(bufnr).seq_cur

  ---@type filter_do.BufRange
  local buf_range = {
    bufnr = bufnr,
    v_char_wised = false,
    undotree_seq = undotree_seq,
    start_row = user_cmd.line1,
    end_row = user_cmd.line2,
    start_col = 1,
    end_col = vim.v.maxcol,
  }

  -- v-mode char-wised detection
  -- see https://www.petergundel.de/neovim/lua/hack/2023/12/17/get-neovim-mode-when-executing-a-command.html
  if user_cmd.count > 0 and user_cmd.range == 2 then
    -- (1-based lines, 0-based columns)
    local row1, col1 = unpack(vim.api.nvim_buf_get_mark(bufnr, "<"))
    local row2, col2 = unpack(vim.api.nvim_buf_get_mark(bufnr, ">"))
    if row1 == user_cmd.line1 and row2 == user_cmd.line2 and col2 ~= vim.v.maxcol then
      buf_range = {
        bufnr = bufnr,
        v_char_wised = true,
        undotree_seq = undotree_seq,
        start_row = user_cmd.line1,
        end_row = user_cmd.line2,
        -- (1-based lines, 1-based columns)
        start_col = col1 + 1,
        end_col = col2 + 1,
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
  local env = U.default_env_from_buf_range(buf_range)

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

local batch_cmd_ctxs = {}

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
  end

  -- sync executing filter_do
  if not ctx.edit_scratch then
    return require("filter_do.api").filter_do(ctx)
  end

  -- batch async executing filter_do with scratch edit
  local emit_on_first_time = #batch_cmd_ctxs == 0
  table.insert(batch_cmd_ctxs, ctx)
  if emit_on_first_time then
    vim.schedule(function()
      local visited_bufs = {}
      local unique_buf_ctxs = {}
      for _, _ctx in ipairs(batch_cmd_ctxs) do
        if not visited_bufs[_ctx.buf_range.bufnr] then
          table.insert(unique_buf_ctxs, _ctx)
          visited_bufs[_ctx.buf_range.bufnr] = true
        end
      end
      batch_cmd_ctxs = {}
      require("filter_do.api").batch_filter_do(unique_buf_ctxs)
    end)
  end
end

return M
