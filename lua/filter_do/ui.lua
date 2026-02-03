---@module "filter_do.ui"

local F = require("filter_do.filter")
local U = require("filter_do.util")
local C = require("filter_do.config")
local Cfg = C.get()

local M = {}
M.__index = M

function M.new()
  local self = setmetatable({}, M)
  return self
end

---@param ctx filter_do.FxCtx
local function gen_buf_range_footer(ctx)
  if ctx.buf_range.v_char_wised then
    local range_mode = "Visual-Range"
    local end_col = tostring(ctx.buf_range.end_col)
    if ctx.buf_range.end_col == vim.v.maxcol then
      end_col = "$"
    end
    return {
      { " " },
      { string.format(" %s ", range_mode), "Visual" },
      { " " },
      { string.format(" start_row: %s ", ctx.buf_range.start_row), "CursorLine" },
      { " " },
      { string.format(" start_col: %s ", ctx.buf_range.start_col), "CursorLine" },
      { " " },
      { string.format(" end_row: %s ", ctx.buf_range.end_row), "CursorLine" },
      { " " },
      { string.format(" end_col: %s ", end_col), "CursorLine" },
      { " " },
    }
  end

  local range_mode = "Line-Range"
  return {
    { " " },
    { string.format(" %s ", range_mode), "Visual" },
    { " " },
    { string.format(" start_row: %s ", ctx.buf_range.start_row), "CursorLine" },
    { " " },
    { string.format(" end_row: %s ", ctx.buf_range.end_row), "CursorLine" },
    { " " },
  }
end

---@param action string
---@param ck boolean
---@return string
local function key_tips(action, ck)
  if ck then
    local keymap = Cfg.action_keymaps[action:lower()]
    keymap = string.gsub(keymap, "<([Ll][Oo][Cc][Aa][Ll][Ll][Ee][Aa][Dd][Ee][Rr])>", "<LL>")
    keymap = string.gsub(keymap, "<([Ll][Ee][Aa][Dd][Ee][Rr])>", "<L>")
    return string.format(" %s(%s) ", action, keymap)
  else
    local first_char = action:sub(1, 1):upper()
    local rest_chars = action:sub(2)
    return string.format(" [%s]%s ", first_char, rest_chars)
  end
end

local function gen_scratch_footer(can_undo)
  local footer = {}
  local ck = C.has_customized_keymaps()
  if not ck then
    vim.list_extend(footer, {
      { " " },
      { " <LocalLeader>+ ", "Visual" },
    })
  end

  if can_undo then
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

local function gen_preview_footer()
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

local function gen_title(title, hi_group)
  return {
    { " " },
    { title, hi_group or "Title" },
    { " " },
  }
end

---@return filter_do.UIEventData
function M:_event_data()
  return {
    ctx = self.ctx,
    stub_path = self.stub_path,
    target_win_id = self.target_win_id,
    scratch_win_id = self.scratch_win_id,
    scratch_buf_id = self.scratch_buf_id,
    preview_buf_id = self.preview_buf_id,
  }
end

