---@type xdo.ProviderInfo
local M = {
  name = "js",
  filter_cmd = function(src_path)
    local node = vim.g.node_host_prog or vim.fn.exepath("node")
    return { node, src_path }
  end,
}

return M
