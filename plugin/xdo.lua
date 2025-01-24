vim.api.nvim_create_user_command("Xdo", function(cmd)
  require("xdo").call_provider(cmd)
end, {
  desc = "Xdo",
  bar = false,
  bang = true,
  nargs = "+",
  range = true,
  complete = function(arg0, cmdstr, curpos)
    -- TODO: improve complete
    local providers = require("xdo").list_provider()
    return vim.tbl_keys(providers)
  end,
})
