---@module "filter_do.ui"

local F = require("filter_do.filter")
local U = require("filter_do.utils")
local C = require("filter_do.config")
local Cfg = C.get()

---@param action string
---@param ck boolean
---@return string
local function key_tips(action, ck)
  if ck then
    local keymap = Cfg.ui.action_keymaps[action:lower()] or ""
    keymap = U.simplify_key_tips(keymap)
    return string.format(" %s(%s) ", action, keymap)
  else
    local first_char = action:sub(1, 1):upper()
    local rest_chars = action:sub(2)
    return string.format(" [%s]%s ", first_char, rest_chars)
  end
end

---@class filter_do.UIOpts
---@field scratch_per_ctx?
---| "true" use isolated scratch file for each context
---| "false" share the same scratch file for all contexts
---| "auto" default, share the same scratch file if all contexts have the same `tpl_name` and `code_snip_spec`, otherwise use isolated scratch files

---@class filter_do.UICtxState
---@field ctx filter_do.FxCtx
---@field filter filter_do.filter.Filter
---@field stub_path string
---@field target_applied boolean

---@class filter_do.UI
---@field private _opts filter_do.UIOpts
---@field private _states filter_do.UICtxState[]
---@field private _sindex integer
---@field private _state filter_do.UICtxState
---@field private _pwin integer
---@field private _target_win_id integer
---@field private _scratch_win_id integer
---@field private _scratch_buf_id integer
---@field private _preview_buf_id integer
---@field private _backdrop_win integer
---@field private _backdrop_buf integer
local M = {}
M.__index = M

---@param ctxs filter_do.FxCtx[]
---@param opts filter_do.UIOpts|nil
function M.new(ctxs, opts)
  local self = setmetatable({}, M)

  -- fill opts with defaults
  self._opts = vim.tbl_deep_extend("force", {
    scratch_per_ctx = "auto",
  }, opts or {})

  self._sindex = 1
  self._states = self:_init_states(ctxs)
  self._state = self._states[self._sindex]
  return self
end

---@param ctxs filter_do.FxCtx[]
---@return filter_do.UICtxState[]
function M:_init_states(ctxs)
  local can_share_scratch = self._opts.scratch_per_ctx ~= "true"
  if can_share_scratch then
    for i = 2, #ctxs do
      if ctxs[i].tpl_name ~= ctxs[1].tpl_name then
        can_share_scratch = false
        break
      end
      if vim.deep_equal(ctxs[i].code_snip_spec, ctxs[1].code_snip_spec) == false then
        can_share_scratch = false
        break
      end
    end
  end
  if can_share_scratch == false and self._opts.scratch_per_ctx == "false" then
    local msg = "filter-do.nvim: Sharing a scratch file across different templates is not supported"
    U.msg_warn(msg)
  end

  ---@type filter_do.UICtxState[]
  local states = {}
  local filters = F.list_filters()
  for _, ctx in ipairs(ctxs) do
    local filter = filters[ctx.tpl_name]
    if not filter then
      local err_msg = string.format("filter_do.nvim: filter not found for %s", ctx.tpl_name)
      U.msg_err(err_msg)
    else
      local state = {
        ctx = ctx,
        filter = filter,
        stub_path = nil,
        target_applied = false,
      }
      table.insert(states, state)
    end
  end

  if can_share_scratch then
    local ctx = states[1].ctx
    local filter = states[1].filter
    local stub_path = filter:gen_stub_by_spec(ctx.code_snip_spec)
    if not stub_path then
      local err_msg = string.format("filter_do.nvim: failed to generate stub file for %s", ctx.tpl_name)
      U.msg_err(err_msg)
      return {}
    end
    local shared_obj = { stub_path = stub_path }
    local mt = {
      __index = function(t, k)
        if k == "stub_path" then
          return shared_obj.stub_path
        else
          return rawget(t, k)
        end
      end,
      __newindex = function(t, k, v)
        if k == "stub_path" then
          shared_obj.stub_path = v
        else
          rawset(t, k, v)
        end
      end,
    }
    for _, state in ipairs(states) do
      setmetatable(state, mt)
    end
    return states
  end

  ---@type filter_do.UICtxState[]
  local res = {}
  for _, state in ipairs(states) do
    local ctx = state.ctx
    local stub_path = state.filter:gen_stub_by_spec(ctx.code_snip_spec)
    if not stub_path then
      local err_msg = string.format("filter_do.nvim: failed to generate stub file for %s", ctx.tpl_name)
      U.msg_err(err_msg)
    else
      state.stub_path = stub_path
      table.insert(res, state)
    end
  end
  return res
