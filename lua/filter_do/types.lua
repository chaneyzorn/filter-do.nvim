---@meta

--- A collection of types to be included / used in other Lua files.
---@module 'filter_do.types'

---@alias filter_do.FxCmdName
---| '"Fx"'
---| '"Fxv"'

---@alias filter_do.EnvKv {[string]:string}

---@class filter_do.BufRange
---@field bufnr integer
---@field v_char_wised boolean
---@field undotree_seq integer
---@field start_row integer 1-based index
---@field end_row integer 1-based index
---@field start_col integer 1-based index
---@field end_col integer 1-based index, vim.v.maxcol for EOL

---@class filter_do.CodeSnipSpec
---@field type
---| "code_snip" # value: string (the code snippet string)
---| "use_last_code" # value: nil (use the last used code snippet)
---| "exist_path" # value: string (the path to the code snippet file)
---| "dynamic_func" # value: fun():string (a function that return filter source file path)
---@field value nil | string | fun(filter_do.filter.Filter):(path:string,keep:boolean)

---@class filter_do.FxCtx
---@field buf_range filter_do.BufRange
---@field tpl_name string
---@field code_snip_spec filter_do.CodeSnipSpec
---@field edit_scratch boolean
---@field env filter_do.EnvKv

---@class filter_do.executors.ExecutorCtx
---@field fx_ctx filter_do.FxCtx a copy of the original FxCtx, should be readonly
---@field env filter_do.EnvKv contains envs from fx_ctx.env, can be modified
---@field stub_path string
---@field user_data table

---@class filter_do.executors.ExecutorInfo
---@field pre_action fun(ctx:filter_do.executors.ExecutorCtx):filter_do.executors.ExecutorCtx|nil
---@field filter_cmd fun(ctx:filter_do.executors.ExecutorCtx):string[]|nil

---@class filter_do.Config
---@field snippet_record_num integer
---@field show_tpl_as_record boolean
---@field executors table<string, filter_do.executors.ExecutorInfo>
---@field tpl_exec table<string, string|filter_do.executors.ExecutorInfo>
---@field get_executor? fun(tpl_name:string):nil|string|filter_do.executors.ExecutorInfo
---@field winborder 'none'|'single'|'double'|'rounded'|'solid'|'shadow'|string[]
---@field action_keymaps table<string,string>

---@class (partial) filter_do.UserConfig: filter_do.Config

---@class (partial) filter_do.FxCtxOpts: filter_do.FxCtx

---@class filter_do.api.FxCtxGetter
---@field get_buf_range fun():filter_do.BufRange
---@field select_tpl fun():string | nil
---@field get_code_snip_spec fun(tpl_name:string):filter_do.CodeSnipSpec | nil
---@field edit_before_apply fun():boolean
---@field get_env fun(buf_range:filter_do.BufRange):filter_do.EnvKv
---@field opts filter_do.FxCtxOpts

---@class filter_do.SnippetHistoryRecord
---@field tpl_name string
---@field path string
---@field filename string
---@field sha256sum string
---@field timestamp integer

---@class filter_do.UIEventData
---@field state filter_do.UICtxState
---@field target_win_id? integer
---@field scratch_win_id? integer
---@field scratch_buf_id? integer
---@field preview_buf_id? integer
