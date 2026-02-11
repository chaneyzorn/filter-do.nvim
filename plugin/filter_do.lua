vim.api.nvim_create_user_command("Fx", function(cmd)
  require("filter_do.cmd").fx_cmd(cmd)
end, {
  desc = "Execute filter on the buffer text",
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

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("filter_do.cleanup", { clear = true }),
  callback = function()
    local config = require("filter_do.config").get()
    local keep_num = config.snippet_record_num or 10
    require("filter_do.filter").clean_all_stubs_and_records(keep_num)
  end,
})
