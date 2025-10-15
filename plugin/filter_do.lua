local fx_cmd_t = {
  Fx = "Execute filter on the buffer text line-wised",
  Fxv = "Execute filter on the buffer text char-wised",
}

for cmd_name, desc in pairs(fx_cmd_t) do
  vim.api.nvim_create_user_command(cmd_name, function(cmd)
    -- print(vim.inspect(cmd))
    require("filter_do.cmd").dispatch_cmd(cmd)
  end, {
    desc = desc,
    -- :h command-attributes
    bar = false,
    bang = false,
    nargs = "+",
    range = "%",
    complete = function(_, cmdline, _)
      -- args: arg_lead:string, cmdline:string, curpos:number
      -- print(string.format("arg_lead=%s cmdline=%s curpos=%s", arg_lead, cmdline, curpos))
      local part1 = {}
      local filters = require("filter_do.filter").list_filters()
      for k in pairs(filters) do
        table.insert(part1, k)
        table.insert(part1, k .. "+")
        table.insert(part1, k .. "-")
        table.insert(part1, k .. "+-")
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

vim.api.nvim_create_user_command("FxLog", function()
  require("filter_do.api").fx_view_log()
end, { desc = "View filter_do.nvim log" })
