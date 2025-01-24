---@module "xdo.provider.util"

local U = {}

function U.collect_env(cmd)
  -- TODO: double check vim behavior
  local start_col = vim.fn.getcharpos("'<")[3]
  local end_col = vim.fn.getcharpos("'>")[3]

  return {
    START_LNR = cmd.line1,
    START_COL = start_col,
    END_LNR = cmd.line2,
    END_COL = end_col,
  }
end

function U.env_kvs(env)
  local res = {}
  for k, v in pairs(env) do
    table.insert(res, string.format("%s=%s", k, v))
  end
  table.sort(res)
  return table.concat(res, " ")
end

function U.get_template_path(provider)
  local current_path = debug.getinfo(1, "S").source:match("@?(.*/)")
  local current_dir = vim.fs.dirname(current_path)
  local provider_path = vim.fs.joinpath(current_dir, provider.name)

  local template_path = vim.fs.find(function(name)
    return name:match("template%..*")
  end, { limit = 1, type = "file", path = provider_path })

  if not template_path then
    local err_msg = string.format("xdo.nvim: can not found template file of %s provider", provider.name)
    vim.notify(err_msg, vim.log.levels.ERROR)
    return nil
  end

  return template_path[1]
end

function U.load_template_file(provider)
  if provider._tpl then
    return provider._tpl
  end

  local tpl_path = U.get_template_path(provider)
  if not tpl_path then
    return nil
  end

  local f, err = io.open(tpl_path, "r")
  if f == nil then
    local err_msg = string.format("xdo.nvim: %s", err)
    vim.notify(err_msg, vim.log.levels.ERROR)
    return nil
  end

  local content = f:read("*a")
  f:close()

  provider._tpl = {
    path = tpl_path,
    content = content,
    line_snip = content:match("USER_SNIPPET_BEGIN: handle_one_line.-\n(.*\n).-USER_SNIPPET_END: handle_one_line"),
    block_snip = content:match("USER_SNIPPET_BEGIN: handle_block.-\n(.*\n).-USER_SNIPPET_END: handle_block"),
  }
  return provider._tpl
end

function U.stub_path(provider)
  local tpl = U.load_template_file(provider)
  if not tpl then
    return nil
  end

  local ext = tpl.path:match(".*%.(.*)$")
  local tmp_path = vim.fs.dirname(vim.fn.tempname())
  return vim.fs.joinpath(tmp_path, string.format("xdo_stub.%s", ext))
end

function U.gen_stub_file(provider, user_input)
  local tpl = U.load_template_file(provider)
  if not tpl then
    return nil
  end

  local stub_path = U.stub_path(provider)
  if not stub_path then
    return nil
  end

  local target_pattern = {}
  if user_input.type == "body_code" then
    target_pattern = {
      handle_one_line = "(.*\n%s*)(.-USER_INPUT: handle_one_line)(.*)",
      handle_block = "(.*\n%s*)(.-USER_INPUT: handle_block)(.*)",
    }
  elseif user_input.type == "function_code" then
    target_pattern = {
      handle_one_line = "(.*USER_SNIPPET_BEGIN: handle_one_line.-\n)(.*)(\n.-USER_SNIPPET_END: handle_one_line.*)",
      handle_block = "(.*USER_SNIPPET_BEGIN: handle_block.-\n)(.*)(\n.-USER_SNIPPET_END: handle_block.*)",
    }
  else
    local err_msg = "xdo.nvim: unknown input type"
    vim.notify(err_msg, vim.log.levels.ERROR)
    return nil
  end

  local pattern = target_pattern[user_input.target]
  local content = string.gsub(tpl.content, pattern, function(head, _, tail)
    return head .. user_input.content .. tail
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

function U.exec_filter(envs, provider, line_range, call_target)
  local src_path = U.stub_path(provider)
  local cmd = provider.filter_cmd(src_path, call_target)

  return vim.api.nvim_cmd({
    cmd = "!",
    args = { envs, unpack(cmd) },
    addr = "line",
    range = line_range,
    mods = {
      keepjumps = true,
      keepmarks = true,
    },
  }, {})
end

return U