end

function M:_gen_buf_range_footer()
  if self._state.target_applied then
    return {
      { " " },
      { " Target Applied ", "Visual" },
      { " " },
    }
  end

  local buf_range = self._state.ctx.buf_range
  if buf_range.charwise_visual then
    return {
      { " " },
      { " Visual-Range ", "Visual" },
      { " " },
      { string.format(" start_pos: (%s, %s) ", buf_range.start_row, buf_range.start_col), "CursorLine" },
      { " " },
      { string.format(" end_pos: (%s, %s) ", buf_range.end_row, buf_range.end_col), "CursorLine" },
      { " " },
    }
  end

  return {
    { " " },
    { " Line-Range ", "Visual" },
    { " " },
    { string.format(" start_row: %s ", buf_range.start_row), "CursorLine" },
    { " " },
    { string.format(" end_row: %s ", buf_range.end_row), "CursorLine" },
    { " " },
  }
end

function M:_gen_scratch_footer()
  local footer = {}
  local ck = C.has_customized_keymaps()
  if not ck then
    vim.list_extend(footer, {
      { " " },
      { " <LocalLeader>+ ", "Visual" },
    })
  end

  if self._state.target_applied then
    vim.list_extend(footer, {
      { " " },
      { key_tips("Undo", ck), "CursorLine" },
      { " " },
      { key_tips("History", ck), "CursorLine" },
      { " " },
      { key_tips("Close", ck), "CursorLine" },
      { " " },
    })
  else
    vim.list_extend(footer, {
      { " " },
      { key_tips("Apply", ck), "CursorLine" },
      { " " },
      { key_tips("Preview", ck), "CursorLine" },
      { " " },
      { key_tips("History", ck), "CursorLine" },
      { " " },
      { key_tips("Close", ck), "CursorLine" },
      { " " },
    })
  end
  return footer
end

function M:_gen_preview_footer()
  local footer = {}
  local ck = C.has_customized_keymaps()
  if not ck then
    vim.list_extend(footer, {
      { " " },
      { " <LocalLeader>+ ", "Visual" },
    })
  end
  vim.list_extend(footer, {
    { " " },
    { key_tips("Apply", ck), "CursorLine" },
    { " " },
    { key_tips("Back", ck), "CursorLine" },
    { " " },
    { key_tips("Close", ck), "CursorLine" },
    { " " },
  })
  return footer
end

function M:_gen_target_title()
  local current_index = self._sindex
  local total_num = #self._states
  local buf_name = U.buf_short_name(self._state.ctx.buf_range.bufnr)
  if total_num > 1 then
    local title = string.format("<-- Target(%s/%s): %s -->", current_index, total_num, buf_name)
    local key_previous = string.format(" %s ", U.simplify_key_tips(Cfg.ui.action_keymaps.previous))
    local key_next = string.format(" %s ", U.simplify_key_tips(Cfg.ui.action_keymaps.next))
    return {
      { " " },
      { key_previous, "CursorLine" },
      { " " },
      { title, "Title" },
      { " " },
      { key_next, "CursorLine" },
      { " " },
    }
  else
    local title = string.format("Target: %s", buf_name)
    return {
      { " " },
      { title, "Title" },
      { " " },
    }
  end
end

function M:_gen_scratch_title()
  return {
    { " " },
    { string.format("filter-do: %s", self._state.ctx.tpl_name), "Title" },
    { " " },
  }
end

function M:_gen_preview_title()
  return {
    { " " },
    {
      string.format(
        "Preview: %s (filter-do: %s)",
        U.buf_short_name(self._state.ctx.buf_range.bufnr),
        self._state.ctx.tpl_name
      ),
      "Title",
    },
    { " " },
  }
end

---@return filter_do.UIEventData
function M:_event_data()
  return {
    state = self._state,
    target_win_id = self._target_win_id,
    scratch_win_id = self._scratch_win_id,
    scratch_buf_id = self._scratch_buf_id,
    preview_buf_id = self._preview_buf_id,
  }
end

