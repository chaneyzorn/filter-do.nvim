---@type filter_do.ExecutorInfo
return {
  filter_cmd = function(ctx)
    local bun = vim.fn.exepath("bun")
    if bun == "" or bun == nil then
      local err_msg = "filter_do.nvim: bun interpreter not found"
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    end
    return { bun, "run", ctx.stub_path }
  end,
}
