local M = {}

local ns = vim.api.nvim_create_namespace "marks.nvim"

M.char_sets = {}
M.char_sets.local_marks = ("abcdefghijklmnopqrstuvwxyz")
M.char_sets.global_marks = M.char_sets.local_marks:upper()
M.char_sets.number_marks = "0123456789"
M.char_sets.builtin_marks = "[]<>`\"^.(){}"
M.char_sets.all_marks = M.char_sets.global_marks ..
    M.char_sets.local_marks ..
    M.char_sets.number_marks ..
    M.char_sets.builtin_marks

--- @generic T
--- @param val T | nil
--- @param default_val T
--- @return T
local default = function(val, default_val)
  if val == nil then
    return default_val
  end
  return val
end

--- @param tbl table
--- @param ... any
local tbl_get = function(tbl, ...)
  if tbl == nil then return nil end
  return vim.tbl_get(tbl, ...)
end

--- @class MarksOpts
--- @field notify? boolean
--- @field remap_m? boolean
--- @field highlight_char_set? string

local gopts = function()
  --- @type MarksOpts
  local opts = {}
  opts.notify = default(tbl_get(vim.g.marks, "notify"), true)
  opts.remap_m = default(tbl_get(vim.g.marks, "remap_m"), true)
  opts.highlight_char_set = default(
    tbl_get(vim.g.marks, "highlight_char_set"),
    M.char_sets.global_marks .. M.char_sets.local_marks
  )
  return opts
end

--- @param level vim.log.levels
--- @param msg string
--- @param ... any
local notify = function(level, msg, ...)
  if not gopts().notify then return end

  msg = "[marks.nvim]: " .. msg
  vim.notify(msg:format(...), level)
end

--- @param mark_name string
local function get_buffer_mark_pos(mark_name)
  local mark = vim.api.nvim_buf_get_mark(0, mark_name)
  if mark[1] == 0 then
    return nil
  end
  return { row = mark[1], col = mark[2], }
end

--- @param mark_name string
local function get_global_mark_info(mark_name)
  local mark = vim.api.nvim_get_mark(mark_name, {})
  if mark[1] == 0 and mark[2] == 0 and mark[3] == 0 and mark[4] == "" then
    return nil
  end
  return { row = mark[1], col = mark[2], bufnr = mark[3], bufname = mark[4], }
end

--- @param bufnr number
local function refresh_mark_signs(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == "" then return end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr, })
  local is_normal_buf = buftype == ""
  if not is_normal_buf then return end

  local sign_group = "marks.nvim"
  vim.fn.sign_unplace(sign_group, { buffer = bufnr, })
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  for letter in gopts().highlight_char_set:gmatch "." do
    local mark_pos = get_buffer_mark_pos(letter)
    if mark_pos == nil then goto continue end
    local id = letter:byte() * 100

    local priority = (function()
      if letter:match "%a" then
        return 20
      end
      return 10
    end)()
    vim.fn.sign_place(id, sign_group, letter, bufnr, { lnum = mark_pos.row, priority = priority, })

    if letter:match "%a" then goto continue end

    local row_zero_indexed = mark_pos.row - 1
    vim.hl.range(bufnr, ns, "MarkCol", { row_zero_indexed, mark_pos.col, }, { row_zero_indexed, mark_pos.col, })

    ::continue::
  end
end

