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

---@return string
function U.ensure_cache_path()
  local cache_path = vim.fn.stdpath("cache")
  local filter_do_cache_path = vim.fs.joinpath(cache_path, "filter_do.nvim")
  if not vim.uv.fs_stat(filter_do_cache_path) then
    vim.uv.fs_mkdir(filter_do_cache_path, 493) -- 0755
  end
  return filter_do_cache_path
end

return U
