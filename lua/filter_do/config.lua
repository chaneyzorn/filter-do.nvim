---@module 'filter_do.config'

local U = require("filter_do.utils")

---@type filter_do.Config
local defaults = {
  snippet_record_num = 10,
  executors = {},
  tpl_exec = {},
  get_executor = nil,
  default_envs = nil,
  ui = {
    ui_select = "auto",
    show_tpl_as_record = true,
    winborder = "rounded",
    listchars = nil,
    action_keymaps = {
      apply = "<LocalLeader>a",
      undo = "<LocalLeader>u",
      preview = "<LocalLeader>p",
      history = "<LocalLeader>h",
      back = "<LocalLeader>b",
      close = "<LocalLeader>c",
      previous = "<LocalLeader>[",
      next = "<LocalLeader>]",
    },
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
end

local ui_select_fn = nil
local ui_select_fn_map = {
  ["default"] = function()
    return vim.ui.select
  end,
  ["snacks.picker"] = function()
    return require("filter_do.integration.snacks_picker").ui_select
  end,
  ["telescope"] = function()
    return require("filter_do.integration.telescope").ui_select
  end,
  ["mini.pick"] = function()
    return require("filter_do.integration.mini_pick").ui_select
  end,
  ["auto"] = function()
    if pcall(require, "snacks.picker") then
      return require("filter_do.integration.snacks_picker").ui_select
    elseif pcall(require, "telescope") then
      return require("filter_do.integration.telescope").ui_select
    elseif pcall(require, "mini.pick") then
      return require("filter_do.integration.mini_pick").ui_select
    else
      return vim.ui.select
    end
  end,
}

---@return filter_do.UISelectFn
function M.get_ui_select_fn()
  if ui_select_fn then
    return ui_select_fn
  end

  if type(config.ui.ui_select) == "function" then
    local config_ui_select_fn = config.ui.ui_select
    ---@cast config_ui_select_fn filter_do.UISelectFn
    ui_select_fn = config_ui_select_fn
    return ui_select_fn
  end

  local get_fn = ui_select_fn_map[config.ui.ui_select]
  if not get_fn then
    local msg = string.format("filter-do.nvim: Unknown option `%s` for `ui.ui_select`", config.ui.ui_select)
    U.msg_warn(msg)
  end
  ui_select_fn = get_fn()
  return ui_select_fn or vim.ui.select
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
  return not vim.deep_equal(d.ui.action_keymaps, c.ui.action_keymaps)
end

return M
