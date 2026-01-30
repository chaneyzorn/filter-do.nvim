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
function F:_load_template_file()
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

---@param identify string|integer
---@return string
function F:_stub_path(identify)
  local stub_file_name = string.format("fx_stub.%s.%s", identify, self.tpl_name)
  return vim.fs.joinpath(U.ensure_cache_path("stubs"), stub_file_name)
end

---@return string[]
function F:list_all_stubs()
  return vim.fn.glob(self:_stub_path("*"), false, true)
end

function F:clean_stubs(keep_num)
  local stub_paths = self:list_all_stubs()
  if #stub_paths <= keep_num then
    return
  end
  -- sort by filename ascendingly to remove old stubs first
  table.sort(stub_paths, function(a, b)
    return a < b
  end)
  for i = 1, #stub_paths - keep_num do
    os.remove(stub_paths[i])
  end
end

---@return string|nil
function F:_get_last_stub()
  local stub_paths = self:list_all_stubs()
  if #stub_paths == 0 then
    return nil
  end
  -- sort by filename descendingly to get the last used stub
  table.sort(stub_paths, function(a, b)
    return a > b
  end)
  return stub_paths[1]
end

---@param code_snip string|nil
---@return string|nil
function F:gen_stub_by_code_snip(code_snip)
  local tpl = self:_load_template_file()
  if not tpl then
    return nil
  end

  local stub_path = self:_stub_path(os.time())
  local f, err = io.open(stub_path, "w")
  if f == nil then
    local err_msg = string.format("filter_do.nvim: %s", err)
    U.msg_err(err_msg)
    return nil
  end

  local content = tpl.content
  if code_snip and #code_snip > 0 then
    local pattern = "(.*\n%s*)(.-USER_CODE)(.*)"
    content = string.gsub(tpl.content, pattern, function(head, _, tail)
      return head .. code_snip .. tail
    end)
  end

  f:write(content)
  f:close()

  return stub_path
end

