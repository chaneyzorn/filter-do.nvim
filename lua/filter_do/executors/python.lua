---@type filter_do.executors.ExecutorInfo
return {
  pre_action = function(ctx)
    return ctx
  end,
  filter_cmd = function(ctx)
    local py3 = vim.g.python3_host_prog or vim.fn.exepath("python3")
    if py3 == "" or py3 == nil then
      local err_msg = "filter_do.nvim: python3 interpreter not found, please set g:python3_host_prog"
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    end
    return { py3, ctx.src_path }
  end,
}
