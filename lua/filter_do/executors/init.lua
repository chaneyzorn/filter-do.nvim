---@class filter_do.executors.TplCtx
---@field src_path string
---@field user_data any

---@class filter_do.executors.ExecutorInfo
---@field pre_action fun(ctx:filter_do.executors.TplCtx):filter_do.executors.TplCtx|nil
---@field filter_cmd fun(ctx:filter_do.executors.TplCtx):string[]|nil

---@type table<string, filter_do.executors.ExecutorInfo>
local executors = {
  python = require("filter_do.executors.python"),
  nodejs = require("filter_do.executors.nodejs"),
  shebang = require("filter_do.executors.shebang"),
}

---@type table<string, filter_do.executors.ExecutorInfo>
local tpl_executor_table = {
  ["line.py"] = executors.python,
  ["text.py"] = executors.python,
  ["line.js"] = executors.nodejs,
  ["text.js"] = executors.nodejs,
}

local E = {}

---@param tpl_name string
---@return filter_do.executors.ExecutorInfo
function E.get_executor(tpl_name)
  return tpl_executor_table[tpl_name] or executors.shebang
end

return E
