local M = {}

M.char_sets = {}
M.char_sets.local_marks = ("abcdefghijklmnopqrstuvwxyz")
M.char_sets.global_marks = M.char_sets.local_marks:upper()
M.char_sets.number_marks = "0123456789"
M.char_sets.builtin_marks = "[]<>`\"^.(){}"
M.char_sets.all_marks = M.char_sets.global_marks ..
    M.char_sets.local_marks .. M.char_sets.number_marks .. M.char_sets.builtin_marks

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

--- @class MarksOpts
--- @field notify? boolean
--- @field highlight_char_set? string

local gopts = function()
  --- @type MarksOpts
  local opts = default(vim.g.marks, {})
  opts = vim.deepcopy(opts)
  opts.notify = default(opts.notify, true)
  opts.highlight_char_set = default(opts.highlight_char_set, M.char_sets.global_marks .. M.char_sets.local_marks)
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
  if mark[1] == 0 and mark[2] == 0 then
    return nil
  end
  return mark
end

--- @param mark_name string
local function get_global_mark_info(mark_name)
  local mark = vim.api.nvim_get_mark(mark_name, {})
  if mark[1] == 0 and mark[2] == 0 and mark[3] == 0 and mark[4] == "" then
    return nil
  end
  return { row = mark[1], bufnr = mark[3], }
end

--- @param bufnr number
local function refresh_mark_signs(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local group = ""
  vim.fn.sign_unplace(group, { buffer = bufnr, })

  for letter in (gopts().highlight_char_set):gmatch "." do
    if get_buffer_mark_pos(letter) ~= nil then
      local id = letter:byte() * 100
      local lnum = unpack(vim.api.nvim_buf_get_mark(bufnr, letter))
      vim.fn.sign_place(id, group, letter, bufnr, { lnum = lnum, priority = 10, })
    end
  end
end

--- @class MarksSetupOpts
--- @field remap_m? boolean
--- @param opts MarksSetupOpts
M.setup = function(opts)
  opts = vim.deepcopy(default(opts, {}))
  opts.remap_m = default(opts.remap_m, true)

  for letter in (gopts().highlight_char_set):gmatch "." do
    vim.fn.sign_define(letter, { text = letter, texthl = "Mark", })
  end

  -- TODO handle refresh for builtin marks

  vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(args)
      refresh_mark_signs(args.buf)
    end,
  })

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

    if mark_pos[1] == vim.fn.line "." then
      del_mark(letter)
      return
    end
  end
end

--- @class MarksNavigateLocalMarksOpts
--- @field direction "next"|"prev"
--- @field navigate_char_set? string
--- @param opts MarksNavigateLocalMarksOpts
M.navigate_local_marks = function(opts)
  opts = vim.deepcopy(default(opts, {}))
  opts.navigate_char_set = default(opts.navigate_char_set, M.char_sets.local_marks .. M.char_sets.global_marks)

  if opts.direction ~= "next" and opts.direction ~= "prev" then
    notify(vim.log.levels.ERROR, "`navigate_local_marks.opts.direction` must be `next` or `prev`")
    return
  end

  --- @type number[][]
  local mark_pos_list = {}
  -- TODO support any set of marks
  for letter in (opts.navigate_char_set):gmatch "." do
    local mark_pos = get_buffer_mark_pos(letter)
    if mark_pos ~= nil then
      table.insert(mark_pos_list, mark_pos)
    end
  end

  table.sort(mark_pos_list, function(a, b)
    if opts.direction == "next" then
      return b[1] > a[1]
    else
      return b[1] < a[1]
    end
  end)

  for _, mark_pos in ipairs(mark_pos_list) do
    local row_condition = (function()
      if opts.direction == "next" then
        return mark_pos[1] > vim.fn.line "."
      end
      return mark_pos[1] < vim.fn.line "."
    end)()

    if row_condition then
      vim.api.nvim_win_set_cursor(0, { mark_pos[1], mark_pos[2], })
      return
    end
  end

  if #mark_pos_list == 0 then return end
  local mark_pos = mark_pos_list[1]
  vim.api.nvim_win_set_cursor(0, { mark_pos[1], mark_pos[2], })
end

M.delete_buffer_marks = function()
  local deleted = false
  -- TODO support any set of marks
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

return M