---@return {height: integer, width: integer, row: integer, col: integer}
function M:win_size_and_location()
  local win_height = math.floor(vim.o.lines * 0.8)
  local win_width = math.floor((vim.o.columns * 0.9) * 0.5) - 1
  local win_row = math.floor(vim.o.lines * 0.1) - 1
  local win_col = math.floor(vim.o.columns * 0.05)
  if vim.o.columns < 240 then
    win_width = math.floor(vim.o.columns * 0.5) - 2
    win_col = 0
  end
  if vim.o.lines < 50 then
    -- excluding title + footer + statusline + cmdheight
    win_height = vim.o.lines - 2 - 1 - vim.o.cmdheight
    win_row = 0
  end
  return {
    height = win_height,
    width = win_width,
    row = win_row,
    col = win_col,
  }
end

function M:_init_ui()
  self._preview_buf_id = nil
  if not self._scratch_buf_id then
    local scratch_buf_id = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(scratch_buf_id, self._state.stub_path)
    self._scratch_buf_id = scratch_buf_id
    self:_config_scratch_buf()
  end

  local config_float_win = false
  local sl = self:win_size_and_location()
  if not self._scratch_win_id then
    local scratch_win_id = vim.api.nvim_open_win(self._scratch_buf_id, true, {
      relative = "editor",
      border = Cfg.ui.winborder,
      row = sl.row,
      col = sl.col + sl.width + 2,
      width = sl.width,
      height = sl.height,
      title = self:_gen_scratch_title(),
      title_pos = "center",
      footer = self:_gen_scratch_footer(),
      footer_pos = "center",
    })
    self._scratch_win_id = scratch_win_id
    vim.api.nvim_set_option_value("winfixbuf", true, { scope = "local", win = self._scratch_win_id })
    self:_locate_user_code(true)
    config_float_win = true
  end
  if not self._target_win_id then
    local target_win_id = vim.api.nvim_open_win(self._state.ctx.buf_range.bufnr, false, {
      relative = "editor",
      border = Cfg.ui.winborder,
      row = sl.row,
      col = sl.col,
      width = sl.width,
      height = sl.height,
      title = self:_gen_target_title(),
      title_pos = "center",
      footer = self:_gen_buf_range_footer(),
      footer_pos = "center",
    })
    self._target_win_id = target_win_id
    vim.api.nvim_set_option_value("winfixbuf", true, { scope = "local", win = self._target_win_id })
    self:highlight_buf_range()
    config_float_win = true
  end
  if config_float_win then
    self:_config_float_win()
  end

  -- create backdrop, credit to lazy.nvim, Apache-2.0 license
  if not self._backdrop_buf then
    self._backdrop_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[self._backdrop_buf].buftype = "nofile"
    vim.bo[self._backdrop_buf].filetype = "fx_backdrop"
  end
  if not self._backdrop_win then
    self._backdrop_win = vim.api.nvim_open_win(self._backdrop_buf, false, {
      relative = "editor",
      border = "none",
      width = vim.o.columns,
      height = vim.o.lines,
      row = 0,
      col = 0,
      style = "minimal",
      focusable = false,
      zindex = 30,
    })
    vim.api.nvim_set_hl(0, "FxBackdrop", { bg = "#000000", default = true })
    vim.api.nvim_set_option_value("winhighlight", "Normal:FxBackdrop", { scope = "local", win = self._backdrop_win })
    vim.api.nvim_set_option_value("winblend", 45, { scope = "local", win = self._backdrop_win })
  end
end

