# `marks.nvim`

A set of utilities to improve your experience with vim marks.

## Features
- Renders a sign at the row of the mark in the sign column (`MarkRow`)
    - The set of marks to render a sign for is configurable
    - Updates automatically
- Highlights the column of the mark (`MarkCol`)
- Utilities to toggle the next available local, global mark, navigate between marks
- 1 source file (~400 LOC), 1 test file

## Sample configuration

```lua 
local marks = require "marks"
vim.g.marks = {
  -- defaults:
  notify = true,
  remap_m = true,
  highlight_char_set = marks.char_sets.local_marks .. marks.char_sets.global_marks,
}

vim.keymap.set("n", "]a", function() marks.navigate_local_marks { direction = "next", } end)
vim.keymap.set("n", "[a", function() marks.navigate_local_marks { direction = "prev", } end)
vim.keymap.set("n", "]s", function() marks.navigate_global_marks { direction = "next", } end)
vim.keymap.set("n", "[s", function() marks.navigate_global_marks { direction = "prev", } end)
vim.keymap.set("n", "<leader>ml", marks.toggle_next_local_mark)
vim.keymap.set("n", "<leader>mg", marks.toggle_next_global_mark)
vim.keymap.set("n", "<leader>me", marks.refresh_signs)
vim.keymap.set("n", "<leader>md", marks.delete_buffer_marks)

-- defaults
vim.api.nvim_set_hl(0, "MarkCol", { link = "Search", })
vim.api.nvim_set_hl(0, "MarkRow", { link = "Search", })
```

## Configuration options

#### `vim.g.marks.notify`
- Call `vim.notify` with info related to the `marks.*` function called

#### `vim.g.marks.remap_m`
- Remap `m` to refresh the sign column when setting a mark

#### `vim.g.marks.highlight_char_set`
- The set of mark characters to render a sign for in the sign column

## TODO
- [ ] Testing

## Similar plugins
- [chentoast/marks.nvim](https://github.com/chentoast/marks.nvim) (sorry for taking duplicate name 😅)
- [vim-signature](https://github.com/kshenoy/vim-signature)
- [vim-bookmarks](https://github.com/MattesGroeger/vim-bookmarks)
