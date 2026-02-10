if not pcall(require, "snacks.picker") then
  vim.notify("filter-do.nvim: Snacks.picker is not available, fallback to defaults.", vim.log.levels.WARN)
  return {
    ui_select = vim.ui.select,
  }
end

local F = require("filter_do.filter")
local U = require("filter_do.utils")

local M = {}

---@class _snacks.uiSelectOpts: snacks.picker.ui_select.Opts
---@field prompt string|nil
---@field kind string|nil

---@generic T
---@param items T[] Arbitrary items
---@param opts? _snacks.uiSelectOpts
---@param on_choice fun(item?: T, idx?: number)
function M.ui_select(items, opts, on_choice)
  opts = vim.tbl_extend("force", {
    prompt = "Select one of:",
    format_item = tostring,
  }, opts or {})

  ---@type snacks.picker.Config
  local picker_config = {
    source = "filter-do",
    finder = function()
      local res = {}
      for _, item in ipairs(items) do
        local preview_title = U.short_path(item.path, 3)
        if item.timestamp then
          ---@cast item filter_do.SnippetHistoryRecord
          preview_title = F.snippet_record_display_fields(item).name
        end
        table.insert(res, {
          text = opts.format_item(item),
          file = item.path,
          preview_title = preview_title,
          item = item, -- returned by snacks.picker.select on_choice
        })
      end
      return res
    end,
    format = function(entry, picker)
      local item = entry.item
      if item.timestamp and item.sha256sum then
        ---@cast item filter_do.SnippetHistoryRecord
        local display = F.snippet_record_display_fields(item)
        ---@type snacks.picker.Highlight[]
        return {
          { display.time_str, "SnacksPickerTime" },
          { " " },
          { display.checksum, "SnacksPickerIdx" },
          { " " },
          unpack(Snacks.picker.format.file({ file = display.name }, picker)),
        }
      else
        return Snacks.picker.format.file(entry, picker)
      end
    end,
    formatters = {
      file = {
        truncate = "left",
        git_status_hl = false,
      },
    },
    ---@param ctx snacks.picker.preview.ctx
    preview = function(ctx)
      Snacks.picker.preview.file(ctx)
      U.config_win_fold(ctx.win)
    end,
    layout = require("snacks.picker.config.layouts").default,
  }

  opts.snacks = picker_config
  require("snacks.picker").select(items, opts, on_choice)
end

return M
