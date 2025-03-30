---@module 'xdo.config'

vim.g.loaded_xdo = false

local M = {}

function M.ensure_init()
  if vim.g.loaded_xdo then
    return
  end
  vim.g.loaded_xdo = true
end

function M.setup(user_config)
  return user_config
end

return M
