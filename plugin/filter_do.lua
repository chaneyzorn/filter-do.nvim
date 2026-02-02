local fx_cmd_t = {
  Fx = "Execute filter on the buffer text line-wised",
  Fxv = "Execute filter on the buffer text char-wised",
}

for cmd_name, desc in pairs(fx_cmd_t) do
  vim.api.nvim_create_user_command(cmd_name, function(cmd)
    require("filter_do.cmd").fx_cmd(cmd)
  end, {
    desc = desc,
    -- :h command-attributes
    bar = false,
    bang = false,
    nargs = "+",
    range = "%", -- default range is whole buffer
    complete = function(_, cmdline, _)
      -- args: arg_lead:string, cmdline:string, curpos:number
      -- print(string.format("arg_lead=%s cmdline=%s curpos=%s", arg_lead, cmdline, curpos))
      local part1 = { "log" }
      local filters = require("filter_do.api").list_filters()
      for _, filter in ipairs(filters) do
        table.insert(part1, filter.tpl_name)
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
