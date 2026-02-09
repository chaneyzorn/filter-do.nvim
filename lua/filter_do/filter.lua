local U = require("filter_do.util")
local E = require("filter_do.executors")

local VIM_PID = tostring(vim.fn.getpid())

---@class filter_do.filter.Filter
---@field tpl_name string
---@field path string
---@field executor filter_do.executors.ExecutorInfo
---@field private _tpl? {path:string, content:string}
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

---@return {path:string, content:string}|nil
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

---@param identify string
---@return string
function F:_stub_path(identify)
  -- identify: <timestamp>.<seq>.<pid>
  -- stub_file: fx_stub.<timestamp>.<seq>.<pid>.<tpl_name>
  local stub_file_name = string.format("fx_stub.%s.%s", identify, self.tpl_name)
  return vim.fs.joinpath(U.ensure_cache_path("stubs"), stub_file_name)
end

---@param identify string
---@return string
function F:_record_path(identify)
  -- identify: <timestamp>.<seq>.<sha256sum>
  -- record_file: fx_record.<timestamp>.<seq>.<sha256sum>.<tpl_name>
  local record_file_name = string.format("fx_record.%s.%s", identify, self.tpl_name)
  return vim.fs.joinpath(U.ensure_cache_path("records"), record_file_name)
end

---@param current_instance boolean
---@return string[]
function F:list_stub_paths(current_instance)
  if current_instance then
    return vim.fn.glob(self:_stub_path("*." .. VIM_PID), false, true)
  else
    return vim.fn.glob(self:_stub_path("*"), false, true)
  end
end

---@param order string "asc" | "desc"
---@param include_tpl_itself boolean
---@return filter_do.SnippetHistoryRecord[]
function F:list_history_records(order, include_tpl_itself)
  local res = {}
  local record_paths = vim.fn.glob(self:_record_path("*"), false, true)
  for _, path in ipairs(record_paths) do
    local filename = vim.fs.basename(path)
    local timestamp_str, _, sha256sum = string.match(filename, "^fx_record%.(.-)%.(.-)%.(.-)%..+")
    if timestamp_str then
      local timestamp = tonumber(timestamp_str)
      if timestamp then
        table.insert(res, {
          tpl_name = self.tpl_name,
          path = path,
          filename = filename,
          sha256sum = sha256sum,
          timestamp = timestamp,
          is_tpl = false,
        })
      end
    end
  end
  if include_tpl_itself then
    table.insert(res, {
      tpl_name = self.tpl_name,
      path = self.path,
      filename = self.tpl_name,
      sha256sum = "",
      timestamp = os.time(),
      is_tpl = true,
    })
  end
  if order == "desc" then
    table.sort(res, function(a, b)
      return a.timestamp > b.timestamp
    end)
  else
    table.sort(res, function(a, b)
      return a.timestamp < b.timestamp
    end)
  end
  return res
end

---@param keep_num integer
function F:clean_stubs_and_records(keep_num)
  -- clean stub files
  local stub_paths = self:list_stub_paths(true)
  for _, stub_path in ipairs(stub_paths) do
    os.remove(stub_path)
  end

  -- clean history records
  local records = self:list_history_records("asc", false)
  if #records <= keep_num then
    return
  end
  for i = 1, #records - keep_num do
    os.remove(records[i].path)
  end
end

---@return string|nil
function F:_get_last_record_path()
  local records = self:list_history_records("desc", false)
  if #records == 0 then
    return nil
  end
  return records[1].path
end