vim.g.marks_setup_called = false
M.setup = function()
  if vim.g.marks_setup_called then return end
  vim.g.marks_setup_called = true
  local opts = gopts()

  vim.api.nvim_set_hl(0, "MarkCol", { link = "Search", })
  vim.api.nvim_set_hl(0, "MarkRow", { link = "Search", })

  for letter in opts.highlight_char_set:gmatch "." do
    vim.fn.sign_define(letter, { text = letter, texthl = "MarkRow", })
  end

  local events = {}

  if opts.highlight_char_set:match "[%a]" then
    events["BufEnter"] = true
    events["BufWinEnter"] = true
  end

  -- <> first/last character of the last selected area
  if opts.highlight_char_set:match "[<>]" then
    events["ModeChanged"] = true
  end

  -- [] first/last character of the last changed or yanked text
  if opts.highlight_char_set:match "[%[%]]" then
    events["TextChanged"] = true
    events["TextChangedI"] = true
    events["TextChangedP"] = true
    events["TextYankPost"] = true
  end

  -- ` cursor before the latest jump, or last m
  if opts.highlight_char_set:match "[`]" then
    events["CursorMoved"] = true
    events["BufEnter"] = true
    events["WinEnter"] = true
    events["TabEnter"] = true
    events["BufDelete"] = true
  end

  -- " cursor when last exiting the current buffer
  if opts.highlight_char_set:match '["]' then
    events["BufLeave"] = true
    events["BufWinLeave"] = true
  end

  -- ^ cursor when insert mode was last stopped
  if opts.highlight_char_set:match "[%^]" then
    events["InsertLeave"] = true
  end

  -- . cursor where the last change was made
  if opts.highlight_char_set:match "[%.]" then
    events["TextChanged"] = true
    events["TextChangedI"] = true
    events["TextChangedP"] = true
  end

  -- () start/end of the current sentence
  -- {} start/end of the current paragraph
  if opts.highlight_char_set:match "[%(%)%{%}]" then
    events["TextChanged"] = true
    events["TextChangedI"] = true
    events["TextChangedP"] = true
    events["CursorMoved"] = true
    events["CursorMovedI"] = true
  end

  local event_list = {}
  for event, _ in pairs(events) do
    table.insert(event_list, event)
  end

  if vim.tbl_count(events) > 0 then
    vim.api.nvim_create_autocmd(event_list, {
      callback = function(args) refresh_mark_signs(args.buf) end,
      desc = "Refresh the mark signs",
    })
  end

  if opts.remap_m then
    vim.keymap.set({ "n", "v", "x", }, "m", function()
      local char = vim.fn.getcharstr()
      vim.schedule(function() refresh_mark_signs(0) end)
      return "m" .. char
    end, { nowait = true, expr = true, desc = "m", })
  end
end

local function set_mark(letter)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_mark(0, letter, cursor_pos[1], cursor_pos[2], {})
  refresh_mark_signs(0)
  notify(vim.log.levels.INFO, "Set mark %s to line %s", letter, vim.fn.line ".")
end

local function del_mark(letter)
  vim.api.nvim_buf_del_mark(0, letter)
  refresh_mark_signs(0)
  notify(vim.log.levels.INFO, "Deleting mark %s", letter)
end

M.refresh_signs = function()
  refresh_mark_signs(0)
  notify(vim.log.levels.INFO, "Refreshing marks")
end

M.toggle_next_global_mark = function()
  for letter in M.char_sets.global_marks:gmatch "." do
    local global_mark_info = get_global_mark_info(letter)
    if not global_mark_info then
      set_mark(letter)
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    if global_mark_info.bufnr == bufnr then
      if global_mark_info.row == vim.fn.line "." then
        del_mark(letter)
      else
        set_mark(letter)
      end
      return
    end
  end
end

M.toggle_next_local_mark = function()
  for letter in M.char_sets.local_marks:gmatch "." do
    local mark_pos = get_buffer_mark_pos(letter)
    if mark_pos == nil then
      set_mark(letter)
      return
    end

    if mark_pos.row == vim.fn.line "." then
      del_mark(letter)
      return
    end
  end
end

--- @class MarksNavigateGlobalMarksOpts
--- @field direction "next"|"prev"
--- @param opts MarksNavigateGlobalMarksOpts
M.navigate_global_marks = function(opts)
  if tbl_get(opts, "direction") ~= "next" and tbl_get(opts, "direction") ~= "prev" then
    notify(vim.log.levels.ERROR, "`navigate_local_marks.opts.direction` must be `next` or `prev`")
    return
  end

  local global_marks_str = (function()
    if opts.direction == "next" then
      return M.char_sets.global_marks
    end
    return M.char_sets.global_marks:reverse()
  end)()

  --- @type string[]
  local global_marks_list = {}
  for global_mark in global_marks_str:gmatch "." do
    if get_global_mark_info(global_mark) then
      table.insert(global_marks_list, global_mark)
    end
  end

  local curr_buf = vim.api.nvim_get_current_buf()
  local curr_idx = 1
  for idx, global_mark in ipairs(global_marks_list) do
    local mark_info = assert(get_global_mark_info(global_mark))
    if curr_buf == mark_info.bufnr then
      curr_idx = idx
    end
  end

  if #global_marks_list == 0 then
    notify(vim.log.levels.INFO, "No global marks")
    return
  end
  if #global_marks_list == 1 then return end

  local next_idx = curr_idx + 1
  if next_idx > #global_marks_list then
    next_idx = 1
  end
  local next_mark = global_marks_list[next_idx]
  local next_mark_info = assert(get_global_mark_info(next_mark))
  vim.cmd.edit(next_mark_info.bufname)
  vim.api.nvim_win_set_cursor(0, { next_mark_info.row, next_mark_info.col, })
