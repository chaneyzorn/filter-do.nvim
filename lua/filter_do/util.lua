---@module "filter_do.util"

local U = {}

function U.msg_info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

function U.msg_warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

function U.msg_err(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

function U.env_kv_str(env)
  local res = {}
  for k, v in pairs(env) do
    table.insert(res, string.format("%s=%s", k, v))
  end
  table.sort(res)
  return table.concat(res, " ")
end

return U
