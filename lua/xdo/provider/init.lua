---@module "xdo.provider"

local U = require("xdo.util")

---@class xdo.Provider
---@field pinfo xdo.ProviderInfo
---@field private _tpl xdo.Provider.Tpl?
local P = {}
P.__index = P

---@class xdo.Provider.Tpl
---@field  path string
---@field  content string
---@field  line_snip string
---@field  block_snip string

function P.new(pinfo)
  local self = setmetatable({}, P)

  self.pinfo = pinfo
  return self
end

function P:get_template_path()
  local current_path = debug.getinfo(1, "S").source:match("@?(.*/)")
  local current_dir = vim.fs.dirname(current_path)
  local provider_path = vim.fs.joinpath(current_dir, self.pinfo.name)

  local template_path = vim.fs.find(function(file_name)
    return file_name:match("template%..*")
  end, { limit = 1, type = "file", path = provider_path })

  if not template_path[1] then
    local err_msg = string.format("xdo.nvim: can not found template file of %s provider", self.pinfo.name)
    U.msg_err(err_msg)
    return nil
  end

  return template_path[1]
end

function P:load_template_file()
  if self._tpl then
    return self._tpl
  end

  local tpl_path = self:get_template_path()
  if not tpl_path then
    return nil
  end

  local f, err = io.open(tpl_path, "r")
  if f == nil then
    local err_msg = string.format("xdo.nvim: %s", err)
    U.msg_err(err_msg)
    return nil
  end

  local content = f:read("*a")
  f:close()

  self._tpl = {
    path = tpl_path,
    content = content,
    line_snip = content:match("USER_SNIPPET_BEGIN: handle_one_line.-\n(.*\n).-USER_SNIPPET_END: handle_one_line"),
    block_snip = content:match("USER_SNIPPET_BEGIN: handle_block.-\n(.*\n).-USER_SNIPPET_END: handle_block"),
  }
  return self._tpl
end

function P:stub_path()
  local tpl = self:load_template_file()
  if not tpl then
    return nil
  end

  local ext = tpl.path:match(".*%.(.*)$")
  local tmp_path = vim.fs.dirname(vim.fn.tempname())
  return vim.fs.joinpath(tmp_path, string.format("xdo_stub.%s", ext))
end

---@param ctx xdo.XdoCtx
function P:gen_stub_file(ctx)
  local tpl = self:load_template_file()
  if not tpl then
    return nil
  end

  local stub_path = self:stub_path()
  if not stub_path then
    return nil
  end

  local patterns = {
    body = {
      handle_one_line = "(.*\n%s*)(.-USER_INPUT: handle_one_line)(.*)",
      handle_block = "(.*\n%s*)(.-USER_INPUT: handle_block)(.*)",
    },
    scratch = {
      handle_one_line = "(.*USER_SNIPPET_BEGIN: handle_one_line.-\n)(.*)(\n.-USER_SNIPPET_END: handle_one_line.*)",
      handle_block = "(.*USER_SNIPPET_BEGIN: handle_block.-\n)(.*)(\n.-USER_SNIPPET_END: handle_block.*)",
    },
  }

  local p1 = ctx.edit_scratch and patterns.scratch or patterns.body
  local pattern = ctx.v_block_wised and p1.handle_block or p1.handle_one_line
  local content = string.gsub(tpl.content, pattern, function(head, _, tail)
    return head .. ctx.code_snip .. tail
  end)

  local f, err = io.open(stub_path, "w")
  if f == nil then
    local err_msg = string.format("xdo.nvim: %s", err)
    vim.notify(err_msg, vim.log.levels.ERROR)
    return nil
  end

  f:write(content)
  f:close()

  return stub_path
end

---@param ctx xdo.XdoCtx
function P:exec_filter(ctx)
  local src_path = self:gen_stub_file(ctx)
  if not src_path then
    local err_msg = string.format("xdo.nvim: can not found template file of %s provider", self.pinfo.name)
    U.msg_err(err_msg)
    return
  end

  local filter_cmd = self.pinfo.filter_cmd(src_path)
  local env_str = U.env_kv_str(ctx.env)

  return vim.api.nvim_cmd({
    cmd = "!",
    args = { env_str, unpack(filter_cmd) },
    range = { ctx.buf_range.start_row, ctx.buf_range.end_row },
    mods = {
      keepjumps = true,
      keepmarks = true,
    },
  }, {})
end

---@type { [string]: xdo.Provider }
local ps = {}
local p_loaded = false

function P.list_providers()
  if p_loaded then
    return ps
  end

  local current_path = debug.getinfo(1, "S").source:match("@?(.*/)")
  local current_dir = vim.fs.dirname(current_path)
  for sub, tp in vim.fs.dir(current_dir) do
    if tp == "directory" then
      local pinfo = require("xdo.provider." .. sub)
      ps[pinfo.name] = P.new(pinfo)
    end
  end

  p_loaded = true
  return ps
end

---@param name string
function P.get_provider(name)
  return P.list_providers()[name]
end

return P
