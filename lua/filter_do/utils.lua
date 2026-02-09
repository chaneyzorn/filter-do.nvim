---@module "filter_do.utils"

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
  local undotree_seq = vim.fn.undotree(bufnr).seq_cur

  ---@type filter_do.BufRange
  local buf_range = {
    bufnr = bufnr,
    v_char_wised = false,
    undotree_seq = undotree_seq,
    start_row = 1,
    end_row = vim.api.nvim_buf_line_count(bufnr),
    start_col = 1,
    end_col = vim.v.maxcol,
  }
  if mode:match("^v") then
    local _, lnum1, col1 = unpack(vim.fn.getpos("'<"))
    local _, lnum2, col2 = unpack(vim.fn.getpos("'>"))
    buf_range = {
      bufnr = bufnr,
      v_char_wised = true,
      undotree_seq = undotree_seq,
      start_row = lnum1,
      end_row = lnum2,
      start_col = col1,
      end_col = col2,
    }
  end
  if mode:match("^V") then
    local _, lnum1, _ = unpack(vim.fn.getpos("'<"))
    local _, lnum2, _ = unpack(vim.fn.getpos("'>"))
    buf_range = {
      bufnr = bufnr,
      v_char_wised = false,
      undotree_seq = undotree_seq,
      start_row = lnum1,
      end_row = lnum2,
      start_col = 1,
      end_col = vim.v.maxcol,
    }
  end

  return buf_range
end

---@param buf_range filter_do.BufRange
---@return filter_do.EnvKv
function U.default_env_from_buf_range(buf_range)
  local env = {
    START_ROW = string.format("%s", buf_range.start_row),
    END_ROW = string.format("%s", buf_range.end_row),
    FX_LOG = U.get_log_path(),
  }
  return env
end

---@param sub_path string|nil
---@return string
function U.ensure_cache_path(sub_path)
  local cache_path = vim.fn.stdpath("cache")
  local target_path = vim.fs.joinpath(cache_path, "filter-do.nvim")
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
  local log_path = vim.fs.joinpath(tmp_path, "filter-do.log")
  return log_path
end

---@param path string
---@return string|nil
function U.file_sha256(path)
  if not vim.uv.fs_stat(path) then
    local msg = string.format("filter-do.nvim: file %s not exists during sha256", path)
    U.msg_err(msg)
    return nil
  end

  local file, err = io.open(path, "rb")
  if not file then
    local msg = string.format("filter-do.nvim: failed to open %s during sha256, %s", path, err)
    U.msg_err(msg)
    return nil
  end

  local content = file:read("*a") or ""
  file:close()

  local hash = vim.fn.sha256(content)
  return hash
end

local _seq = 0

---@param suffix string
---@return string
function U.time_seq(suffix)
  _seq = _seq + 1
  local timestamp = os.time()
  return string.format("%s.%s.%s", timestamp, _seq, suffix)
end

---@param pattern string
---@param data? table
function U.trigger_user_cmd(pattern, data)
  data = data or {}
  vim.api.nvim_exec_autocmds("User", { pattern = "Fx" .. pattern, data = data })
end

---@param win_id integer
---@param fn fun():any
function U.with_winfixbuf_disabled(win_id, fn)
  if not vim.api.nvim_win_is_valid(win_id) then
    fn()
  end

  local winfuxbuf = vim.api.nvim_get_option_value("winfixbuf", { win = win_id })
  vim.api.nvim_set_option_value("winfixbuf", false, { scope = "local", win = win_id })
  local res = fn()
  vim.api.nvim_set_option_value("winfixbuf", winfuxbuf, { scope = "local", win = win_id })
  return res
end

function U.simplify_key_tips(key)
  key = string.gsub(key, "<([Ll][Oo][Cc][Aa][Ll][Ll][Ee][Aa][Dd][Ee][Rr])>", "<LL>")
  key = string.gsub(key, "<([Ll][Ee][Aa][Dd][Ee][Rr])>", "<L>")
  return key
end

return U
