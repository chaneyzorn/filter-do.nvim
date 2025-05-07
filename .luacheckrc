std = luajit
cache = true
codes = true

self = false
read_globals = { "vim" }

-- Reference: https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {
  -- Neovim lua API + luacheck thinks variables like `vim.wo.spell = true` is
  -- invalid when it actually is valid. So we have to disable rule `W122`.
  "122",
}

exclude_files = {}