---@return string|nil
function F:gen_stub_by_last_used()
  local last_stub = self:_get_last_stub()
  if not last_stub then
    local err_msg = string.format("filter_do.nvim: no previous code found for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return nil
  end

  -- rename the last used stub to a new one with current timestamp
  local new_stub_path = self:_stub_path(os.time())
  local cp_res = vim.system({ "cp", last_stub, new_stub_path }):wait()
  if cp_res.code ~= 0 then
    local err_msg = string.format("filter_do.nvim: failed to copy stub file %s to %s", last_stub, new_stub_path)
    U.msg_err(err_msg)
    return nil
  end
  return new_stub_path
end

---@param src_path string
---@return string|nil
function F:gen_stub_by_exist_file(src_path)
  if vim.uv.fs_stat(src_path) == nil then
    local err_msg = string.format("filter_do.nvim: source file %s does not exist", src_path)
    U.msg_err(err_msg)
    return nil
  end

  local new_stub_path = self:_stub_path(os.time())
  local cp_res = vim.system({ "cp", src_path, new_stub_path }):wait()
  if cp_res.code ~= 0 then
    local err_msg = string.format("filter_do.nvim: failed to copy stub file %s to %s", src_path, new_stub_path)
    U.msg_err(err_msg)
    return nil
  end
  return new_stub_path
end

---@param func fun(filter_do.filter.Filter):string
---@return string|nil
function F:gen_stub_by_dynamic_func(func)
  local src_path = func(self)
  if not src_path or #src_path == 0 then
    local err_msg = string.format("filter_do.nvim: dynamic func returned empty path for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return nil
  end
  if vim.uv.fs_stat(src_path) == nil then
    local err_msg = string.format("filter_do.nvim: source file %s does not exist", src_path)
    U.msg_err(err_msg)
    return nil
  end
  return src_path
end

---@param code_snip_spec filter_do.CodeSnipSpec
---@return string|nil
function F:gen_stub_by_spec(code_snip_spec)
  local value = code_snip_spec.value
  if code_snip_spec.type == "code_snip" then
    ---@cast value string
    return self:gen_stub_by_code_snip(value)
  elseif code_snip_spec.type == "use_last_code" then
    return self:gen_stub_by_last_used()
  elseif code_snip_spec.type == "exist_path" then
    ---@cast value string
    return self:gen_stub_by_exist_file(value)
  elseif code_snip_spec.type == "dynamic_func" then
    ---@cast value fun(filter_do.filter.Filter):string
    return self:gen_stub_by_dynamic_func(value)
  else
    local err_msg = string.format("filter_do.nvim: unknown code snip spec type %s", code_snip_spec.type)
    U.msg_err(err_msg)
    return nil
  end
end

---@param ctx filter_do.FxCtx
---@return integer
function F:_copy_range_to_new_buf(ctx)
  local lines = {}
  if ctx.buf_range.v_char_wised then
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
function F:_set_range_with_buf_text(ctx, src_buf)
  local lines = vim.api.nvim_buf_get_lines(src_buf, 0, -1, false)
  if ctx.buf_range.v_char_wised then
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
---@param src_path string|nil not gen stub file if specified
---@return integer|nil
function F:exec_filter(ctx, src_path)
  local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = ctx.buf_range.bufnr })
  local readonly = vim.api.nvim_get_option_value("readonly", { buf = ctx.buf_range.bufnr })
  if readonly or not modifiable then
    local err_msg = string.format("filter_do.nvim: buffer %s is not modifiable", ctx.buf_range.bufnr)
    U.msg_err(err_msg)
    return
  end

  if src_path == nil then
    src_path = self:gen_stub_by_spec(ctx.code_snip_spec)
  end
  if not src_path then
    return
  end

  local executor_ctx = self.executor.pre_action({
    src_path = src_path,
    fx_ctx = vim.deepcopy(ctx),
    env = vim.deepcopy(ctx.env),
    user_data = {},
  })
  if not executor_ctx then
    local err_msg = string.format("filter_do.nvim: pre_action failed for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return
  end

  local filter_cmd = self.executor.filter_cmd(executor_ctx)
  if not filter_cmd or #filter_cmd == 0 then
    local err_msg = string.format("filter_do.nvim: failed to gen cmd for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return
  end

  if ctx.buf_range.v_char_wised then
    local new_buf = self:_copy_range_to_new_buf(ctx)
    local res_code = vim.api.nvim_buf_call(new_buf, function()
      vim.api.nvim_cmd({
        cmd = "!",
        args = { U.env_kv_str(executor_ctx.env), unpack(filter_cmd) },
        range = { 1, vim.api.nvim_buf_line_count(new_buf) },
      }, {})
      local res_code = vim.v.shell_error
      if res_code ~= 0 then
        U.msg_err(string.format("filter_do.nvim: %s failed with code %s", self.tpl_name, res_code))
      end
      return res_code
    end)
    if res_code == 0 then
      self:_set_range_with_buf_text(ctx, new_buf)
    end
    vim.api.nvim_buf_delete(new_buf, { force = true })
    return res_code
  end

  return vim.api.nvim_buf_call(ctx.buf_range.bufnr, function()
    vim.api.nvim_cmd({
      cmd = "!",
      args = { U.env_kv_str(executor_ctx.env), unpack(filter_cmd) },
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
  local user_tpl_list = {}
  local tpl_list = vim.api.nvim_get_runtime_file("fxtpl/*", true)
  for _, path in pairs(tpl_list) do
    -- make sure user templates override built-in ones
    if path:find("filter_do.nvim/fxtpl") then
      local filter = F.new(path)
      res[filter.tpl_name] = filter
    else
      table.insert(user_tpl_list, path)
    end
  end
  for _, path in pairs(user_tpl_list) do
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

---@param keep_num integer
function F.clean_all_stubs(keep_num)
  local filters = F.list_filters()
  for _, filter in pairs(filters) do
    filter:clean_stubs(keep_num)
  end
end

return F
