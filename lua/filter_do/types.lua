---@meta

--- A collection of types to be included / used in other Lua files.
---@module 'filter_do.types'

---@alias filter_do.FxCmdName
---| '"Fx"'
---| '"Fxv"'

---@alias filter_do.EnvKv {[string]:string}

---@class filter_do.BufRange
---@field bufnr integer
---@field start_row integer
---@field end_row integer
---@field start_col integer
---@field end_col integer

---@class filter_do.FxCtx
---@field buf_range filter_do.BufRange
---@field tpl_name string
---@field code_snip string
---@field v_char_wised boolean
---@field edit_scratch boolean
---@field use_last_code boolean
---@field env filter_do.EnvKv
