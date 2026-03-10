---@type filter_do.ExecutorInfo
return {
  filter_cmd = function(ctx)
    local ruby = vim.fn.exepath("ruby")
    if ruby == "" or ruby == nil then
      local err_msg = "filter_do.nvim: ruby interpreter not found, please set g:ruby_host_prog"
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    end
    return { ruby, ctx.stub_path }
  end,
}
