---@type xdo.ProviderInfo
local M = {
  name = "py",
  filter_cmd = function(src_path)
    local py3 = vim.g.python3_host_prog or vim.fn.exepath("python3")
    return { py3, src_path }
  end,
}

return M
