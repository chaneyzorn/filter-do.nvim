if not pcall(require, "mini.pick") then
  vim.notify("filter-do.nvim: mini.pick is not available, fallback to defaults.", vim.log.levels.WARN)
  return {
    ui_select = vim.ui.select,
  }
end

local MP = require("mini.pick")

local U = require("filter_do.utils")
local F = require("filter_do.filter")

local M = {}

-- I have to pick following functions manually, since they are not exported.

function M.get_config(config)
  return vim.tbl_deep_extend("force", MP.config, vim.b.minipick_config or {}, config or {})
end

function M.show_with_icons(buf_id, items, query)
  return MP.default_show(buf_id, items, query, { show_icons = true })
end

---@class _mini.pick.uiSelectOpts
---@field format_item? fun(item: any):string
---@field prompt string|nil
---@field kind string|nil

---@generic T
---@param items T[] Arbitrary items
---@param opts? _mini.pick.uiSelectOpts
---@param on_choice fun(item?: T, idx?: number)
function M.ui_select(items, opts, on_choice)
  opts = vim.tbl_extend("force", {
    prompt = "Select one of:",
    format_item = tostring,
  }, opts or {})

  local was_abort = true
  local item = MP.start({
    source = {
      name = opts.prompt,
      items = function()
        local pick_items = {}
        for i, item in ipairs(items) do
          table.insert(pick_items, {
            text = opts.format_item(item),
            path = item.path,
            item = item,
            index = i,
          })
        end
        return pick_items
      end,
      show = function(buf_id, pick_items, query)
        local record_ns_id = vim.api.nvim_create_namespace("FxRecordMiniPickRanges")
        vim.api.nvim_buf_clear_namespace(buf_id, record_ns_id, 0, -1)

        local show_fn, prefix_offset = M.get_config().source.show, 0
        if not show_fn then
          show_fn, prefix_offset = M.show_with_icons, 4 + 1
        end
        local res = show_fn(buf_id, pick_items, query)

        -- highlight record fields
        for i = 1, #pick_items do
          local item = pick_items[i].item
          if item.timestamp then
            ---@cast item filter_do.SnippetHistoryRecord
            local ds = F.snippet_record_display_fields(item)
            local row = i - 1
            local offset = prefix_offset
            local start_col, end_col = offset, ds.time_str:len() + offset
            vim.api.nvim_buf_set_extmark(buf_id, record_ns_id, row, start_col, {
              hl_mode = "combine",
              priority = 150, -- lower than 200, to avoid to override match highlight
              hl_group = "Number",
              end_row = row,
              end_col = end_col,
            })
            offset = end_col + 1
            start_col, end_col = offset, ds.checksum:len() + offset
            vim.api.nvim_buf_set_extmark(buf_id, record_ns_id, row, start_col, {
              hl_mode = "combine",
              priority = 150, -- lower than 200, to avoid to override match highlight
              hl_group = "Statement",
              end_row = row,
              end_col = end_col,
            })
          end
        end

        return res
      end,
      preview = function(buf_id, item, _opts)
        local res = MP.default_preview(buf_id, item, _opts)
        local win_id = vim.fn.bufwinid(buf_id)
        if win_id ~= 1 then
          U.config_win_fold(win_id)
        end
        return res
      end,
      choose = function(item)
        was_abort = false
        on_choice(item and item.item, item and item.index)
      end,
    },
  })
  if item == nil and was_abort then
    on_choice(item and item.item, item and item.index)
  end
end

return M
