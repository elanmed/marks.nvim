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
--- @field remap_m? boolean
--- @field notify? boolean

local gopts = function()
  --- @type MarksOpts
  local opts = default(vim.g.marks, {})
  opts = vim.deepcopy(opts)
  opts.remap_m = default(opts.remap_m, true)
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

--- @param mark_name string
local function get_global_mark_info(mark_name)
  local mark = vim.api.nvim_get_mark(mark_name, {})
  if mark[1] == 0 and mark[2] == 0 and mark[3] == 0 and mark[4] == "" then
    return nil
  end
  return { row = mark[1], bufnr = mark[3], }
end

--- @param mark_name string
local function get_buffer_mark_row(mark_name)
  local mark = vim.api.nvim_buf_get_mark(0, mark_name)
  if mark[1] == 0 and mark[2] == 0 then
    return nil
  end
  return mark[1]
end

local local_marks = ("abcdefghijklmnopqrstuvwxyz")
local global_marks = local_marks:upper()
for letter in (global_marks .. local_marks):gmatch "." do
  vim.fn.sign_define(letter, { text = letter, texthl = "Mark", })
end

--- @param bufnr number
local function refresh_mark_signs(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local group = ""
  vim.fn.sign_unplace(group, { buffer = bufnr, })

  for letter in (global_marks .. local_marks):gmatch "." do
    if get_buffer_mark_row(letter) then
      local id = letter:byte() * 100
      local lnum = unpack(vim.api.nvim_buf_get_mark(bufnr, letter))
      vim.fn.sign_place(id, group, letter, bufnr, { lnum = lnum, priority = 10, })
    end
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

vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function(args)
    refresh_mark_signs(args.buf)
  end,
})

M.refresh_signs = function()
  refresh_mark_signs(0)
  notify(vim.log.levels.INFO, "Refreshing marks")
end

local toggle_next_global_mark = function()
  for letter in global_marks:gmatch "." do
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

local toggle_next_local_mark = function()
  for letter in local_marks:gmatch "." do
    local mark_row = get_buffer_mark_row(letter)
    if not mark_row then
      set_mark(letter)
      return
    end

    if mark_row == vim.fn.line "." then
      del_mark(letter)
      return
    end
  end
end

--- @param direction "next"|"prev"
local function navigate_mark(direction)
  --- @type number[]
  local mark_row_list = {}
  for letter in (global_marks .. local_marks):gmatch "." do
    local mark_row = get_buffer_mark_row(letter)
    if mark_row then
      table.insert(mark_row_list, mark_row)
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

local delete_buffer_marks = function()
  local deleted = false
  for letter in (global_marks .. local_marks):gmatch "." do
    if get_buffer_mark_row(letter) then
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

vim.keymap.set("n", "m", function()
  local char = vim.fn.getcharstr()
  vim.schedule(function() refresh_mark_signs(0) end)
  return "m" .. char
end, { nowait = true, expr = true, desc = "m", })

return M
