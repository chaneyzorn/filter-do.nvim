---@module 'filter_do.config'

-- TODO: support config something

vim.g.loaded_filter_do = false

local M = {}

function M.ensure_init()
  if vim.g.loaded_filter_do then
    return
  end
  vim.g.loaded_filter_do = true
end

function M.setup(user_config)
  return user_config
end

return M
