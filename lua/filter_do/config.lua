---@module 'filter_do.config'

---@type filter_do.Config
local defaults = {
  snippet_record_num = 10,
  show_tpl_as_record = true,
  executors = {},
  tpl_exec = {},
  get_executor = nil,
  action_keymaps = {
    apply = "<LocalLeader>a",
    undo = "<LocalLeader>u",
    preview = "<LocalLeader>p",
    history = "<LocalLeader>h",
    back = "<LocalLeader>b",
    close = "<LocalLeader>c",
  },
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
      local keep_num = config.snippet_record_num or 10
      require("filter_do.filter").clean_all_stubs_and_records(keep_num)
    end,
  })
end

---@return filter_do.Config
function M.get()
  return config
end

---@return filter_do.Config
function M.get_defaults()
  return defaults
end

---@return boolean
function M.has_customized_keymaps()
  local d = M.get_defaults()
  local c = M.get()
  return not vim.deep_equal(d.action_keymaps, c.action_keymaps)
end

return M
