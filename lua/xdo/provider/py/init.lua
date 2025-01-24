local M = {
  name = "py",
  filter_cmd = function(src_path, call_target)
    local py3 = vim.g.python3_host_prog or vim.fn.exepath("python3")
    return { py3, src_path, call_target }
  end,
}

return M