function M:_refresh_ui()
  if self._preview_buf_id then
    return -- skip refresh during preview
  end

  -- refresh target window
  if vim.api.nvim_win_get_buf(self._target_win_id) ~= self._state.ctx.buf_range.bufnr then
    U.with_winfixbuf_disabled(self._target_win_id, function()
      vim.api.nvim_win_set_buf(self._target_win_id, self._state.ctx.buf_range.bufnr)
    end)
  end
  vim.api.nvim_win_set_config(self._target_win_id, {
    title = self:_gen_target_title(),
    footer = self:_gen_buf_range_footer(),
  })
  if self._state.target_applied then
    self:clear_buf_range_highlight()
  else
    self:highlight_buf_range()
  end

  -- refresh scratch window
  local focus_user_code = nil
  if vim.api.nvim_buf_get_name(self._scratch_buf_id) ~= self._state.stub_path then
    vim.api.nvim_buf_call(self._scratch_buf_id, function()
      vim.cmd.update()
    end)
    vim.api.nvim_buf_set_name(self._scratch_buf_id, self._state.stub_path)
    focus_user_code = function()
      self:_locate_user_code(true)
    end
  end
  if vim.api.nvim_win_get_buf(self._scratch_win_id) ~= self._scratch_buf_id then
    U.with_winfixbuf_disabled(self._scratch_win_id, function()
      vim.api.nvim_win_set_buf(self._scratch_win_id, self._scratch_buf_id)
    end)
    focus_user_code = function()
      self:_locate_user_code(false)
    end
  end
  if focus_user_code then
    focus_user_code()
  end
  vim.api.nvim_win_set_config(self._scratch_win_id, {
    title = self:_gen_scratch_title(),
    footer = self:_gen_scratch_footer(),
  })
end

function M:open_ui()
  if not self._state then
    local err_msg = "filter-do.nvim: no valid context to open UI"
    U.msg_err(err_msg)
    return
  end

  U.trigger_user_cmd("OpenPre", self:_event_data())

  -- record current window before creating floating windows
  self._pwin = vim.api.nvim_get_current_win()
  -- switch to scratch_win_id
  self:_init_ui()

  U.trigger_user_cmd("OpenPost", self:_event_data())
end

---@param move_cursor boolean
function M:_locate_user_code(move_cursor)
  if move_cursor then
    vim.api.nvim_win_call(self._scratch_win_id, function()
      vim.cmd.edit()
      vim.api.nvim_set_option_value("buflisted", false, { scope = "local", buf = self._scratch_buf_id })
      vim.cmd("normal! gg0")
      if vim.fn.search("USER_CODE") == 0 then
        if vim.fn.search("user-code-ended") ~= 0 then
          vim.cmd("normal! {{}k")
        end
      end
      vim.cmd("normal! ^")
    end)
  end

  vim.api.nvim_set_option_value("foldmethod", "marker", { scope = "local", win = self._scratch_win_id })
  vim.api.nvim_set_option_value("foldlevel", 0, { scope = "local", win = self._scratch_win_id })
end

function M:highlight_buf_range()
  local buf_range = self._state.ctx.buf_range
  vim.api.nvim_win_set_cursor(self._target_win_id, { buf_range.start_row, buf_range.start_col })
  vim.api.nvim_win_call(self._target_win_id, function()
    vim.cmd("normal! zt")
  end)

  local ns_name = "filter_do.buf_range_hl"
  local ns_id = vim.api.nvim_create_namespace(ns_name)
  vim.api.nvim_buf_clear_namespace(buf_range.bufnr, ns_id, 0, -1)
  vim.hl.range(
    buf_range.bufnr,
    ns_id,
    "Visual",
    { buf_range.start_row - 1, buf_range.start_col - 1 },
    { buf_range.end_row - 1, buf_range.end_col - 1 },
    {
      regtype = buf_range.charwise_visual and "v" or "V",
      inclusive = true,
      priority = 1000,
    }
  )
end

---@param buf_range filter_do.BufRange|nil
function M:clear_buf_range_highlight(buf_range)
  buf_range = buf_range or self._state.ctx.buf_range
  local ns_name = "filter_do.buf_range_hl"
  local ns_id = vim.api.nvim_create_namespace(ns_name)
  vim.api.nvim_buf_clear_namespace(buf_range.bufnr, ns_id, 0, -1)
end

function M:action_apply()
  U.trigger_user_cmd("ApplyPre", self:_event_data())

  if self._state.target_applied then
    U.msg_warn("filter-do.nvim: Undo previous apply before applying again")
    return
  end

  -- check if target buffer has been modified
  local seq_cur = vim.fn.undotree(self._state.ctx.buf_range.bufnr).seq_cur
  if seq_cur ~= self._state.ctx.buf_range.undotree_seq then
    U.msg_warn("filter-do.nvim: Target buffer has been modified, cannot apply filter")
    return
  end

  vim.api.nvim_buf_call(self._scratch_buf_id, function()
    vim.cmd.update()
  end)

  self._state.target_applied = true
  self._state.filter:exec_filter(self._state.ctx, self._state.stub_path)
  self:_refresh_ui()

  U.trigger_user_cmd("ApplyPost", self:_event_data())
