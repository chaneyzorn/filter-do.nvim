---@module 'filter_do.config'

---@type filter_do.UserConfig
local defaults = {
  filter_records_num = 10,
  executors = {},
  tpl_exec = {},
  get_executor = nil,
}

local config = vim.deepcopy(defaults)

local M = {}

---@param user_config filter_do.UserConfig
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})

  local E = require("filter_do.executors")
  E.setup_executors(config.executors or {})
  E.setup_tpl_exec(config.tpl_exec or {})

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("filter_do.cleanup", { clear = true }),
    callback = function()
      local keep_num = config.filter_records_num or 10
      require("filter_do.filter").clean_all_stubs_and_records(keep_num)
    end,
  })
end

---@return filter_do.UserConfig
function M.get()
  return config
end

return M
