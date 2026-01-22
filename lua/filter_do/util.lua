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


---@param sub_path string|nil
---@return string
function U.ensure_cache_path(sub_path)
  local cache_path = vim.fn.stdpath("cache")
  local target_path = vim.fs.joinpath(cache_path, "filter_do.nvim")
  if sub_path then
    target_path = vim.fs.joinpath(target_path, sub_path)
  end
  if not vim.uv.fs_stat(target_path) then
    vim.fn.mkdir(target_path, "p")
  end
  return target_path
end

return U