end

function M:action_undo()
  U.trigger_user_cmd("UndoPre", self:_event_data())

  if not self._state.target_applied then
    U.msg_warn("filter-do.nvim: No apply action to undo")
    return
  end

  vim.api.nvim_buf_call(self._state.ctx.buf_range.bufnr, function()
    vim.cmd.undo({ count = self._state.ctx.buf_range.undotree_seq })
  end)
  self._state.target_applied = false
  self:_refresh_ui()

  U.trigger_user_cmd("UndoPost", self:_event_data())
end

function M:action_history()
  U.trigger_user_cmd("HistoryPre", self:_event_data())

  C.ui_select_fn(self._state.filter:list_history_records("desc", Cfg.ui.show_tpl_as_record), {
    prompt = "filter-do.nvim: Select a snippet history record",
    format_item = function(item)
      return F.format_snippet_record(item)
    end,
  }, function(record, _)
    if not record then
      return
    end
    local stub_path = self._state.filter:gen_stub_by_exist_file(record.path)
    if stub_path then
      local origin_stub = self._state.stub_path
      self._state.stub_path = stub_path
      self:_refresh_ui()
      os.remove(origin_stub)
    end

    U.trigger_user_cmd("HistoryPost", self:_event_data())
  end)
end

function M:action_close()
  U.trigger_user_cmd("ClosePre", self:_event_data())

  vim.api.nvim_buf_call(self._scratch_buf_id, function()
    vim.cmd.update()
  end)
  vim.api.nvim_win_close(self._scratch_win_id, true)

  U.trigger_user_cmd("ClosePost", self:_event_data())
end

function M:action_previous()
  U.trigger_user_cmd("PreviousPre", self:_event_data())

  -- cycle to previous state
  self._sindex = self._sindex - 1
  if self._sindex < 1 then
    self._sindex = #self._states
  end
  self._state = self._states[self._sindex]
  self:_refresh_ui()

  U.trigger_user_cmd("PreviousPost", self:_event_data())
end

function M:action_next()
  U.trigger_user_cmd("NextPre", self:_event_data())

  -- cycle to next state
  self._sindex = self._sindex + 1
  if self._sindex > #self._states then
    self._sindex = 1
  end
  self._state = self._states[self._sindex]
  self:_refresh_ui()

  U.trigger_user_cmd("NextPost", self:_event_data())
end

