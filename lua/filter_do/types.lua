---@meta

--- A collection of type definitions for filter-do.nvim.
---@module 'filter_do.types'

---@alias filter_do.EnvKv {[string]:string}
--- Environment variables dictionary passed to filter scripts.

---@class filter_do.BufRange
--- Represents a range of text within a buffer.
---@field bufnr integer Buffer number where the range is located
---@field charwise_visual boolean Whether the range was selected in charwise visual mode
---@field undotree_seq integer Undo sequence number for safety checks, value of `vim.fn.undotree(bufnr).seq_cur`
---@field start_row integer Start line number (1-based index, inclusive)
---@field end_row integer End line number (1-based index, inclusive)
---@field start_col integer Start column number (1-based index, inclusive)
---@field end_col integer End column number (1-based index, inclusive). Use vim.v.maxcol for end of line

---@class filter_do.CodeSnipSpec
--- Specifies how to obtain the user code snippet for the filter.
--- The `type` field determines how the `value` field is interpreted.
---@field type
---| "code_snip" # `value` is a string containing the actual code snippet
---| "use_last_code" # `value` is nil, reuse the most recently used code snippet
---| "exist_path" # `value` is a string path to a file containing the code
---| "dynamic_func" # `value` is a function that returns the path to a code file
---@field value nil | string | fun(filter_do.filter.Filter):(path:string,keep:boolean)
--- For "dynamic_func", the function receives the filter object and returns:
---   - path: Path to the generated code file
---   - keep: Whether to preserve the temporary file after execution

---@class filter_do.FxCtx
--- Context for a single filter execution.
--- Created from user input and passed through the execution pipeline.
---@field buf_range filter_do.BufRange Range of text to be filtered
---@field tpl_name string Name of the filter template to use (e.g., "line.py")
---@field code_snip_spec filter_do.CodeSnipSpec Specification for obtaining user code
---@field edit_scratch boolean If true, open UI to edit code before applying
---@field envs filter_do.EnvKv Environment variables for the filter script

---@class filter_do.ExecutorCtx
--- Context passed to executor functions.
--- Extends FxCtx with execution-specific data.
---@field fx_ctx filter_do.FxCtx Original FxCtx (should be treated as readonly)
---@field envs filter_do.EnvKv Mutable copy of environment variables from fx_ctx.envs
---@field stub_path string Path to the generated filter script (stub) file
---@field user_data table Arbitrary data storage for executor internal use

---@class filter_do.ExecutorInfo
--- Defines how to execute a filter script for a specific language/runtime.
--- Executors transform the stub file into an executable command.
---@field pre_action? fun(ctx:filter_do.ExecutorCtx):filter_do.ExecutorCtx|nil
--- Optional setup function called before filter execution.
--- Can modify ctx.envs or return a modified context. Return nil to abort.
---@field filter_cmd fun(ctx:filter_do.ExecutorCtx):string[]|nil
--- Required function that returns the command to execute the filter.
--- Returns an array of command arguments (e.g., {"python", stub_path}).
--- Return nil to abort execution.
---@field post_action? fun(ctx:filter_do.ExecutorCtx)
--- Optional cleanup function called after filter execution, regardless of success/failure.

---@class filter_do.Config
--- Full configuration for filter-do.nvim.
--- Use filter_do.UserConfig for user overrides (partial configuration).
---@field snippet_record_num integer Number of recent code snippets per filter to keep in history
---@field executors table<string, filter_do.ExecutorInfo> Registry of available executors by name
---@field tpl_exec table<string, string|filter_do.ExecutorInfo> Mapping of template names to executors
---@field get_executor? fun(tpl_name:string):nil|string|filter_do.ExecutorInfo
--- Custom function to resolve executor for a template. Return nil to use default resolution.
---@field default_envs? fun(ctx:filter_do.FxCtx):filter_do.EnvKv
--- Function to generate default environment variables for each execution context.
---@field ui filter_do.UIConfig UI-related configuration options

---@alias filter_do.UISelectFn fun(items:any[], opts:table, on_choice:fun(item:any|nil, idx:integer|nil))
--- Custom picker function signature for template/code selection.
--- Matches vim.ui.select signature. Used for integrations with pickers like telescope.

---@class filter_do.UIConfig
--- Configuration for the interactive UI.
---@field winborder 'none'|'single'|'double'|'rounded'|'solid'|'shadow'|string[]
--- Border style for floating windows. Can be a preset or custom array.
---@field action_keymaps table<string,string> Keymap definitions for UI actions (e.g., apply, close)
---@field ui_select 'auto' | 'default' | 'telescope' | 'snacks.picker' | 'mini.pick' | filter_do.UISelectFn
--- Picker to use for template/code selection. 'auto' detects available pickers.
---@field show_tpl_as_record boolean Whether to show template files in code snippet history
---@field listchars string | nil listchars option for the target preview window. nil uses global setting.

---@class (partial) filter_do.UserConfig: filter_do.Config
--- Partial configuration provided by the user.
--- All fields are optional; unset fields use defaults.

---@class (partial) filter_do.FxCtxOpts: filter_do.FxCtx
--- Partial FxCtx used for internal context building.

---@class filter_do.api.FxCtxGetter
--- Interface for building an FxCtx interactively.
--- Used by the APIs to gather user input step by step.
---@field get_buf_range fun():filter_do.BufRange | nil Get the target buffer range (or nil on cancel)
---@field select_tpl fun():string | nil Prompt user to select a template (or nil on cancel)
---@field get_code_snip_spec fun(tpl_name:string):filter_do.CodeSnipSpec | nil Get code spec for a template (or nil on cancel)
---@field edit_before_apply fun():boolean Ask if user wants to edit code before applying
---@field get_envs fun(ctx:filter_do.FxCtx):filter_do.EnvKv Generate environment variables for the context

---@class filter_do.SnippetHistoryRecord
--- A record of a previously used code snippet.
--- Used for the code snippet history feature.
---@field tpl_name string Name of the template this snippet was used with
---@field path string Path to the saved snippet file
---@field filename string Original filename or display name of the snippet
---@field sha256sum string SHA256 hash of the snippet content for identity
---@field timestamp integer Unix timestamp of when the snippet was used
---@field is_tpl boolean Whether this record represents a template file (not user code)

---@class filter_do.UICtxState
--- Internal state for the interactive UI session.
--- Passed to UI event handlers for customization.
---@field ctx filter_do.FxCtx The execution context
---@field filter filter_do.filter.Filter The filter object managing the execution
---@field stub_path string Path to the generated filter script
---@field target_applied boolean Whether the filter has been applied to the buffer

---@class filter_do.UIEventData
--- Data passed to User autocommand events for UI lifecycle hooks.
---@field state filter_do.UICtxState Current UI session state
---@field target_win_id? integer Window ID of the target buffer (if visible)
---@field scratch_win_id? integer Window ID of the scratch/edit window
---@field scratch_buf_id? integer Buffer ID of the scratch/edit buffer
---@field preview_buf_id? integer Buffer ID of the preview window showing results
