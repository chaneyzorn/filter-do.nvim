---@module "filter_do.executors"

---@type table<string, filter_do.ExecutorInfo>
local executors = {
  python = require("filter_do.executors.python"),
  nodejs = require("filter_do.executors.nodejs"),
  shebang = require("filter_do.executors.shebang"),
}

---@type table<string, filter_do.ExecutorInfo>
local tpl_exec = {
  ["line.py"] = executors.python,
  ["text.py"] = executors.python,
  ["line.js"] = executors.nodejs,
  ["text.js"] = executors.nodejs,
}

local E = {}

---@param custom_executors table<string, filter_do.ExecutorInfo>
function E.setup_executors(custom_executors)
  for name, executor in pairs(custom_executors) do
    executors[name] = executor
  end
end

---@param custom_tpl_exec table<string, filter_do.ExecutorInfo|string>
function E.setup_tpl_exec(custom_tpl_exec)
  for tpl_name, executor in pairs(custom_tpl_exec) do
    if type(executor) == "string" then
      executor = executors[executor]
      if not executor then
        local err_msg = string.format("filter_do.nvim: executor %s not found for tpl %s", executor, tpl_name)
        vim.notify(err_msg, vim.log.levels.ERROR)
      end
    end
    tpl_exec[tpl_name] = executor
  end
end

---@param tpl_name string
---@return filter_do.ExecutorInfo
function E.get_executor(tpl_name)
  local cfg = require("filter_do.config").get()
  if cfg.get_executor then
    local executor = cfg.get_executor(tpl_name)
    if executor then
      if type(executor) == "string" then
        return executors[executor] or executors.shebang
      elseif type(executor) == "table" then
        return executor
      end
    end
  end
  return tpl_exec[tpl_name] or executors.shebang
end

return E