function M:_config_scratch_buf()
  local keymap = Cfg.ui.action_keymaps
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.apply, "", {
    desc = "filter-do: Apply filter",
    callback = function()
      self:action_apply()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.undo, "", {
    desc = "filter-do: Undo last apply",
    callback = function()
      self:action_undo()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.preview, "", {
    desc = "filter-do: Preview diff",
    callback = function()
      self:action_preview_diff()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.history, "", {
    desc = "filter-do: History snippet record",
    callback = function()
      self:action_history()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.close, "", {
    desc = "filter-do: Close window",
    callback = function()
      self:action_close()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.previous, "", {
    desc = "filter-do: Previous target",
    callback = function()
      self:action_previous()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._scratch_buf_id, "n", keymap.next, "", {
    desc = "filter-do: Next target",
    callback = function()
      self:action_next()
    end,
  })
end

function M:_config_float_win()
  local resize_augrp_name = string.format("FxResizeFloatWin_%s_%s", self._scratch_win_id, self._target_win_id)
  local resize_augrp_id = vim.api.nvim_create_augroup(resize_augrp_name, { clear = true })
  local on_resize_fn = function()
    local sl = self:win_size_and_location()
    if vim.api.nvim_win_is_valid(self._scratch_win_id) then
      vim.api.nvim_win_set_config(self._scratch_win_id, {
        relative = "editor",
        row = sl.row,
        col = sl.col + sl.width + 2,
        width = sl.width,
        height = sl.height,
      })
    end
    if vim.api.nvim_win_is_valid(self._target_win_id) then
      vim.api.nvim_win_set_config(self._target_win_id, {
        relative = "editor",
        row = sl.row,
        col = sl.col,
        width = sl.width,
        height = sl.height,
      })
    end
    if vim.api.nvim_win_is_valid(self._backdrop_win) then
      vim.api.nvim_win_set_config(self._backdrop_win, {
        width = vim.o.columns,
        height = vim.o.lines,
      })
    end
  end
  vim.api.nvim_create_autocmd("VimResized", {
    group = resize_augrp_id,
    callback = on_resize_fn,
  })

  local on_close_fn = function()
    local wins = { self._target_win_id, self._scratch_win_id, self._backdrop_win }
    local bufs = { self._scratch_buf_id, self._preview_buf_id, self._backdrop_buf }
    for _, win_id in ipairs(wins) do
      if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
      end
    end
    for _, buf_id in ipairs(bufs) do
      if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
        vim.api.nvim_buf_delete(buf_id, { force = true })
      end
    end
    for _, state in ipairs(self._states) do
      if state.stub_path and vim.uv.fs_stat(state.stub_path) then
        os.remove(state.stub_path)
        state.stub_path = nil
      end
      self:clear_buf_range_highlight(state.ctx.buf_range)
    end

    vim.api.nvim_del_augroup_by_id(resize_augrp_id)
    -- restore previous window
    if vim.api.nvim_win_is_valid(self._pwin) then
      vim.api.nvim_set_current_win(self._pwin)
    end
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self._scratch_win_id),
    callback = on_close_fn,
    once = true,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self._target_win_id),
    callback = on_close_fn,
    once = true,
  })
end

function M:action_preview_diff()
  U.trigger_user_cmd("PreviewPre", self:_event_data())

  if self._state.target_applied then
    U.msg_warn("filter-do.nvim: Undo previous apply before previewing diff")
    return
  end

  -- check if target buffer has been modified
  local buf_range = self._state.ctx.buf_range
  local seq_cur = vim.fn.undotree(buf_range.bufnr).seq_cur
  if seq_cur ~= buf_range.undotree_seq then
    U.msg_err("filter-do.nvim: Target buffer has been modified, cannot preview diff")
    return
  end

  -- create preview buffer
  local lines = vim.api.nvim_buf_get_lines(buf_range.bufnr, 0, -1, false)
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
  self._preview_buf_id = preview_buf

  vim.api.nvim_buf_call(self._scratch_buf_id, function()
    vim.cmd.update()
  end)
  -- exec filter on preview buffer
  local preview_ctx = vim.deepcopy(self._state.ctx)
  preview_ctx.buf_range.bufnr = preview_buf
  self._state.filter:exec_filter(preview_ctx, self._state.stub_path)

  U.with_winfixbuf_disabled(self._scratch_win_id, function()
    vim.api.nvim_win_set_buf(self._scratch_win_id, preview_buf)
  end)
  vim.api.nvim_win_set_config(self._scratch_win_id, {
    title = self:_gen_preview_title(),
    footer = self:_gen_preview_footer(),
  })
  self:_config_preview_buf()
  self:clear_buf_range_highlight()

  -- clear all diff related options in all wins in the current tabpage
  vim.cmd.diffoff({ bang = true })
  -- set diff in target and preview wins
  vim.api.nvim_win_call(self._target_win_id, function()
    vim.cmd.diffthis()
  end)
  vim.api.nvim_win_call(self._scratch_win_id, function()
    vim.cmd.diffthis()
  end)

  U.trigger_user_cmd("PreviewPost", self:_event_data())
end

function M:action_back()
  U.trigger_user_cmd("BackPre", self:_event_data())

  -- clear all diff related options in all wins in the current tabpage
  vim.cmd.diffoff({ bang = true })
  local preview_buf_id = self._preview_buf_id
  self._preview_buf_id = nil
  self:_refresh_ui()
  vim.api.nvim_buf_delete(preview_buf_id, { force = true })

  U.trigger_user_cmd("BackPost", self:_event_data())
end

function M:_config_preview_buf()
  local keymap = Cfg.ui.action_keymaps
  vim.api.nvim_buf_set_keymap(self._preview_buf_id, "n", keymap.apply, "", {
    desc = "filter-do: Apply filter",
    callback = function()
      self:action_back()
      self:action_apply()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._preview_buf_id, "n", keymap.back, "", {
    desc = "filter-do: Back to scratch",
    callback = function()
      self:action_back()
    end,
  })
  vim.api.nvim_buf_set_keymap(self._preview_buf_id, "n", keymap.close, "", {
    desc = "filter-do: Close window",
    callback = function()
      self:action_back()
      self:action_close()
    end,
  })
end

return M
