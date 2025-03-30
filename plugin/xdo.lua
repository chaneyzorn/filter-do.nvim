local xdo_cmd_t = {
  Xdo = "Exec code for each line in the range",
  Xdov = "Exec code for each line in the char-wised range",
  Vdo = "Exec code for the whole line-wised range",
  Vdov = "Exec code for the whole char-wised range",
}

for cmd_name, desc in pairs(xdo_cmd_t) do
  vim.api.nvim_create_user_command(cmd_name, function(cmd)
    require("xdo.cmd").dispatch_cmd(cmd)
  end, {
    desc = desc,
    bar = false,
    bang = false,
    nargs = "+",
    range = "%",
    complete = function()
      -- TODO: improve complete
      -- args: arg0, cmdstr, curpos
      local providers = require("xdo.provider").list_providers()
      return vim.tbl_keys(providers)
    end,
  })
end

vim.api.nvim_create_user_command("XdoLog", function()
  require("xdo.api").xdo_view_log()
end, { desc = "View Xdo log" })
