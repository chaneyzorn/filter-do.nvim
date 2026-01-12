local U = require("filter_do.util")

---@class filter_do.filter.TplCtx
---@field src_path string

---@class filter_do.filter.FilterInfo
---@field pre_action fun(ctx:filter_do.filter.TplCtx):filter_do.filter.TplCtx|nil
---@field filter_cmd fun(ctx:filter_do.filter.TplCtx):string[]|nil

---@class filter_do.filter.Tpl
---@field  path string
---@field  content string

---@class filter_do.filter.Filter
---@field tpl_name string
---@field path string
---@field finfo filter_do.filter.FilterInfo
---@field private _tpl filter_do.filter.Tpl?
local F = {}
F.__index = F

---@param ctx filter_do.filter.TplCtx
---@return filter_do.filter.TplCtx|nil
function F.default_pre_action(ctx)
  return ctx
end

---@param ctx filter_do.filter.TplCtx
---@return string[]|nil
function F.default_python_cmd(ctx)
  local py3 = vim.g.python3_host_prog or vim.fn.exepath("python3")
  if py3 == "" or py3 == nil then
    local err_msg = "filter_do.nvim: python3 interpreter not found, please set g:python3_host_prog"
    U.msg_err(err_msg)
    return nil
  end
  return { py3, ctx.src_path }
end

---@param ctx filter_do.filter.TplCtx
---@return string[]|nil
function F.default_node_cmd(ctx)
  local node = vim.g.node_host_prog or vim.fn.exepath("node")
  if node == "" or node == nil then
    local err_msg = "filter_do.nvim: node interpreter not found, please set g:node_host_prog"
    U.msg_err(err_msg)
    return nil
  end
  return { node, ctx.src_path }
end

F.default_chmodx_filter = {
  pre_action = function(ctx)
    local res = vim.system({ "chmod", "+x", ctx.src_path }):wait()
    if res.code ~= 0 then
      local err_msg = string.format("filter_do.nvim: failed to chmod +x to %s, err: %s", ctx.src_path, res.stderr)
      U.msg_err(err_msg)
      return nil
    else
      return ctx
    end
  end,
  filter_cmd = function(ctx)
    return { ctx.src_path }
  end,
}

F.default_python_filter = {
  pre_action = F.default_pre_action,
  filter_cmd = F.default_python_cmd,
}

F.default_js_filter = {
  pre_action = F.default_pre_action,
  filter_cmd = F.default_node_cmd,
}

local filter_info = {
  ["line.py"] = F.default_python_filter,
  ["text.py"] = F.default_python_filter,
  ["line.js"] = F.default_js_filter,
  ["text.js"] = F.default_js_filter,
}

---@param path string
---@return filter_do.filter.Filter
function F.new(path)
  local tpl_name = vim.fs.basename(path)
  local finfo = filter_info[tpl_name] or F.default_chmodx_filter

  local self = setmetatable({}, F)
  self.tpl_name = tpl_name
  self.path = path
  self.finfo = finfo
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

  local tmp_path = vim.fs.dirname(vim.fn.tempname())
  return vim.fs.joinpath(tmp_path, string.format("fx_stub.%s", self.tpl_name))
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

  local tpl_ctx = self.finfo.pre_action({ src_path = src_path })
  if not tpl_ctx then
    local err_msg = string.format("filter_do.nvim: pre_action failed for filter %s", self.tpl_name)
    U.msg_err(err_msg)
    return
  end

  local filter_cmd = self.finfo.filter_cmd(tpl_ctx)
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
        args = { U.env_kv_str(ctx.env), unpack(filter_cmd) },
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
      args = { U.env_kv_str(ctx.env), unpack(filter_cmd) },
      range = { ctx.buf_range.start_row, ctx.buf_range.end_row },
      mods = {
        keepjumps = true,
        keepmarks = true,
      },
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
