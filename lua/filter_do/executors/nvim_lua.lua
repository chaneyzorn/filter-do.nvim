---@type filter_do.ExecutorInfo
return {
  filter_cmd = function(ctx)
    return { vim.v.progpath, "-l", ctx.stub_path }
  end,
}
