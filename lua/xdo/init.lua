---@module 'xdo'

local M = {}

local providers = {}
local builtin_loaded = false

function M.register(p)
  providers[p.name] = p
end

function M.load_builtin_providers()
  if builtin_loaded then
    return providers
  end

  local current_path = debug.getinfo(1, "S").source:match("@?(.*/)")
  local current_dir = vim.fs.dirname(current_path)
  for sub, tp in vim.fs.dir(vim.fs.joinpath(current_dir, "provider")) do
    if tp == "directory" then
      local provider = require("xdo.provider." .. sub)
      M.register(provider)
    end
  end

  builtin_loaded = true
  return providers
end

function M.list_provider()
  return M.load_builtin_providers()
end

function M.call_provider(cmd)
  -- print(vim.inspect(cmd))
  M.load_builtin_providers()

  local provider_name = cmd.fargs[1]
  local provider = providers[provider_name]
  if not provider then
    local err_msg = string.format("xdo.nvim: unknown provider %s", provider_name)
    vim.notify(err_msg, vim.log.levels.ERROR)
    return
  end

  -- TODO: Don't repeat target in gen and call
  -- TODO: Determine the range carefully
  local line_range = { cmd.line1, cmd.line2 }
  local U = require("xdo.provider.util")
  local envs = U.env_kvs(U.collect_env(cmd))
  U.gen_stub_file(provider, {
    content = cmd.args:sub(#provider_name + 2),
    target = "handle_one_line",
    type = "body_code",
  })
  U.exec_filter(envs, provider, line_range, "line_do")
end

return M
