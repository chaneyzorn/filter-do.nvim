local U = require("filter_do.util")
local E = require("filter_do.executors")

---@class filter_do.filter.Tpl
---@field  path string
---@field  content string

---@class filter_do.filter.Filter
---@field tpl_name string
---@field path string
---@field executor filter_do.executors.ExecutorInfo
---@field private _tpl filter_do.filter.Tpl?
local F = {}
F.__index = F

---@param path string
---@return filter_do.filter.Filter
function F.new(path)
  local tpl_name = vim.fs.basename(path)

  local self = setmetatable({}, F)
  self.tpl_name = tpl_name
  self.path = path
  self.executor = E.get_executor(tpl_name)
  return self
end

---@return filter_do.filter.Tpl|nil
function F:load_template_file()
  if self._tpl then
    return self._tpl
  end

  local f = io.open(self.path, "r")
  if f == nil then
    local err_msg = string.format("filter_do.nvim: can not open template file %s", self.path)
    U.msg_err(err_msg)
    return nil
  end

  local content = f:read("*a")
  f:close()

  self._tpl = { path = self.path, content = content }
  return self._tpl
end

---@return string|nil
function F:stub_path()
  local tpl = self:load_template_file()
  if not tpl then
    return nil
  end

  return vim.fs.joinpath(U.ensure_cache_path(), string.format("fx_stub.%s", self.tpl_name))
end

---@return string|nil
function F:get_exists_stub()
  local stub_path = self:stub_path()
  if not stub_path then
    return nil
  end

  local stat = vim.uv.fs_stat(stub_path)
  if not stat then
    return nil
  end

  return stub_path
end

---@param ctx filter_do.FxCtx|nil
---@return string|nil
function F:gen_stub_file(ctx)
  if ctx and ctx.use_last_code then
    local stub_path = self:get_exists_stub()
    if not stub_path then
      local err_msg = string.format("filter_do.nvim: no previous code found for filter %s", self.tpl_name)
      U.msg_err(err_msg)
      return nil
    end
    return stub_path
  end

  local tpl = self:load_template_file()
  if not tpl then
    return nil
  end

  local stub_path = self:stub_path()
  if not stub_path then
    return nil
  end

  local f, err = io.open(stub_path, "w")
  if f == nil then
    local err_msg = string.format("filter_do.nvim: %s", err)
    U.msg_err(err_msg)
    return nil
  end

  local content = tpl.content
  if ctx and ctx.code_snip and #ctx.code_snip > 0 then
    local pattern = "(.*\n%s*)(.-USER_CODE)(.*)"
    content = string.gsub(tpl.content, pattern, function(head, _, tail)
      return head .. ctx.code_snip .. tail
    end)
  end

  f:write(content)
  f:close()

  return stub_path
end

---@param ctx filter_do.FxCtx
---@return integer
function F:copy_range_to_new_buf(ctx)
  local lines = {}
  if ctx.v_char_wised then
    lines = vim.api.nvim_buf_get_text(
      ctx.buf_range.bufnr,
      ctx.buf_range.start_row - 1,
      ctx.buf_range.start_col - 1,
      ctx.buf_range.end_row - 1,
      ctx.buf_range.end_col,
      {}
    )
  else
    lines = vim.api.nvim_buf_get_lines( -- keep line wrapping, make stylua happy
      ctx.buf_range.bufnr,
      ctx.buf_range.start_row - 1,
      ctx.buf_range.end_row,
      false
    )
  end

  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, lines)
  return new_buf
end

---@param ctx filter_do.FxCtx
---@param src_buf integer
---@return nil
function F:set_range_with_buf_text(ctx, src_buf)
  local lines = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
  if ctx.v_char_wised then
    vim.api.nvim_buf_set_text(
      ctx.buf_range.bufnr,
      ctx.buf_range.start_row - 1,
      ctx.buf_range.start_col - 1,
      ctx.buf_range.end_row - 1,
      ctx.buf_range.end_col,
      lines
    )
  else
    vim.api.nvim_buf_set_lines( -- keep line wrapping, make stylua happy
      ctx.buf_range.bufnr,
      ctx.buf_range.start_row - 1,
      ctx.buf_range.end_row,
      false,
      lines
    )
  end
end

---@param ctx filter_do.FxCtx
---@param src_path string|nil
function F:exec_filter(ctx, src_path)
  local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = ctx.buf_range.bufnr })
  local readonly = vim.api.nvim_get_option_value("readonly", { buf = ctx.buf_range.bufnr })
  if readonly or not modifiable then
    local err_msg = string.format("filter_do.nvim: buffer %s is not modifiable", ctx.buf_range.bufnr)
    U.msg_err(err_msg)
    return
  end

  if src_path == nil then
    src_path = self:gen_stub_file(ctx)
  end
  if not src_path then
    return
  end

  local tpl_ctx = self.executor.pre_action({
    src_path = src_path,
    fx_ctx = vim.deepcopy(ctx),
    env = vim.deepcopy(ctx.env),
    user_data = {},
  })
  if not tpl_ctx then
    local err_msg = string.format("filter_do.nvim: pre_action failed for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return
  end

  local filter_cmd = self.executor.filter_cmd(tpl_ctx)
  if not filter_cmd or #filter_cmd == 0 then
    local err_msg = string.format("filter_do.nvim: failed to gen cmd for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return
  end

  if ctx.v_char_wised then
    local new_buf = self:copy_range_to_new_buf(ctx)
    local res_code = vim.api.nvim_buf_call(new_buf, function()
      vim.api.nvim_cmd({
        cmd = "!",
        args = { U.env_kv_str(tpl_ctx.env), unpack(filter_cmd) },
        range = { 1, vim.api.nvim_buf_line_count(new_buf) },
      }, {})
      local res_code = vim.v.shell_error
      if res_code ~= 0 then
        U.msg_err(string.format("filter_do.nvim: %s failed with code %s", self.tpl_name, res_code))
      end
      return res_code
    end)
    if res_code == 0 then
      self:set_range_with_buf_text(ctx, new_buf)
    end
    vim.api.nvim_buf_delete(new_buf, { force = true })
    return res_code
  end

  return vim.api.nvim_buf_call(ctx.buf_range.bufnr, function()
    vim.api.nvim_cmd({
      cmd = "!",
      args = { U.env_kv_str(tpl_ctx.env), unpack(filter_cmd) },
      range = { ctx.buf_range.start_row, ctx.buf_range.end_row },
    }, {})
    local res_code = vim.v.shell_error
    if res_code ~= 0 then
      U.msg_err(string.format("filter_do.nvim: %s failed with code %s", self.tpl_name, res_code))
    end
    return res_code
  end)
end

---@return table<string, filter_do.filter.Filter>
function F.list_filters()
  local res = {}
  -- TODO: make sure the built-in templates are listed at first
  local tpl_list = vim.api.nvim_get_runtime_file("fxtpl/*", true)
  for _, path in pairs(tpl_list) do
    local filter = F.new(path)
    res[filter.tpl_name] = filter
  end
  return res
end

---@param tpl_name string
---@return filter_do.filter.Filter|nil
function F.get_filter_by_name(tpl_name)
  local filters = F.list_filters()
  return filters[tpl_name]
end

return F
