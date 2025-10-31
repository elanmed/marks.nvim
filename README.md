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

vim.keymap.set("n", "]a", function() marks.navigate_buffer_marks { direction = "next", } end)
vim.keymap.set("n", "[a", function() marks.navigate_buffer_marks { direction = "prev", } end)
vim.keymap.set("n", "]s", function() marks.navigate_global_marks { direction = "next", } end)
vim.keymap.set("n", "[s", function() marks.navigate_global_marks { direction = "prev", } end)
vim.keymap.set("n", "<leader>ml", marks.toggle_next_local_mark)
vim.keymap.set("n", "<leader>mg", marks.toggle_next_global_mark)
vim.keymap.set("n", "<leader>me", marks.refresh_signs)
vim.keymap.set("n", "<leader>md", marks.delete_buffer_marks)
vim.keymap.set("n", "<leader>mq", marks.send_global_marks_to_qf_list)
vim.keymap.set("n", "<leader>mf", marks.buffer_marks_to_qf_list)

-- defaults
vim.api.nvim_set_hl(0, "MarkCol", { default = true, link = "Search", })
vim.api.nvim_set_hl(0, "MarkRow", { default = true, link = "Search", })
```

## Configuration options

#### `vim.g.marks.notify`
- Call `vim.notify` with info related to the `marks.*` function called

#### `vim.g.marks.remap_m`
- Remap `m` to refresh the sign column when setting a mark

#### `vim.g.marks.highlight_char_set`
- The set of mark characters to render a sign for in the sign column

## Api
#### `navigate_buffer_marks`

```lua
--- @class MarksNavigateBufferMarksOpts
--- @field direction "next"|"prev"
--- @field navigate_char_set? string defaults to `marks.char_sets.local_marks .. marks.char_sets.global_marks`
--- @param opts MarksNavigateBufferMarksOpts
M.navigate_buffer_marks = function(opts)
```
- Navigate to the next/prev mark in the buffer that matches `opts.navigate_char_set`
- Cycles

#### `navigate_global_marks`
```lua
--- @class MarksNavigateGlobalMarksOpts
--- @field direction "next"|"prev"
--- @param opts MarksNavigateGlobalMarksOpts
M.navigate_global_marks = function(opts)
```
- Navigate to the next/prev global mark
- Cycles

#### `toggle_next_local_mark`
```lua
M.toggle_next_local_mark = function()
```
- If a local mark is set on the current line, delete it
- Else, set the next available local mark

#### `toggle_next_global_mark`
```lua
M.toggle_next_global_mark = function()
```
- If a global mark is set on the current line, delete it
- Else, set the next available global mark

#### `refresh_signs`
```lua
M.refresh_signs = function()
```
- Manually refresh the sign column
    - This shouldn't be necessary, it's called behind the scenes

#### `delete_buffer_marks`
```lua
M.delete_buffer_marks = function()
```
- Delete all local and global marks in the buffer
    - To delete all local marks, use `vim.cmd.delmarks "[a-z]"`
    - To delete all global marks, use `vim.cmd.delmarks "[A-Z]"`

#### `global_marks_to_qf_list`
```lua
M.global_marks_to_qf_list = function()
```
- Send all global marks to the quickfix list
- Open the quickfix list

#### `buffer_marks_to_qf_list`
```lua
--- @class MarksSendBufferMarksToQfListOpts
--- @field qf_list_char_set? string defaults to `marks.char_sets.local_marks .. marks.char_sets.global_marks`
--- @param opts MarksSendBufferMarksToQfListOpts
M.buffer_marks_to_qf_list = function(opts)
```
- Send marks in the buffer that match `opts.qf_list_char_set` to the quickfix list
- Open the quickfix list

## Similar plugins
- [chentoast/marks.nvim](https://github.com/chentoast/marks.nvim) (sorry for the duplicate name 😅)
- [vim-signature](https://github.com/kshenoy/vim-signature)
- [vim-bookmarks](https://github.com/MattesGroeger/vim-bookmarks)
