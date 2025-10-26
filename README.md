# `marks.nvim`

A set of utilities to upgrade native vim marks.

## Sample configuration

```lua 
vim.g.marks = {
  -- defaults:
  notify = true,
  remap_m = true,
  highlighted_char_set = marks.local_marks .. marks.global_marks,
}

local marks = require "marks"
vim.keymap.set("n", "]a", function() marks.navigate_local_marks { direction = "next", } end)
vim.keymap.set("n", "[a", function() marks.navigate_local_marks { direction = "prev", } end)
vim.keymap.set("n", "]s", function() marks.navigate_global_marks { direction = "next", } end)
vim.keymap.set("n", "[s", function() marks.navigate_global_marks { direction = "prev", } end)
vim.keymap.set("n", "<leader>ml", marks.toggle_next_local_mark)
vim.keymap.set("n", "<leader>mg", marks.toggle_next_global_mark)
vim.keymap.set("n", "<leader>me", marks.refresh_signs)
vim.keymap.set("n", "<leader>md", marks.delete_buffer_marks)
```

## Configuration options

#### `vim.g.marks.notify`
- Call `vim.notify` with info related to the `marks.*` function called

#### `vim.g.marks.remap_m`
- Remap `m` to refresh the sign column when setting a mark

#### `vim.g.marks.highlighted_char_set`
- The set of mark characters to render in the sign column 

## TODO
- [ ] Testing
- [ ] Support builtin marks, refreshing when necessary
