# `marks.nvim`

A set of utilities to smooth out native vim marks.

## Sample configuration

```lua 
vim.g.marks = {
  -- defaults:
  notify = true,
  highlighted_char_set = marks.local_marks .. marks.global_marks,
}

local marks = require "marks"
marks.setup {
  -- defaults:
  remap_m = true,
}

```

## Configuration options

#### `vim.g.marks.notify`
- TODO

#### `vim.g.marks.highlighted_char_set`
- TODO
