if not pcall(require, "telescope") then
  vim.notify("filter-do.nvim: Telescope is not available, fallback to defaults.", vim.log.levels.WARN)
  return {
    ui_select = vim.ui.select,
  }
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local U = require("filter_do.utils")
local F = require("filter_do.filter")

local M = {}

function M.make_entry(opts)
  local record_displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 19 },
      { width = 10 },
      { remaining = true },
    },
  })
  local make_display = function(entry)
    local item = entry.raw
    if item.timestamp and item.sha256sum then
      ---@cast item filter_do.SnippetHistoryRecord
      local fields = F.snippet_record_display_fields(item)
      return record_displayer({
        { fields.time_str, "TelescopeResultsNumber" },
        { fields.checksum, "TelescopeResultsIdentifier" },
        { fields.name, "TelescopeResultsVariable" },
      })
    else
      ---@cast item { path: string }
      local _entry = make_entry.gen_from_file({
        path_display = function(...)
          return opts.format_item(item)
        end,
      })(item.path)
      return _entry:display()
    end
  end

  return function(item)
    return {
      raw = item,
      value = item,
      display = make_display,
      ordinal = opts.format_item(item), -- evaluting score by telescope sorter within user input prompt
      path = item.path,
      filename = item.path,
    }
  end
end

function M.create_previewer()
  return previewers.new_buffer_previewer({
    title = "File Preview",
    dyn_title = function(_, entry)
      return "Preview: " .. U.short_path(entry.path, 3)
    end,
    get_buffer_by_name = function(_, entry)
      return entry.path
    end,
    define_preview = function(self, entry)
      local path = entry.path
      conf.buffer_previewer_maker(path, self.state.bufnr, {
        bufname = self.state.bufname,
        winid = self.state.winid,
        callback = function()
          vim.schedule(function()
            vim.api.nvim_set_option_value("foldmethod", "marker", { scope = "local", win = self.state.winid })
            vim.api.nvim_set_option_value("foldlevel", 0, { scope = "local", win = self.state.winid })
            vim.api.nvim_set_option_value("number", true, { scope = "local", win = self.state.winid })
            vim.api.nvim_win_call(self.state.winid, function()
              vim.cmd("normal! zx") -- update fold
            end)
          end)
        end,
      })
    end,
  })
end

---@generic T
---@param items T[] Arbitrary items
---@param opts table Additional options
---     - prompt (string|nil)
---               Text of the prompt. Defaults to `Select one of:`
---     - format_item (function item -> text)
---               Function to format an
---               individual item from `items`. Defaults to `tostring`.
---     - kind (string|nil)
---               Arbitrary hint string indicating the item shape.
---               Plugins reimplementing `vim.ui.select` may wish to
---               use this to infer the structure or semantics of
---               `items`, or the context in which select() was called.
---@param on_choice fun(item: T|nil, idx: integer|nil)
---               Called once the user made a choice.
---               `idx` is the 1-based index of `item` within `items`.
---               `nil` if the user aborted the dialog.
function M.ui_select(items, opts, on_choice)
  opts = vim.tbl_extend("force", {
    prompt = "Select one of:",
    format_item = tostring,
  }, opts or {})

  if vim.tbl_isempty(items) then
    on_choice(nil, nil)
    return
  end

  pickers
    .new({}, {
      prompt_title = opts.prompt,
      finder = finders.new_table({
        results = items,
        entry_maker = M.make_entry(opts),
      }),
      previewer = M.create_previewer(),
      sorter = conf.generic_sorter(),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          on_choice(selection and selection.raw or nil, selection and selection.index or nil)
        end)
        return true
      end,
    })
    :find()
end

return M
