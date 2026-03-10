---@type filter_do.ExecutorInfo
return {
  filter_cmd = function(ctx)
    local lua = vim.fn.exepath("lua")
    if lua == "" or lua == nil then
      local err_msg = "filter_do.nvim: lua interpreter not found"
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    end
    return { lua, ctx.stub_path }
  end,
}
