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

---@param path string
---@param level integer
---@return string
function U.short_path(path, level)
  local normalized_path = vim.fs.normalize(path)
  if normalized_path == "" or normalized_path == "/" then
    return normalized_path
  end

  local target_level = math.max(1, tonumber(level) or 3)
  local result_parts = vim.ringbuf(target_level)
  for _, part in ipairs(vim.split(normalized_path, "/", { trimempty = true })) do
    result_parts:push(part)
  end

  local res = {}
  while true do
    local item = result_parts:pop()
    if item == nil then
      break
    end
    table.insert(res, item)
  end
  return table.concat(res, "/")
end

---@return filter_do.BufRange
function U.get_current_buffer_range()
  local mode = vim.fn.mode()
  local bufnr = vim.api.nvim_get_current_buf()

  if mode:match("^v") then
    local _, lnum1, col1 = unpack(vim.fn.getpos("'<"))
    local _, lnum2, col2 = unpack(vim.fn.getpos("'>"))
    return {
      bufnr = bufnr,
      start_row = lnum1,
      end_row = lnum2,
      start_col = col1,
      end_col = col2,
    }
  end

  if mode:match("^V") then
    local _, lnum1, _ = unpack(vim.fn.getpos("'<"))
    local _, lnum2, _ = unpack(vim.fn.getpos("'>"))
    return {
      bufnr = bufnr,
      start_row = lnum1,
      end_row = lnum2,
      start_col = 1,
      end_col = vim.v.maxcol,
    }
  end

  return {
    bufnr = bufnr,
    start_row = 1,
    end_row = vim.api.nvim_buf_line_count(bufnr),
    start_col = 1,
    end_col = vim.v.maxcol,
  }
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

---@return string
function U.get_log_path()
  local tmp_path = vim.fs.dirname(vim.fn.tempname())
  local log_path = vim.fs.joinpath(tmp_path, "filter_do.log")
  return log_path
end

return U
