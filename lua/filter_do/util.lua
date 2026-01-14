---@module "filter_do.util"

local U = {}

---@param msg string
function U.msg_info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

---@param msg string
function U.msg_warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

---@param msg string
function U.msg_err(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

---@param env filter_do.EnvKv
---@return string
function U.env_kv_str(env)
  local res = {}
  for k, v in pairs(env) do
    table.insert(res, string.format("%s=%s", k, v))
  end
  table.sort(res)
  return table.concat(res, " ")
end

---@param bufnr number
---@return string
function U.buf_short_name(bufnr)
  local full_name = vim.api.nvim_buf_get_name(bufnr)
  return vim.fn.fnamemodify(full_name, ":~:.")
end

return U