---@param ctx filter_do.FxCtx
function M:open_scratch_win(ctx)
  U.trigger_user_cmd("OpenPre", self:_event_data())

  -- ensure stub file exists
  local filter = F.get_filter_by_name(ctx.tpl_name)
  if not filter then
    local err_msg = string.format("filter_do.nvim: filter not found for %s", ctx.tpl_name)
    U.msg_err(err_msg)
    return
  end
  local stub_path = filter:gen_stub_by_spec(ctx.code_snip_spec)
  if not (stub_path and vim.uv.fs_stat(stub_path)) then
    return
  end

  self.ctx = ctx
  self.filter = filter
  self.stub_path = stub_path

  -- create buffer and load stub file to the buffer
  local scratch_buf_id = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(scratch_buf_id, stub_path)
  self.scratch_buf_id = scratch_buf_id
  self.preview_buf_id = nil

  -- record current window before creating floating windows
  self.prev_win_id = vim.api.nvim_get_current_win()

  -- create windows
  local win_height = math.floor(vim.o.lines * 0.8)
  local win_width = math.floor((vim.o.columns * 0.9) * 0.5)
  local target_win_id = vim.api.nvim_open_win(ctx.buf_range.bufnr, false, {
    relative = "editor",
    border = "rounded",
    row = math.floor(vim.o.lines * 0.1) - 1,
    col = math.floor(vim.o.columns * 0.05),
    width = win_width - 1,
    height = win_height,
    title = gen_title(string.format("Target: %s", U.buf_short_name(ctx.buf_range.bufnr))),
    title_pos = "center",
    footer = gen_buf_range_footer(ctx),
    footer_pos = "center",
  })
  self.target_win_id = target_win_id
  self.target_buf_init_undo_seq = vim.fn.undotree(ctx.buf_range.bufnr).seq_cur
  self.target_buf_undo_seq = nil

  local scratch_win_id = vim.api.nvim_open_win(scratch_buf_id, true, {
    relative = "editor",
    border = "rounded",
    row = math.floor(vim.o.lines * 0.1) - 1,
    col = math.floor(vim.o.columns * 0.05) + win_width + 1,
    width = win_width - 1,
    height = win_height,
    title = gen_title(string.format("filter-do: %s", ctx.tpl_name)),
    title_pos = "center",
    footer = gen_scratch_footer(self.target_buf_undo_seq),
    footer_pos = "center",
  })
  self.scratch_win_id = scratch_win_id

  self:config_scratch_buf()
  self:config_float_win()
  self:highlight_buf_range(ctx)

  U.trigger_user_cmd("OpenPost", self:_event_data())
end

function M:locate_user_code()
  vim.api.nvim_buf_call(self.scratch_buf_id, function()
    vim.cmd.edit()
    vim.cmd("normal! gg0")
    local rs = vim.fn.search("USER_CODE")
    if rs == 0 then
      -- Placeholder replaced by user code snippet, search next placeholder
      vim.fn.search("user code ended")
      vim.cmd("normal! {{}k")
    end
    vim.cmd("normal! ^")
  end)
end

function M:locate_target_win()
  local buf_range = self.ctx.buf_range
  vim.api.nvim_win_set_cursor(self.target_win_id, { buf_range.start_row, buf_range.start_col })
  vim.api.nvim_win_call(self.target_win_id, function()
    vim.cmd("normal! zt")
  end)
end

---@param ctx filter_do.FxCtx
function M:highlight_buf_range(ctx)
  self:locate_target_win()

  local ns_name = "filter_do.buf_range_hl"
  local ns_id = vim.api.nvim_create_namespace(ns_name)
  vim.api.nvim_buf_clear_namespace(ctx.buf_range.bufnr, ns_id, 0, -1)
  vim.hl.range(
    ctx.buf_range.bufnr,
    ns_id,
    "Visual",
    { ctx.buf_range.start_row - 1, ctx.buf_range.start_col - 1 },
    { ctx.buf_range.end_row - 1, ctx.buf_range.end_col - 1 },
    {
      regtype = ctx.buf_range.v_char_wised and "v" or "V",
      inclusive = true,
      priority = 1000,
    }
  )
end

---@param ctx filter_do.FxCtx
function M:clear_buf_range_highlight(ctx)
  local ns_name = "filter_do.buf_range_hl"
  local ns_id = vim.api.nvim_create_namespace(ns_name)
  vim.api.nvim_buf_clear_namespace(ctx.buf_range.bufnr, ns_id, 0, -1)
end

function M:action_apply()
  U.trigger_user_cmd("ApplyPre", self:_event_data())

  if self.target_buf_undo_seq ~= nil then
    U.msg_warn("filter-do.nvim: Undo previous apply before applying again")
    return
  end

  -- check if target buffer has been modified
  local seq_cur = vim.fn.undotree(self.ctx.buf_range.bufnr).seq_cur
  if seq_cur ~= self.target_buf_init_undo_seq then
    U.msg_warn("filter-do.nvim: Target buffer has been modified, cannot apply filter")
    return
  end

  vim.api.nvim_buf_call(self.scratch_buf_id, function()
    vim.cmd.update()
  end)

  self.target_buf_undo_seq = seq_cur
  self.filter:exec_filter(self.ctx, self.stub_path)
  vim.api.nvim_win_set_config(self.scratch_win_id, {
    footer = gen_scratch_footer(self.target_buf_undo_seq),
  })
  self:clear_buf_range_highlight(self.ctx)

  U.trigger_user_cmd("ApplyPost", self:_event_data())
