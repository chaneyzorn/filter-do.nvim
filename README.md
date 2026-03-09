# filter-do.nvim

A [`:!filter`](https://neovim.io/doc/user/change.html#filter) script manager that helps you process text in vim buffers using your favorite programming languages.

<https://github.com/user-attachments/assets/8975630b-f8d2-4b16-b0ce-23f385ad3302>

- [filter-do.nvim](#filter-donvim)
  - [TLDR](#tldr)
    - [Why?](#why)
  - [Features](#features)
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Vim Ex Commands](#vim-ex-commands)
    - [Subcommands](#subcommands)
  - [Built-in Templates](#built-in-templates)
  - [User Examples](#user-examples)
  - [API](#api)
  - [User Events](#user-events)
  - [Custom Environment Variables](#custom-environment-variables)
  - [Writing Custom Filter Templates](#writing-custom-filter-templates)
    - [Filter Template Files](#filter-template-files)
    - [Custom Interpreter Environments](#custom-interpreter-environments)
  - [Todo](#todo)
  - [Acknowledgments](#acknowledgments)

## TLDR

In vim, you can use the [`:pydo`](https://neovim.io/doc/user/if_pyth.html#%3Apydo), [`:rubydo`](https://neovim.io/doc/user/if_ruby.html#%3Arubydo), [`:perldo`](https://neovim.io/doc/user/if_perl.html#%3Aperldo), [`:luado`](https://neovim.io/doc/user/lua.html#%3Aluado) series of commands to process lines of text in vim buffers:

```vim
:pydo return line.upper()
:luado return line:gsub("(%a+), (%a+)", "%2 %1")
```

However, nvim does not currently provide `:jsdo` (or your favorite `:xdo` for any language). With this plugin, you can do:

```vim
:Fx line.js return line.replace(/apple/gi, "grape")
```

This plugin provides a universal core pattern based on `:!filter` — specify a filter template file and optional user code to generate a filter script, then use that script to process text in the vim buffer.

```vim
:Fx <filter_template> <(optional)user_code>
```

It also includes several advanced features.

### Why?

Now you can edit text with your favorite language before you fully master vim regexp.

## Features

- Write filter templates in any programming language you like, including those requiring compilation steps;
- Filter templates can be used directly as regular filters;
- Supports inserting and deleting multiple lines of buffer text (compared to built-in commands);
- `:Fx` automatically recognizes [`:h charwise-visual`](https://neovim.io/doc/user/visual.html#charwise-visual) ranges;
- Works with :argdo, :bufdo, :cdo, :cfdo, :ldo, :lfdo, :tabdo, :windo;
- No dependency on [`:h remote-plugin-hosts`](https://neovim.io/doc/user/remote_plugin.html#remote-plugin-hosts);
- UI: Edit multi-line code in an independent window with full vim capabilities;
- UI: Preview changes with diff before execution;
- UI: Manage and reuse historical code snippets;
- UI: Integrates with telescope, snacks.picker, mini.pick;
- UI: Automatically enters batch mode when used with :bufdo etc., works out of the box;

## Installation

- [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "chaneyzorn/filter-do.nvim",
    config = function()
      require("filter_do").setup({})
    end,
}
```

## Configuration

All configuration options and their default values:

```lua
---@type filter_do.Config
require("filter_do").setup({
  -- Number of historical code snippets to keep per filter template (older ones are auto-cleared)
  snippet_record_num = 10,
  -- Custom interpreters and their environment paths
  ---@type table<string, filter_do.ExecutorInfo>
  executors = {},
  -- Custom interpreters for filter scripts (e.g., use bun.js for JS)
  ---@type table<string, string|filter_do.ExecutorInfo>
  tpl_exec = {},
  -- More flexible specification using lua functions
  ---@type fun(tpl_name:string):nil|string|filter_do.ExecutorInfo
  get_executor = nil,
  -- Custom environment variables passed to filter programs
  ---@type fun(ctx:filter_do.FxCtx):filter_do.EnvKv
  default_envs = nil,
  ui = {
    -- UI for interactive selection of filter templates and historical snippets
    -- 'auto': Auto-detect compatible ui.select
    -- 'default': Use built-in vim.ui.select
    -- 'telescope': Use telescope.nvim
    -- 'snacks.picker': Use snacks.picker
    -- 'mini.pick': Use mini.pick
    -- filter_do.UISelectFn: Use any `vim.ui.select`-compatible interface
    ui_select = "auto",
    -- Whether to show the template itself as a selectable historical record
    show_tpl_as_record = true,
    winborder = "rounded",
    -- Custom :h 'listchars' for UI's target window, nil for global defaults
    -- eg: "nbsp:␣,tab:»·,trail:∙,eol:¬,space:∙"
    listchars = nil,
    -- UI-local key mappings
    action_keymaps = {
      apply = "<LocalLeader>a",
      undo = "<LocalLeader>u",
      preview = "<LocalLeader>p",
      history = "<LocalLeader>h",
      back = "<LocalLeader>b",
      close = "<LocalLeader>c",
      previous = "<LocalLeader>[",
      next = "<LocalLeader>]",
    },
  },
})
```

See subsequent sections to learn how to write your own filter templates and specify custom interpreters for scripts (optional).

## Vim Ex Commands

```vim
:[range]Fx <filter_template>[-][+] [user_code]
```

- `[range]`: Optional, handled automatically by vim [`:h cmdline-ranges`](https://neovim.io/doc/user/cmdline.html#cmdline-ranges); additionally recognizes column ranges from [`:h charwise-visual`](https://neovim.io/doc/user/visual.html#charwise-visual);
- `<filter_template>`: Required, sourced from `<vim_runtime>/fxtpl/*` (e.g., `your_own_template.suffix` from `~/.config/nvim/fxtpl/*`);
- `[user_code]`: Optional, custom code that combines with `<filter_template>` to generate a script for `:!filter`; if not specified, the original template content is used directly;
- `[-]`: Optional modifier, uses the previous `[user_code]` (no need to re-enter code);
- `[+]`: Optional modifier, opens an independent window to edit the script (supports writing multi-line codes);

### Subcommands

- `:Fx log`: View logs printed by filters (if any);

Subcommands take precedence over filter templates, so `log` is a reserved name and cannot be used as a template name. More subcommands may be added in future versions.

## Built-in Templates

Built-in templates are located in the `filter-do.nvim/fxtpl/` directory.

- line.py

```py
def handle_one_line(line: str, linenr: int) -> str:
    """Handle each line of the text.

    :param line: One line of text from the vim buffer, typically ending with a newline character.
    :param linenr: The line number in the Vim buffer.
    :return: Processed text line.
        - Return empty string to delete this line.
        - Include `\n` to insert multiple lines of text.
        - Remove the trailing `\n` to join the next line.
    """
    return line  # USER_CODE
```

- line.js

```js
/**
 * Handle each line of the text.
 *
 * @param {string} line - One line of text from the vim buffer, typically ending with a newline character.
 * @param {number} linenr - The line number in the Vim buffer.
 * @returns {string} Processed text line.
 *   - Return empty string to delete this line.
 *   - Include `\n` to insert multiple lines of text.
 *   - Remove the trailing `\n` to join the next line.
 */
async function handleOneLine(line, linenr) {
  return line; // USER_CODE
}
```

- text.py

```py
def handle_block(text: str) -> str:
    """Handle the block of text.

    :param text: A block of text from the vim buffer.
    :return: Processed text block.
    """
    return text  # USER_CODE
```

- text.js

```js
/**
 * Handle the block of text.
 *
 * @param {string} text - A block of text from the vim buffer.
 * @returns {string} Processed text block.
 */
async function handleBlock(text) {
  return text; // USER_CODE
}
```

- systool.sh

```sh
#!/usr/bin/env sh
# Invoke external program as :!filter

cat # USER_CODE

# user-code-ended
# This is a simple wrapper designed to
# align with filter-do.nvim's capabilities.
# such as recognition of `charwise-visual` ranges.
```

## User Examples

- **case-1**: Edit buffer text with Ex command

```vim
:Fx line.js return line.replace(/apple/gi, "grape")
```

- **case-2**: Execute filter on charwise-visual column range

```vim
:'<,'>Fx text.py import json; json.dumps(text.split())
```

- **case-3**: Use previous charwise-visual range and code snippet

```vim
:*Fx text.py-
```

- **case-4**: Use filter template directly

```vim
:new | Fx conway_game_of_life.py
```

- **case-5**: Use specified code snippet with independent edit window

```vim
:Fx text.py+ return text.upper()
```

- **case-6**: Use previous user_code with independent edit window

```vim
:Fx line.js-+
```

- **case-7**: Delete lines across multiple files with `:bufdo`

```vim
:bufdo Fx line.py return "" if line.find("passwd") else line
```

- **case-8**: Complex operations on multiple files with `:cdo` (independent window)

```vim
:cdo Fx line.js+
```

- **case-9**: For more fun

```vim
:enew | while 1 | silent Fx conway_game_of_life.py
:  redraw | sleep 50m | endwhile
```

<https://github.com/user-attachments/assets/acb50187-b9b3-4ff5-b6e7-1e26f21b4f55>

Press Ctrl-C to abort execution. No difference from the built-in `:!filter`—just a demo for fun.

See: `example/fxtpl/conway_game_of_life.py`

## API

```lua
local api = require("filter_do.api")

---Easy-to-use API for filter execution with UI selection
---If tpl_name and code_snip_spec are not specified, triggers ui.select to get them
---@param opts filter_do.FxCtxOpts|nil
api.select_filter_do(opts)

---List all available filters
---@return {tpl_name:string, path:string}[]
api.list_filters()

---@param tpl_name string
---@param order string "asc" | "desc"
---@param include_tpl_itself boolean
---@return filter_do.SnippetHistoryRecord[]
api.list_history_by_tpl(tpl_name, order, include_tpl_itself)

---Core API for filter execution
---@param ctx filter_do.FxCtx
api.filter_do(ctx)

---@param ctxs filter_do.FxCtx[]
api.batch_filter_do(ctxs)

---Implement a set of specified interfaces to complete a custom workflow
---api.select_filter_do is a concrete example based on this interface
---@param ctx_getter filter_do.api.FxCtxGetter
api.filter_do_wrapper(ctx_getter)

---Core data structure: filter_do.FxCtx
---Example below
{
  tpl_name = "text.py",
  buf_range = {
    bufnr = 1,
    charwise_visual = true,
    start_row = 3,
    start_col = 7,
    end_row = 4,
    end_col = 9,
    undotree_seq = 0
  },
  code_snip_spec = {
    type = "code_snip",
    value = "return line.upper()"
  },
  edit_scratch = true,
  envs = {
    START_ROW = "3",
    END_ROW = "4",
    FX_LOG = "/tmp/nvim.chaney/B8fxBa/filter-do.log",
  },
}
```

Refer to the `filter-do/lua/types.lua` file for detailed type definitions.

You can map the API to a keybinding:

```lua
{
    "chaneyzorn/filter-do.nvim",
    cmd = "Fx",
    keys = {
      {
        "<leader>fx",
        function()
          require("filter_do.api").select_filter_do()
        end,
        mode = { "n", "v" },
        desc = "filter-do",
      },
    },
    config = function()
      require("filter_do").setup({})
    end,
}
```

## User Events

During filter-do execution:

- **FxGenStubPre**: Before generating filter script
  - `event.data={spec:filter_do.CodeSnipSpec}`
- **FxGenStubPost**: After generating filter script
  - `event.data={spec:filter_do.CodeSnipSpec, stub_path:string}`
- **FxExecPre**: Before executing filter script
  - `event.data={ctx:filter_do.FxCtx}`
- **FxExecPost**: After executing filter script
  - `event.data={executor_ctx:filter_do.ExecutorCtx, filter_cmd:string[], shell_code:vim.v.shell_error}`
- **FxSaveHistoryPre**: Before saving code snippet record
  - `event.data={stub_path:string}`
- **FxSaveHistoryPost**: After saving code snippet record
  - `event.data={stub_path:string, exist_record:string|nil, new_record:string, checksum:string}`

During UI interaction:

- **FxUIOpenPre**: Before opening UI window
- **FxUIOpenPost**: After opening UI window
- **FxUIApplyPre**: Before applying filter script
- **FxUIApplyPost**: After applying filter script
- **FxUIUndoPre**: Before undoing application
- **FxUIUndoPost**: After undoing application
- **FxUIHistoryPre**: Before selecting historical record
- **FxUIHistoryPost**: After selecting historical record
- **FxUIClosePre**: Before closing UI window
- **FxUIClosePost**: After closing UI window
- **FxUIPreviousPre**: Before selecting previous buffer in batch mode
- **FxUIPreviousPost**: After selecting previous buffer in batch mode
- **FxUINextPre**: Before selecting next buffer in batch mode
- **FxUINextPost**: After selecting next buffer in batch mode
- **FxUIPreviewPre**: Before opening preview mode
- **FxUIPreviewPost**: After opening preview mode
- **FxUIBackPre**: Before returning from preview mode
- **FxUIBackPost**: After returning from preview mode

The `event.data` structure for the above events is as follows:

```lua
---@class filter_do.UIEventData
---@field state filter_do.UICtxState
---@field target_win_id? integer
---@field scratch_win_id? integer
---@field scratch_buf_id? integer
---@field preview_buf_id? integer
```

For example, use User events to disable `winbar` in UI windows:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = { "FxUIOpenPost", "FxUIPreviousPost", "FxUINextPost" },
  callback = function(event)
    vim.api.nvim_set_option_value("winbar", "", { scope = "local", win = event.data.target_win_id })
  end,
})
```

## Custom Environment Variables

You can customize the default environment variables available to your filter commands by configuring the `default_envs` option in the `setup` function. This allows you to inject dynamic or static environment values that will be merged with the built-in variables (e.g., `START_ROW`, `END_ROW`, `FX_LOG`).

```lua
require("filter_do").setup({
  ---@type nil | fun(ctx: filter_do.FxCtx): filter_do.EnvKv
  default_envs = function(ctx)
    return {
      PROJECT_ROOT = vim.fn.getcwd(),
      BUFFER_NUMBER = tostring(ctx.buf_range.bufnr),
      LOG_LEVEL = "DEBUG",
    }
  end,
})
```

## Writing Custom Filter Templates

A filter program reads text from stdin, processes it, and outputs the result to stdout.

### Filter Template Files

filter-do.nvim uses `vim.api.nvim_get_runtime_file("fxtpl/*", true)` to find all template files, such as:

- `filter-do.nvim/fxtpl/*`
- `~/.config/nvim/fxtpl/*`

filter-do.nvim uses two placeholders in template files for positioning:

- `USER_CODE`: The line containing this marker will be replaced with the user's code (replacement starts from the **first non-whitespace character** of the line);
- `user-code-ended`: When editing in an independent window, the cursor is first positioned using `USER_CODE`; if `USER_CODE` has been replaced with actual code, `user-code-ended` is used instead;

For example, `:Fx text.py return text.upper()` generates:

```py
def handle_block(text: str) -> str:
    """Handle the block of text.

    :param text: A block of text from the vim buffer.
    :return: Processed text block.
    """
    return text.upper()
```

- If user code is specified as an empty string, no replacement occurs (original template content is used);
- Templates don't require `USER_CODE` (ignores user code and uses original content);
- Creating a template file with the same name overrides the built-in template.

**Recommendation**: filter-do.nvim enables folding in independent windows with `foldmethod=marker foldlevel=0`. Add `:h fold-marker` to templates to focus on core code.

### Custom Interpreter Environments

If no explicit execution method is specified for a filter script, `executors/shebang.lua` is used by default: the script is made executable and then run (requires a `#!shebang` in the file).

To use a specific interpreter environment, configure it via `require("filter_do").setup()`:

```lua
require("filter_do").setup({
  ---@type table<string, filter_do.ExecutorInfo>
  executors = {
    bunjs = { -- Add new executor
      ---@param ctx filter_do.ExecutorCtx
      pre_action = function(ctx)
        -- customize the environment variables
        ctx.envs = vim.tbl_extend("force", ctx.envs, {
          PROJECT_ROOT = vim.fn.getcwd(),
        })
        return ctx
      end,
      filter_cmd = function(ctx)
        local bun = vim.fn.exepath("bun")
        if bun == "" or bun == nil then
          vim.notify("bun not found", vim.log.levels.ERROR)
          return nil
        end
        return { bun, ctx.stub_path }
      end,
    },
    python = {
        -- Override built-in defaults ...
    },
    shebang = {
        -- Override built-in defaults ...
    },
    my_nodejs = {
        -- Create custom nodejs executor ...
    },
  },
  ---@type table<string, string|filter_do.ExecutorInfo>
  tpl_exec = {
    ["line.js"] = "my_nodejs",  -- Override built-in defaults
    ["some_custom.js"] = "bunjs",
    ["another.py"] = {
        -- Specific python version (e.g., pypy) ...
    },
    -- ["default.sh"] = "shebang",
  },
  ---@type fun(tpl_name:string):nil|string|filter_do.ExecutorInfo
  get_executor = function(tpl_name)
    if tpl_name == "my.js" then
      if vim.fn.exepath("bun") then
        return "bunjs"
      else
        return {
          -- Custom javascript executor ...
        }
      end
    end
    return nil
  end,
})
```

filter-do.nvim determines the executor in the following order:

1. `get_executor(tpl_name)`
2. `tpl_exec[tpl_name]`
3. `executors/shebang.lua`

Compiled languages (e.g., Go) are also supported:

```lua
require("filter_do").setup({
  executors = {
    go = {
      pre_action = function(ctx)
        local target_path = ctx.stub_path:gsub("%.go$", "")
        local res = vim.system({ "go", "build", "-o", target_path, ctx.stub_path }):wait()
        if res.code ~= 0 then
          local err_msg =
            string.format("filter_do.nvim: failed to compile go file %s, err: %s", ctx.stub_path, res.stderr)
          vim.notify(err_msg, vim.log.levels.ERROR)
          return nil
        end

        ctx.user_data.target_path = target_path
        return ctx
      end,
      filter_cmd = function(ctx)
        if not ctx.user_data.target_path then
          vim.notify("filter_do.nvim: go compile target path not found", vim.log.levels.ERROR)
          return nil
        end
        return { ctx.user_data.target_path }
      end,
      post_action = function(ctx)
        if ctx.user_data.target_path then
          os.remove(ctx.user_data.target_path)
        end
      end,
    },
  },
})
```

## Todo

- Support more executors and templates
- Add async spinner in UI during execution
- Create highlight group
- Support the Windows platform

## Acknowledgments

- `:h pydo`: A convenient built-in command (despite limitations) that inspired this project;
- [skywind3000/vim-text-process](https://github.com/skywind3000/vim-text-process): Another filter manager that inspired the scope of this plugin;
- [ColinKennedy/nvim-best-practices-plugin-template](https://github.com/ColinKennedy/nvim-best-practices-plugin-template): Learned much about plugin development; plus many famous plugins in the nvim ecosystem;
- [mcauley-penney/visual-whitespace.nvim](https://github.com/mcauley-penney/visual-whitespace.nvim): May help you visualize EOL in buffers;
