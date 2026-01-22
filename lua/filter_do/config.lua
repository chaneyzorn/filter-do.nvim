---@module 'filter_do.config'

---@type filter_do.UserConfig
local defaults = {
  executors = {},
  tpl_exec = {},
}

local config = vim.deepcopy(defaults)

local M = {}

---@param user_config filter_do.UserConfig
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})

  local E = require("filter_do.executors")
  E.setup_executors(config.executors or {})
  E.setup_tpl_exec(config.tpl_exec or {})
end

return M