end

function M:action_undo()
  U.trigger_user_cmd("UndoPre", self:_event_data())

  if self.target_buf_undo_seq == nil then
    U.msg_warn("filter-do.nvim: No apply action to undo")
    return
  end
  local undo_seq = self.target_buf_undo_seq
  self.target_buf_undo_seq = nil
  vim.api.nvim_buf_call(self.ctx.buf_range.bufnr, function()
    vim.cmd.undo({ count = undo_seq })
  end)
  vim.api.nvim_win_set_config(self.scratch_win_id, {
    footer = gen_scratch_footer(self.target_buf_undo_seq),
  })
  self:highlight_buf_range(self.ctx)

  U.trigger_user_cmd("UndoPost", self:_event_data())
end

function M:action_history()
  U.trigger_user_cmd("HistoryPre", self:_event_data())

  vim.ui.select(self.filter:list_history_records("desc", Cfg.show_tpl_as_record), {
    prompt = "filter-do.nvim: Select history snippet record",
    format_item = function(item)
      return F.format_snippet_record(item)
    end,
  }, function(record, _)
    if not record then
      return
    end
    local stub_path = self.filter:gen_stub_by_exist_file(record.path)
    if not stub_path then
      return
    end
    self.stub_path = stub_path
    -- update buffer content
    vim.api.nvim_buf_call(self.scratch_buf_id, function()
      vim.cmd.update()
    end)
    vim.api.nvim_buf_set_name(self.scratch_buf_id, stub_path)
    self:locate_user_code()
  end)

  U.trigger_user_cmd("HistoryPost", self:_event_data())
end

function M:action_close()
  U.trigger_user_cmd("ClosePre", self:_event_data())

  vim.api.nvim_buf_call(self.scratch_buf_id, function()
    vim.cmd.update()
  end)
  vim.api.nvim_win_close(self.scratch_win_id, true)

  U.trigger_user_cmd("ClosePost", self:_event_data())
end

function M:config_scratch_buf()
  local keymap = Cfg.action_keymaps
  self:locate_user_code()
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", keymap.apply, "", {
    desc = "filter-do: Apply filter",
    callback = function()
      self:action_apply()
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", keymap.undo, "", {
    desc = "filter-do: Undo last apply",
    callback = function()
      self:action_undo()
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", keymap.preview, "", {
    desc = "filter-do: Preview diff",
    callback = function()
      self:action_preview_diff()
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", keymap.history, "", {
    desc = "filter-do: History snippet record",
    callback = function()
      self:action_history()
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", keymap.close, "", {
    desc = "filter-do: Close window",
    callback = function()
      self:action_close()
    end,
  })
end

function M:config_float_win()
  local callback_fn = function()
    self:clear_buf_range_highlight(self.ctx)
    if vim.api.nvim_win_is_valid(self.target_win_id) then
      vim.api.nvim_win_close(self.target_win_id, true)
    end
    if vim.api.nvim_win_is_valid(self.scratch_win_id) then
      vim.api.nvim_win_close(self.scratch_win_id, true)
    end
    if vim.api.nvim_buf_is_valid(self.scratch_buf_id) then
      vim.api.nvim_buf_delete(self.scratch_buf_id, { force = true })
    end
    if self.preview_buf_id and vim.api.nvim_buf_is_valid(self.preview_buf_id) then
      vim.api.nvim_buf_delete(self.preview_buf_id, { force = true })
    end
    -- restore previous window
    if vim.api.nvim_win_is_valid(self.prev_win_id) then
      vim.api.nvim_set_current_win(self.prev_win_id)
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self.scratch_win_id),
    callback = callback_fn,
    once = true,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self.target_win_id),
    callback = callback_fn,
    once = true,
  })
  vim.api.nvim_set_option_value("foldmethod", "marker", { win = self.scratch_win_id })
  vim.api.nvim_set_option_value("foldlevel", 0, { win = self.scratch_win_id })
