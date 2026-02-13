---@type filter_do.ExecutorInfo
return {
  pre_action = function(ctx)
    return ctx
  end,
  filter_cmd = function(ctx)
    local node = vim.g.node_host_prog or vim.fn.exepath("node")
    if node == "" or node == nil then
      local err_msg = "filter_do.nvim: node interpreter not found, please set g:node_host_prog"
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    end
    return { node, ctx.stub_path }
  end,
}
