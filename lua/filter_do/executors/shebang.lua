---@type filter_do.ExecutorInfo
return {
  pre_action = function(ctx)
    local res = vim.system({ "chmod", "+x", ctx.stub_path }):wait()
    if res.code ~= 0 then
      local err_msg = string.format("filter_do.nvim: failed to chmod +x to %s, err: %s", ctx.stub_path, res.stderr)
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    else
      return ctx
    end
  end,
  filter_cmd = function(ctx)
    return { ctx.stub_path }
  end,
}