end

function M:action_preview_diff()
  U.trigger_user_cmd("PreviewPre", self:_event_data())

  if self.target_buf_undo_seq ~= nil then
    U.msg_warn("filter-do.nvim: Undo previous apply before previewing diff")
    return
  end

  -- check if target buffer has been modified
  local seq_cur = vim.fn.undotree(self.ctx.buf_range.bufnr).seq_cur
  if seq_cur ~= self.target_buf_init_undo_seq then
    U.msg_err("filter-do.nvim: Target buffer has been modified, cannot preview diff")
    return
  end

  vim.api.nvim_buf_call(self.scratch_buf_id, function()
    vim.cmd.update()
  end)

  local lines = vim.api.nvim_buf_get_lines(self.ctx.buf_range.bufnr, 0, -1, false)
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
  self.preview_buf_id = preview_buf

  local preview_ctx = vim.deepcopy(self.ctx)
  preview_ctx.buf_range.bufnr = preview_buf
  self.filter:exec_filter(preview_ctx, self.stub_path)

  vim.api.nvim_win_set_buf(self.scratch_win_id, preview_buf)
  vim.api.nvim_win_set_config(self.scratch_win_id, {
    title = gen_title(
      string.format("Preview: %s (filter-do: %s)", U.buf_short_name(self.ctx.buf_range.bufnr), self.ctx.tpl_name)
    ),
    footer = gen_preview_footer(),
  })
  self:config_preview_buf()
  self:clear_buf_range_highlight(self.ctx)

  -- clear all diff related options in all wins in the current tabpage
  vim.cmd.diffoff({ bang = true })
  -- set diff in target and preview wins
  vim.api.nvim_win_call(self.target_win_id, function()
    vim.cmd.diffthis()
  end)
  vim.api.nvim_win_call(self.scratch_win_id, function()
    vim.cmd.diffthis()
  end)

  U.trigger_user_cmd("PreviewPost", self:_event_data())
end

function M:action_back()
  U.trigger_user_cmd("BackPre", self:_event_data())

  -- clear all diff related options in all wins in the current tabpage
  vim.cmd.diffoff({ bang = true })
  self:highlight_buf_range(self.ctx)

  vim.api.nvim_win_set_buf(self.scratch_win_id, self.scratch_buf_id)
  vim.api.nvim_buf_delete(self.preview_buf_id, { force = true })
  self.preview_buf_id = nil

  vim.api.nvim_win_set_config(self.scratch_win_id, {
    title = gen_title(string.format("filter-do: %s", self.ctx.tpl_name)),
    footer = gen_scratch_footer(self.target_buf_undo_seq),
  })
  vim.api.nvim_set_option_value("foldmethod", "marker", { win = self.scratch_win_id })
  vim.api.nvim_set_option_value("foldlevel", 0, { win = self.scratch_win_id })

  U.trigger_user_cmd("BackPost", self:_event_data())
end

function M:config_preview_buf()
  local keymap = Cfg.action_keymaps
  vim.api.nvim_buf_set_keymap(self.preview_buf_id, "n", keymap.apply, "", {
    desc = "filter-do: Apply filter",
    callback = function()
      self:action_back()
      self:action_apply()
    end,
  })
  vim.api.nvim_buf_set_keymap(self.preview_buf_id, "n", keymap.back, "", {
    desc = "filter-do: Back to scratch",
    callback = function()
      self:action_back()
    end,
  })
  vim.api.nvim_buf_set_keymap(self.preview_buf_id, "n", keymap.close, "", {
    desc = "filter-do: Close window",
    callback = function()
      self:action_back()
      self:action_close()
    end,
  })
end

return M
