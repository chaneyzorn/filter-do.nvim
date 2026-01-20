---@type filter_do.executors.ExecutorInfo
return {
  pre_action = function(ctx)
    local res = vim.system({ "chmod", "+x", ctx.src_path }):wait()
    if res.code ~= 0 then
      local err_msg = string.format("filter_do.nvim: failed to chmod +x to %s, err: %s", ctx.src_path, res.stderr)
      vim.notify(err_msg, vim.log.levels.ERROR)
      return nil
    else
      return ctx
    end
  end,
  filter_cmd = function(ctx)
    return { ctx.src_path }
  end,
}
