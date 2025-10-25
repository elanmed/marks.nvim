local M = {}

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

local gopts = function()
  --- @type MarksOpts
  local opts = default(vim.g.marks, {})
  opts = vim.deepcopy(opts)
  opts.notify = default(opts.notify, true)
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

M.local_marks = ("abcdefghijklmnopqrstuvwxyz")
M.global_marks = M.local_marks:upper()
M.number_marks = "0123456789"
M.builtin_marks = "[]<>`\"^.(){}"
M.all_marks = M.global_marks .. M.local_marks .. M.number_marks .. M.builtin_marks

--- @param mark_name string
local function get_buffer_mark_info(mark_name)
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

  for letter in (M.all_marks):gmatch "." do
    if get_buffer_mark_info(letter) ~= nil then
      local id = letter:byte() * 100
      local lnum = unpack(vim.api.nvim_buf_get_mark(bufnr, letter))
      vim.fn.sign_place(id, group, letter, bufnr, { lnum = lnum, priority = 10, })
    end
  end
end

--- @class MarksSetupOpts
--- @field remap_m? boolean
--- @field highlighted_char_set? string
--- @param opts MarksSetupOpts
M.setup = function(opts)
  opts = vim.deepcopy(default(opts, {}))
  opts.remap_m = default(opts.remap_m, true)
  opts.highlighted_char_set = default(opts.highlighted_char_set, M.global_marks .. M.local_marks)

  for letter in (opts.highlighted_char_set):gmatch "." do
    vim.fn.sign_define(letter, { text = letter, texthl = "Mark", })
  end

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
  vim.api.nvim_buf_set_mark(0, letter, vim.fn.line ".", 0, {})
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
  for letter in M.global_marks:gmatch "." do
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
  for letter in M.local_marks:gmatch "." do
    local mark_info = get_buffer_mark_info(letter)
    if mark_info == nil then
      set_mark(letter)
      return
    end

    if mark_info[1] == vim.fn.line "." then
      del_mark(letter)
      return
    end
  end
end

--- @param direction "next"|"prev"
M.navigate_mark = function(direction)
  --- @type number[]
  local mark_row_list = {}
  -- TODO support any set of marks
  for letter in (M.global_marks .. M.local_marks):gmatch "." do
    local mark_info = get_buffer_mark_info(letter)
    if mark_info ~= nil then
      table.insert(mark_row_list, mark_info[1])
    end
  end

  table.sort(mark_row_list, function(a, b)
    if direction == "next" then
      return b > a
    else
      return b < a
    end
  end)

  for _, mark_row in ipairs(mark_row_list) do
    local row_condition = (function()
      if direction == "next" then
        return mark_row > vim.fn.line "."
      end
      return mark_row < vim.fn.line "."
    end)()

    if row_condition then
      vim.api.nvim_win_set_cursor(0, { mark_row, 0, })
      return
    end
  end

  if #mark_row_list == 0 then return end
  local mark_row = mark_row_list[1]
  vim.api.nvim_win_set_cursor(0, { mark_row, 0, })
end

M.delete_buffer_marks = function()
  local deleted = false
  -- TODO support any set of marks
  for letter in (M.global_marks .. M.local_marks):gmatch "." do
    if get_buffer_mark_info(letter) ~= nil then
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
