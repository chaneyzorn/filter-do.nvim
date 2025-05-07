local xdo_cmd_t = {
  Xdo = "Exec code on each line in the range",
  Xdov = "Exec code on each line in the char-wised range",
  Vdo = "Exec code on the whole line-wised range",
  Vdov = "Exec code on the whole char-wised range",
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
    complete = function(arg_lead, cmdline, curpos)
      -- args: arg_lead, cmdline, curpos
      print(string.format("arg_lead=%s cmdline=%s curpos=%s", arg_lead, cmdline, curpos))

      local part1 = {}
      local providers = require("xdo.provider").list_providers()
      for k in pairs(providers) do
        table.insert(part1, k)
        table.insert(part1, k .. "+")
      end

      local part1_present = false
      for _, v in pairs(part1) do
        if cmdline:find(v) ~= nil then
          part1_present = true
        end
      end

      if not part1_present then
        return part1
      elseif cmdline:find("return") == nil then
        return { "return" }
      else
        return {}
      end
    end,
  })
end

vim.api.nvim_create_user_command("XdoLog", function()
  require("xdo.api").xdo_view_log()
end, { desc = "View Xdo log" })
