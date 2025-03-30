---@meta

--- A collection of types to be included / used in other Lua files.
---@module 'xdo.types'

---@alias xdo.XdoCmdName
---| '"Xdo"'
---| '"Xdov"'
---| '"Vdo"'
---| '"Vdov"'

---@alias xdo.EnvKv {[string]:string}

---@class Xdo.BufRange
---@field bufnr integer
---@field start_row integer
---@field end_row integer
---@field start_col integer
---@field end_col integer
---@field tail_len integer

---@class xdo.XdoCtx
---@field buf_range Xdo.BufRange
---@field provider string
---@field code_snip string
---@field v_block_wised boolean
---@field v_char_wised boolean
---@field edit_scratch boolean
---@field env xdo.EnvKv

---@class xdo.ProviderInfo
---@field name string
---@field filter_cmd fun(src_path:string):string[]