---@param code_snip string|nil
---@return string|nil
function F:gen_stub_by_code_snip(code_snip)
  local tpl = self:_load_template_file()
  if not tpl then
    return nil
  end

  local stub_path = self:_stub_path(U.time_seq(VIM_PID))
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
  local last_record_path = self:_get_last_record_path()
  if not last_record_path then
    local err_msg = string.format("filter_do.nvim: no previous code found for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return nil
  end

  -- copy the last used record to a new one with current timestamp
  local new_stub_path = self:_stub_path(U.time_seq(VIM_PID))
  local cp_res = vim.system({ "cp", last_record_path, new_stub_path }):wait()
  if cp_res.code ~= 0 then
    local err_msg = string.format("filter_do.nvim: failed to copy stub file %s to %s", last_record_path, new_stub_path)
    U.msg_err(err_msg)
    return nil
  end
  return new_stub_path
end

---@param exist_path string
---@return string|nil
function F:gen_stub_by_exist_file(exist_path)
  if vim.uv.fs_stat(exist_path) == nil then
    local err_msg = string.format("filter_do.nvim: source file %s does not exist", exist_path)
    U.msg_err(err_msg)
    return nil
  end

  local new_stub_path = self:_stub_path(U.time_seq(VIM_PID))
  local cp_res = vim.system({ "cp", exist_path, new_stub_path }):wait()
  if cp_res.code ~= 0 then
    local err_msg = string.format("filter_do.nvim: failed to copy stub file %s to %s", exist_path, new_stub_path)
    U.msg_err(err_msg)
    return nil
  end
  return new_stub_path
end

---@param func fun(filter_do.filter.Filter):(string,boolean)
---@return string|nil
function F:gen_stub_by_dynamic_func(func)
  local stub_path, keep = func(self)
  if not stub_path or #stub_path == 0 then
    local err_msg = string.format("filter_do.nvim: dynamic func returned empty path for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return nil
  end
  if vim.uv.fs_stat(stub_path) == nil then
    local err_msg = string.format("filter_do.nvim: source file %s does not exist", stub_path)
    U.msg_err(err_msg)
    return nil
  end
  local new_stub_path = self:_stub_path(U.time_seq(VIM_PID))
  local cp_res = vim.system({ "cp", stub_path, new_stub_path }):wait()
  if cp_res.code ~= 0 then
    local err_msg = string.format("filter_do.nvim: failed to copy stub file %s to %s", stub_path, new_stub_path)
    U.msg_err(err_msg)
    return nil
  end
  if not keep then
    os.remove(stub_path)
  end
  return new_stub_path
end

---@param code_snip_spec filter_do.CodeSnipSpec
---@return string|nil
function F:gen_stub_by_spec(code_snip_spec)
  U.trigger_user_cmd("GenStubPre", { spec = code_snip_spec })

  local stub_path = nil
  local value = code_snip_spec.value
  if code_snip_spec.type == "code_snip" then
    ---@cast value string
    stub_path = self:gen_stub_by_code_snip(value)
  elseif code_snip_spec.type == "use_last_code" then
    stub_path = self:gen_stub_by_last_used()
  elseif code_snip_spec.type == "exist_path" then
    ---@cast value string
    stub_path = self:gen_stub_by_exist_file(value)
  elseif code_snip_spec.type == "dynamic_func" then
    ---@cast value fun(filter_do.filter.Filter):(string,boolean)
    stub_path = self:gen_stub_by_dynamic_func(value)
  else
    local err_msg = string.format("filter_do.nvim: unknown code snip spec type %s", code_snip_spec.type)
    U.msg_err(err_msg)
    stub_path = nil
  end

  U.trigger_user_cmd("GenStubPost", {
    spec = code_snip_spec,
    stub_path = stub_path,
  })
  return stub_path
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
---@param stub_path string|nil not gen stub file if specified
---@return boolean
function F:exec_filter(ctx, stub_path)
  U.trigger_user_cmd("ExecPre", { ctx = ctx })

  local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = ctx.buf_range.bufnr })
  local readonly = vim.api.nvim_get_option_value("readonly", { buf = ctx.buf_range.bufnr })
  if readonly or not modifiable then
    local err_msg = string.format("filter_do.nvim: buffer %s is not modifiable", ctx.buf_range.bufnr)
    U.msg_err(err_msg)
    return false
  end

  local orphan_stub = stub_path == nil
  if orphan_stub then
    stub_path = self:gen_stub_by_spec(ctx.code_snip_spec)
  end
  if not (stub_path and vim.uv.fs_stat(stub_path)) then
    return false
  end

  local executor_ctx = self.executor.pre_action({
    stub_path = stub_path,
    fx_ctx = vim.deepcopy(ctx),
    env = vim.deepcopy(ctx.env),
    user_data = {},
  })
  if not executor_ctx then
    local err_msg = string.format("filter_do.nvim: pre_action failed for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return false
  end

  local filter_cmd = self.executor.filter_cmd(executor_ctx)
  if not filter_cmd or #filter_cmd == 0 then
    local err_msg = string.format("filter_do.nvim: failed to gen cmd for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return false
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
      self:save_stub_as_record(stub_path)
    end
    vim.api.nvim_buf_delete(new_buf, { force = true })

    U.trigger_user_cmd("ExecPost", {
      executor_ctx = executor_ctx,
      filter_cmd = filter_cmd,
      shell_code = res_code,
    })
    if orphan_stub then
      os.remove(stub_path)
    end
    return res_code == 0
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
    if res_code == 0 then
      self:save_stub_as_record(stub_path)
    end

    U.trigger_user_cmd("ExecPost", {
      executor_ctx = executor_ctx,
      filter_cmd = filter_cmd,
      shell_code = res_code,
    })
    if orphan_stub then
      os.remove(stub_path)
    end
    return res_code == 0
  end)
end

---@param stub_path string
---@return boolean
function F:save_stub_as_record(stub_path)
  U.trigger_user_cmd("SaveHistoryPre", { stub_path = stub_path })

  local stub_checksum = U.file_sha256(stub_path)
  if not stub_checksum then
    return false
  end

  ---@type table<string,filter_do.SnippetHistoryRecord>
  local checksums = {}
  local records = self:list_history_records("asc", false)
  for _, record in ipairs(records) do
    if record.sha256sum then
      checksums[record.sha256sum] = record
    end
  end

  local res = nil
  local exist_record = checksums[stub_checksum]
  local new_record_path = self:_record_path(U.time_seq(stub_checksum))
  if exist_record then
    res = vim.system({ "mv", exist_record.path, new_record_path }):wait()
  else
    res = vim.system({ "cp", stub_path, new_record_path }):wait()
  end
  if res.code ~= 0 then
    local msg = string.format("filter-do.nvim: failed to save snippnet record, %s", res.stderr)
    U.msg_err(msg)
  end

  U.trigger_user_cmd("SaveHistoryPost", {
    stub_path = stub_path,
    exist_record = exist_record and exist_record.path,
    new_record = new_record_path,
    checksum = stub_checksum,
  })
  return res.code == 0
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

---@param tpl_name string
---@param order string "asc" | "desc"
---@param include_tpl_itself boolean
---@return filter_do.SnippetHistoryRecord[]
function F.list_history_by_tpl(tpl_name, order, include_tpl_itself)
  local filter = F.get_filter_by_name(tpl_name)
  if not filter then
    return {}
  end
  return filter:list_history_records(order, include_tpl_itself)
end

---@param keep_num integer
function F.clean_all_stubs_and_records(keep_num)
  local filters = F.list_filters()
  for _, filter in pairs(filters) do
    filter:clean_stubs_and_records(keep_num)
  end
end

---@param record filter_do.SnippetHistoryRecord
---@return table{time_str:string,checksum:string,name:string}
function F.snippet_record_display_fields(record)
  local display_name = string.format("fx_record.%s", record.tpl_name)
  local display_checksum = record.sha256sum:sub(1, 10)
  local time_str = vim.fn.strftime("%Y-%m-%dT%H:%M:%S", record.timestamp)
  if record.is_tpl then
    display_name = U.short_path(record.path, 3)
    display_checksum = "[Template]"
  end
  return {
    time_str = time_str,
    checksum = display_checksum,
    name = display_name,
  }
end

---@param record filter_do.SnippetHistoryRecord
---@return string
function F.format_snippet_record(record)
  local display = F.snippet_record_display_fields(record)
  local time_str = display.time_str
  local display_checksum = display.checksum
  local display_name = display.name
  return string.format("%s %s %s", time_str, display_checksum, display_name)
end

return F
