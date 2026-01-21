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

---@class filter_do.executors.ExecutorCtx
---@field fx_ctx filter_do.FxCtx a copy of the original FxCtx, should be readonly
---@field env filter_do.EnvKv contains envs from fx_ctx.env, can be modified
---@field src_path string
---@field user_data any

---@class filter_do.executors.ExecutorInfo
---@field pre_action fun(ctx:filter_do.executors.ExecutorCtx):filter_do.executors.ExecutorCtx|nil
---@field filter_cmd fun(ctx:filter_do.executors.ExecutorCtx):string[]|nil

---@class filter_do.UserConfig
---@field executors? table<string, filter_do.executors.ExecutorInfo>
---@field tpl_exec? table<string, string|filter_do.executors.ExecutorInfo>
