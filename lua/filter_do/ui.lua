---@module "filter_do.ui"

local F = require("filter_do.filter")
local U = require("filter_do.util")

local M = {}
M.__index = M

function M.new()
  local self = setmetatable({}, M)
  return self
end

---@param ctx filter_do.FxCtx
function M:open_scratch_win(ctx)
  -- ensure stub file exists
  local filter = F.get_filter_by_name(ctx.tpl_name)
  if not filter then
    local err_msg = string.format("filter_do.nvim: filter not found for %s", ctx.tpl_name)
    U.msg_err(err_msg)
    return
  end
  local stub_path = filter:gen_stub_file(ctx)
  if not stub_path then
    return
  end

  self.ctx = ctx
  self.filter = filter
  self.stub_path = stub_path

  -- create buffer and load stub file to the buffer
  local scratch_buf_id = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(scratch_buf_id, stub_path)
  self.scratch_buf_id = scratch_buf_id

  -- create windows
  local win_height = math.floor(vim.o.lines * 0.8)
  local win_width = math.floor((vim.o.columns * 0.8) * 0.5)
  local filter_win_id = vim.api.nvim_open_win(scratch_buf_id, true, {
    relative = "editor",
    border = "rounded",
    row = math.floor(vim.o.lines * 0.1),
    col = math.floor(vim.o.columns * 0.1),
    width = win_width - 1,
    height = win_height,
    title = string.format(" filter-do: %s ", ctx.tpl_name),
    title_pos = "center",
    footer = {
      { " " },
      { " <LocalLeader>+ ", "Visual" },
      { " " },
      { " [A]pply ", "CursorLine" },
      { " " },
      { " [R]eset ", "CursorLine" },
      { " " },
      { " [P]review ", "CursorLine" },
      { " " },
      { " [C]lose ", "CursorLine" },
      { " " },
    },
    footer_pos = "center",
  })
  self.filter_win_id = filter_win_id

  local target_win_id = vim.api.nvim_open_win(ctx.buf_range.bufnr, false, {
    relative = "editor",
    border = "rounded",
    row = math.floor(vim.o.lines * 0.1),
    col = math.floor(vim.o.columns * 0.1) + win_width + 1,
    width = win_width - 1,
    height = win_height,
    title = string.format(" target: %s ", vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ctx.buf_range.bufnr), ":~:.")),
    title_pos = "center",
  })
  self.target_win_id = target_win_id

  self:config_scratch_buf()
  self:config_float_win()
end

function M:config_scratch_buf()
  vim.api.nvim_buf_call(self.scratch_buf_id, function()
    vim.cmd.edit()
    vim.cmd.normal("gg0")
    vim.fn.search("USER_CODE")
    vim.cmd.normal("0w")
  end)

  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", "<LocalLeader>a", "", {
    desc = "filter-do: Apply filter",
    callback = function()
      vim.api.nvim_buf_call(self.scratch_buf_id, function()
        vim.cmd.update()
      end)
      self.filter:exec_filter(self.ctx, self.stub_path)
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", "<LocalLeader>r", "", {
    desc = "filter-do: Reset scratch",
    callback = function()
      local new_ctx = vim.deepcopy(self.ctx)
      new_ctx.edit_scratch = false
      new_ctx.use_last_code = false
      new_ctx.code_snip = ""
      self.filter:gen_stub_file(new_ctx)
      vim.api.nvim_buf_call(self.scratch_buf_id, function()
        vim.cmd.edit()
        vim.cmd.normal("gg0")
        vim.fn.search("USER_CODE")
        vim.cmd.normal("0w")
      end)
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", "<LocalLeader>p", "", {
    desc = "filter-do: Preview diff",
    callback = function()
      -- TODO: support preview diff
      U.msg_warn("call filter-do preview, not implemented yet")
    end,
  })
  vim.api.nvim_buf_set_keymap(self.scratch_buf_id, "n", "<LocalLeader>c", "", {
    desc = "filter-do: Close window",
    callback = function()
      vim.api.nvim_buf_call(self.scratch_buf_id, function()
        vim.cmd.update()
      end)
      vim.api.nvim_win_close(self.filter_win_id, true)
    end,
  })
end

function M:config_float_win()
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self.filter_win_id),
    callback = function()
      if vim.api.nvim_win_is_valid(self.target_win_id) then
        vim.api.nvim_win_close(self.target_win_id, true)
      end
      if vim.api.nvim_buf_is_valid(self.scratch_buf_id) then
        vim.api.nvim_buf_delete(self.scratch_buf_id, { force = true })
      end
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self.target_win_id),
    callback = function()
      if vim.api.nvim_win_is_valid(self.filter_win_id) then
        vim.api.nvim_win_close(self.filter_win_id, true)
      end
    end,
    once = true,
  })
end

return M