end

--- @class MarksNavigateBufferMarksOpts
--- @field direction "next"|"prev"
--- @field navigate_char_set? string
--- @param _opts MarksNavigateBufferMarksOpts
M.navigate_buffer_marks = function(_opts)
  if tbl_get(_opts, "direction") ~= "next" and tbl_get(_opts, "direction") ~= "prev" then
    notify(vim.log.levels.ERROR, "`navigate_local_marks.opts.direction` must be `next` or `prev`")
    return
  end

  local opts = {}
  opts.navigate_char_set = default(
    tbl_get(_opts, "navigate_char_set"),
    M.char_sets.local_marks .. M.char_sets.global_marks
  )
  opts.direction = _opts.direction

  --- @type {row: number, col: number}[]
  local mark_pos_list = {}
  for letter in opts.navigate_char_set:gmatch "." do
    local mark_pos = get_buffer_mark_pos(letter)
    if mark_pos ~= nil then
      table.insert(mark_pos_list, mark_pos)
    end
  end

  table.sort(mark_pos_list, function(a, b)
    if opts.direction == "next" then
      return b.row > a.row
    else
      return b.row < a.row
    end
  end)

  for _, mark_pos in ipairs(mark_pos_list) do
    local row_condition = (function()
      if opts.direction == "next" then
        return mark_pos.row > vim.fn.line "."
      end
      return mark_pos.row < vim.fn.line "."
    end)()

    if row_condition then
      vim.api.nvim_win_set_cursor(0, { mark_pos.row, mark_pos.col, })
      return
    end
  end

  if #mark_pos_list == 0 then return end
  local mark_pos = mark_pos_list[1]
  vim.api.nvim_win_set_cursor(0, { mark_pos.row, mark_pos.col, })
end

M.delete_buffer_marks = function()
  local deleted = false
  for letter in (M.char_sets.global_marks .. M.char_sets.local_marks):gmatch "." do
    if get_buffer_mark_pos(letter) ~= nil then
      vim.api.nvim_buf_del_mark(0, letter)
      deleted = true
    end
  end
  if deleted then
    notify(vim.log.levels.INFO, "Deleted marks")
  else
    notify(vim.log.levels.WARN, "No marks in the buffer")
  end

  refresh_mark_signs(0)
end

--- @class MarksSendBufferMarksToQfListOpts
--- @field qf_list_char_set? string
--- @param _opts MarksSendBufferMarksToQfListOpts
M.buffer_marks_to_qf_list = function(_opts)
  --- @type MarksSendBufferMarksToQfListOpts
  local opts = {}
  opts.qf_list_char_set = default(
    tbl_get(_opts, "qf_list_char_set"),
    M.char_sets.local_marks .. M.char_sets.global_marks
  )
  local qf_list = {}
  for letter in opts.qf_list_char_set:gmatch "." do
    local mark_pos = get_buffer_mark_pos(letter)
    if mark_pos ~= nil then
      local line = vim.trim(vim.api.nvim_buf_get_lines(0, mark_pos.row, mark_pos.row + 1, false)[1])
      table.insert(qf_list, {
        bufnr = 0,
        text = ("%s|%s"):format(letter, line),
        lnum = mark_pos.row,
        col = mark_pos.col,
        filename = vim.fs.normalize(vim.api.nvim_buf_get_name(0)),
      })
    end
  end
  vim.fn.setqflist(qf_list)
  vim.cmd.copen()
end

M.global_marks_to_qf_list = function()
  local qf_list = {}
  for letter in M.char_sets.global_marks:gmatch "." do
    local mark_info = get_global_mark_info(letter)

    if mark_info ~= nil then
      local lines = vim.fn.readfile(vim.fs.normalize(mark_info.bufname), tostring(mark_info.row))
      local line = vim.list_slice(lines, mark_info.row, mark_info.row)[1]
      line = vim.trim(line)

      table.insert(qf_list, {
        text = ("%s|%s"):format(letter, line),
        lnum = mark_info.row,
        col = mark_info.col,
        filename = vim.fs.normalize(mark_info.bufname),
      })
    end
  end
  vim.fn.setqflist(qf_list)
  vim.cmd.copen()
end

return M
