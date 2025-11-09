require "mini.test".setup()
local child = MiniTest.new_child_neovim()

local dummy_dir = "dummy_dir"
local dummy_file_a = vim.fs.joinpath(dummy_dir, "dummy_file_a.txt")
local dummy_file_b = vim.fs.joinpath(dummy_dir, "dummy_file_b.txt")
local dummy_file_c = vim.fs.joinpath(dummy_dir, "dummy_file_c.txt")

local expect_qf_list = MiniTest.new_expectation(
  "qf list equal",
  function(expected, received)
    local mapped = vim.tbl_map(function(entry)
      return {
        text = entry.text,
        lnum = entry.lnum,
        col = entry.col,
        filename = entry.filename,
      }
    end, received)
    return vim.deep_equal(mapped, expected)
  end,
  function(expected, received)
    local mapped = vim.tbl_map(function(entry)
      return {
        text = entry.text,
        lnum = entry.lnum,
        col = entry.col,
        filename = entry.filename,
      }
    end, received)
    return ("Expected %s, received %s"):format(vim.inspect(expected), vim.inspect(mapped))
  end
)

local expect_cursor = MiniTest.new_expectation(
  "cursor set",
  --- @class ExpectCursorOpts
  --- @field row number
  --- @field col number
  --- @field basename? string
  --- @param opts ExpectCursorOpts
  function(opts)
    local bufname = child.api.nvim_buf_get_name(child.api.nvim_get_current_buf())
    local cursor = child.api.nvim_win_get_cursor(child.api.nvim_get_current_win())
    if opts.basename then
      return cursor[1] == opts.row and cursor[2] == opts.col and opts.basename == vim.fs.basename(bufname)
    else
      return cursor[1] == opts.row and cursor[2] == opts.col
    end
  end,
  --- @param opts ExpectCursorOpts
  function(opts)
    local bufname = child.api.nvim_buf_get_name(child.api.nvim_get_current_buf())
    local cursor = child.api.nvim_win_get_cursor(child.api.nvim_get_current_win())
    if opts.basename then
      return ("Expected cursor to be at %s, %s at bufname %s, was at %s, %s at bufname %s"):format(opts.row, opts.col,
        opts.basename, cursor[1], cursor[2], vim.fs.basename(bufname))
    else
      return ("Expected cursor to be at %s, %s, was at %s, %s"):format(opts.row, opts.col, cursor[1], cursor[2])
    end
  end
)

local expect_buffer_mark = MiniTest.new_expectation(
  "mark set",
  --- @class ExpectBufferMarkOpts
  --- @field row number
  --- @field col number
  --- @field letter string
  --- @field set boolean
  --- @param opts ExpectBufferMarkOpts
  function(opts)
    local mark = child.api.nvim_buf_get_mark(child.api.nvim_get_current_buf(), opts.letter)
    if opts.set then
      return mark[1] == opts.row and mark[2] == opts.col
    else
      return mark[1] == 0 and mark[2] == 0
    end
  end,
  --- @param opts ExpectBufferMarkOpts
  function(opts)
    if opts.set then
      return ("Expected mark %s to be set, was not"):format(opts.letter)
    else
      return ("Expected mark %s not to be set, was"):format(opts.letter)
    end
  end
)

local expect_global_mark = MiniTest.new_expectation(
  "mark set",
  --- @class ExpectGlobalMarkOpts
  --- @field row number
  --- @field col number
  --- @field letter string
  --- @field basename string
  --- @field set boolean
  --- @param opts ExpectGlobalMarkOpts
  function(opts)
    local mark = child.api.nvim_get_mark(opts.letter, {})
    if opts.set then
      return mark[1] == opts.row and mark[2] == opts.col and vim.fs.basename(mark[4]) == opts.basename
    else
      return mark[1] == 0 and mark[2] == 0 and mark[3] == 0 and mark[4] == ""
    end
  end,
  --- @param opts ExpectGlobalMarkOpts
  function(opts)
    if opts.set then
      return ("Expected mark %s to be set, was not"):format(opts.letter)
    else
      return ("Expected mark %s not to be set, was"):format(opts.letter)
    end
  end
)

local expect_sign = MiniTest.new_expectation(
  "sign set",
  --- @class ExpectSignOpts
  --- @field letter string
  --- @field set boolean
  --- @param opts ExpectSignOpts
  function(opts)
    local signs = child.fn.sign_getplaced(child.api.nvim_get_current_buf(), { group = "marks.nvim", })[1].signs
    if opts.set then
      return vim.tbl_contains(signs, function(sign)
        return sign.name == opts.letter
      end, { predicate = true, })
    else
      return not vim.tbl_contains(signs, function(sign)
        return sign.name == opts.letter
      end, { predicate = true, })
    end
  end,
  --- @param opts ExpectSignOpts
  function(opts)
    if opts.set then
      return ("Expected sign %s to be set, was not"):format(opts.letter)
    else
      return ("Expected sign %s not to be set, was"):format(opts.letter)
    end
  end
)

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      vim.fn.mkdir(dummy_dir)
      vim.fn.writefile({ "alpha", "bravo", "charlie", }, dummy_file_a)
      vim.fn.writefile({ "delta", "echo", "foxtrot", }, dummy_file_b)
      vim.fn.writefile({ "golf", "hotel", "india", }, dummy_file_c)

      child.restart { "-u", "scripts/minimal_init.lua", }
      child.cmd "set signcolumn=yes"
      child.lua [[M = require('marks')]]
      child.cmd("edit " .. dummy_file_a)
    end,
    post_case = function()
      vim.fn.delete(dummy_dir, "rf")
    end,
    post_once = child.stop,
  },
}

T["get_next_avail_local_mark"] = function()
  child.lua [[M.setup()]]

  MiniTest.expect.equality("a", child.lua_get [[M.get_next_avail_local_mark()]])

  child.lua [[M.toggle_next_local_mark()]]
  expect_sign { letter = "a", set = true, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }

  MiniTest.expect.equality("b", child.lua_get [[M.get_next_avail_local_mark()]])
end

T["toggle_next_local_mark"] = MiniTest.new_set {
  hooks = { pre_case = function() child.lua [[M.setup()]] end, },
}
T["toggle_next_local_mark"]["toggle a mark when called on a single line"] = function()
  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }

  child.lua [[M.toggle_next_local_mark()]]

  expect_sign { letter = "a", set = true, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }

  child.lua [[M.toggle_next_local_mark()]]

  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }
end
T["toggle_next_local_mark"]["add the next available mark"] = function()
  child.lua [[M.toggle_next_local_mark()]]
  expect_sign { letter = "a", set = true, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }

  expect_sign { letter = "b", set = false, }
  expect_buffer_mark { letter = "b", set = false, row = 2, col = 1, }
  child.type_keys "jl"
  child.lua [[M.toggle_next_local_mark()]]
  expect_sign { letter = "b", set = true, }
  expect_buffer_mark { letter = "b", set = true, row = 2, col = 1, }
end

T["get_next_avail_global_mark"] = function()
  child.lua [[M.setup()]]
  MiniTest.expect.equality("A", child.lua_get [[M.get_next_avail_global_mark()]])

  child.lua [[M.toggle_next_global_mark()]]

  expect_sign { letter = "A", set = true, }
  expect_global_mark { letter = "A", set = true, row = 1, col = 0, basename = "dummy_file_a.txt", }

  MiniTest.expect.equality("B", child.lua_get [[M.get_next_avail_global_mark()]])
end

T["toggle_next_global_mark"] = MiniTest.new_set {
  hooks = { pre_case = function() child.lua [[M.setup()]] end, },
}
T["toggle_next_global_mark"]["toggle a mark when called on a single line"] = function()
  expect_sign { letter = "A", set = false, }
  expect_global_mark { letter = "A", set = false, row = 1, col = 0, basename = "dummy_file_a.txt", }

  child.lua [[M.toggle_next_global_mark()]]

  expect_sign { letter = "A", set = true, }
  expect_global_mark { letter = "A", set = true, row = 1, col = 0, basename = "dummy_file_a.txt", }

  child.lua [[M.toggle_next_global_mark()]]

  expect_sign { letter = "A", set = false, }
  expect_global_mark { letter = "A", set = false, row = 1, col = 0, basename = "dummy_file_a.txt", }
end
T["toggle_next_global_mark"]["replace the current global mark in a single file"] = function()
  child.lua [[M.toggle_next_global_mark()]]
  expect_sign { letter = "A", set = true, }
  expect_global_mark { letter = "A", set = true, row = 1, col = 0, basename = "dummy_file_a.txt", }

  child.type_keys "jl"
  child.lua [[M.toggle_next_global_mark()]]
  expect_sign { letter = "A", set = true, }
  expect_global_mark { letter = "A", set = true, row = 2, col = 1, basename = "dummy_file_a.txt", }
end
T["toggle_next_global_mark"]["add the next available global mark in a group of files"] = function()
  child.lua [[M.toggle_next_global_mark()]]
  expect_sign { letter = "A", set = true, }
  expect_global_mark { letter = "A", set = true, row = 1, col = 0, basename = "dummy_file_a.txt", }

  child.cmd("edit " .. dummy_file_b)

  expect_sign { letter = "B", set = false, }
  expect_global_mark { letter = "B", set = false, row = 2, col = 1, basename = "dummy_file_b.txt", }
  child.type_keys "jl"
  child.lua [[M.toggle_next_global_mark()]]
  expect_sign { letter = "B", set = true, }
  expect_global_mark { letter = "B", set = true, row = 2, col = 1, basename = "dummy_file_b.txt", }
end

T["navigate_buffer_marks"] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.lua [[M.setup()]]

      child.lua [[M.toggle_next_local_mark()]]
      child.type_keys "jl"
      child.lua [[M.toggle_next_local_mark()]]
      child.type_keys "jl"
      child.lua [[M.toggle_next_global_mark()]]
      child.type_keys "gg0"
    end,
  },
}

T["navigate_buffer_marks"]["navigates to the next, prev marks in the buffer"] = function()
  expect_cursor { row = 1, col = 0, }

  child.lua [[M.navigate_buffer_marks { direction = "next" }]]
  expect_cursor { row = 2, col = 1, }

  child.lua [[M.navigate_buffer_marks { direction = "next" }]]
  expect_cursor { row = 3, col = 2, }

  child.lua [[M.navigate_buffer_marks { direction = "next" }]]
  expect_cursor { row = 1, col = 0, }

  child.lua [[M.navigate_buffer_marks { direction = "prev" }]]
  expect_cursor { row = 3, col = 2, }

  child.lua [[M.navigate_buffer_marks { direction = "prev" }]]
  expect_cursor { row = 2, col = 1, }

  child.lua [[M.navigate_buffer_marks { direction = "prev" }]]
  expect_cursor { row = 1, col = 0, }
end
T["navigate_buffer_marks"]["respects opts.navigate_char_set"] = function()
  expect_cursor { row = 1, col = 0, }

  child.lua [[M.navigate_buffer_marks { direction = "next", navigate_char_set = M.char_sets.local_marks }]]
  expect_cursor { row = 2, col = 1, }

  child.lua [[M.navigate_buffer_marks { direction = "next", navigate_char_set = M.char_sets.local_marks }]]
  expect_cursor { row = 1, col = 0, }

  child.lua [[M.navigate_buffer_marks { direction = "prev", navigate_char_set = M.char_sets.local_marks }]]
  expect_cursor { row = 2, col = 1, }

  child.lua [[M.navigate_buffer_marks { direction = "prev", navigate_char_set = M.char_sets.local_marks }]]
  expect_cursor { row = 1, col = 0, }
end

T["navigate_global_marks"] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.lua [[M.setup()]]

      child.lua [[M.toggle_next_global_mark()]]

      child.cmd("edit " .. dummy_file_b)
      child.type_keys "jl"
      child.lua [[M.toggle_next_global_mark()]]

      child.cmd("edit " .. dummy_file_c)
      child.type_keys "jjll"
      child.lua [[M.toggle_next_global_mark()]]

      child.cmd("edit " .. dummy_file_a)
    end,
  },
}
T["navigate_global_marks"]["navigates to the next, prev global marks"] = function()
  expect_cursor { row = 1, col = 0, basename = "dummy_file_a.txt", }

  child.lua [[M.navigate_global_marks { direction = "next" }]]
  expect_cursor { row = 2, col = 1, basename = "dummy_file_b.txt", }

  child.lua [[M.navigate_global_marks { direction = "next" }]]
  expect_cursor { row = 3, col = 2, basename = "dummy_file_c.txt", }

  child.lua [[M.navigate_global_marks { direction = "next" }]]
  expect_cursor { row = 1, col = 0, basename = "dummy_file_a.txt", }

  child.lua [[M.navigate_global_marks { direction = "prev" }]]
  expect_cursor { row = 3, col = 2, basename = "dummy_file_c.txt", }

  child.lua [[M.navigate_global_marks { direction = "prev" }]]
  expect_cursor { row = 2, col = 1, basename = "dummy_file_b.txt", }

  child.lua [[M.navigate_global_marks { direction = "prev" }]]
  expect_cursor { row = 1, col = 0, basename = "dummy_file_a.txt", }
end

T["delete_buffer_marks"] = function()
  child.lua [[M.setup()]]

  child.lua [[M.toggle_next_local_mark()]]
  child.type_keys "j"
  child.lua [[M.toggle_next_local_mark()]]
  child.type_keys "j"
  child.lua [[M.toggle_next_global_mark()]]

  expect_sign { letter = "a", set = true, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }
  expect_sign { letter = "b", set = true, }
  expect_buffer_mark { letter = "b", set = true, row = 2, col = 0, }
  expect_sign { letter = "A", set = true, }
  expect_buffer_mark { letter = "A", set = true, row = 3, col = 0, }

  child.lua [[M.delete_buffer_marks()]]
  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }
  expect_sign { letter = "b", set = false, }
  expect_buffer_mark { letter = "b", set = false, row = 2, col = 0, }
  expect_sign { letter = "A", set = false, }
  expect_buffer_mark { letter = "A", set = false, row = 3, col = 0, }
end

T["setup"] = MiniTest.new_set()
T["setup"]["remap_m"] = MiniTest.new_set()
T["setup"]["remap_m"]["should default to true"] = function()
  child.lua [[M.setup()]]

  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }
  child.type_keys "ma"
  expect_sign { letter = "a", set = true, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }
end
T["setup"]["remap_m"]["should respect false"] = function()
  child.g.marks = { remap_m = false, }
  child.lua [[M.setup()]]

  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }
  child.type_keys "ma"
  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }
end

T["setup"]["highlight_char_set"] = function()
  child.g.marks = { highlight_char_set = "b", }
  child.lua [[M.setup()]]

  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }
  child.type_keys "ma"
  expect_sign { letter = "a", set = false, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }

  child.type_keys "j"

  expect_sign { letter = "b", set = false, }
  expect_buffer_mark { letter = "b", set = false, row = 2, col = 0, }
  child.type_keys "mb"
  expect_sign { letter = "b", set = true, }
  expect_buffer_mark { letter = "b", set = true, row = 2, col = 0, }

  child.type_keys "j"

  expect_sign { letter = "c", set = false, }
  expect_buffer_mark { letter = "c", set = false, row = 2, col = 0, }
  child.type_keys "mc"
  expect_sign { letter = "c", set = false, }
  expect_buffer_mark { letter = "c", set = true, row = 3, col = 0, }
end

T["buffer_marks_to_qf_list"] = function()
  child.lua [[M.setup()]]

  child.type_keys "ma"
  child.type_keys "jl"
  child.type_keys "mb"
  child.type_keys "jl"
  child.type_keys "mA"

  child.lua [[M.buffer_marks_to_qf_list()]]
  local qf_list = child.fn.getqflist()
  expect_qf_list(
    {
      { col = 0, lnum = 1, text = "a|alpha", },
      { col = 1, lnum = 2, text = "b|bravo", },
      { col = 2, lnum = 3, text = "A|charlie", },
    },
    qf_list)
end

T["global_marks_to_qf_list"] = function()
  child.lua [[M.setup()]]

  child.type_keys "mA"
  child.cmd("edit " .. dummy_file_b)
  child.type_keys "jl"
  child.type_keys "mB"
  child.cmd("edit " .. dummy_file_c)
  child.type_keys "jjll"
  child.type_keys "mC"

  child.lua [[M.global_marks_to_qf_list()]]
  local qf_list = child.fn.getqflist()
  expect_qf_list(
    {
      { col = 0, lnum = 1, text = "A|alpha", },
      { col = 1, lnum = 2, text = "B|echo", },
      { col = 2, lnum = 3, text = "C|india", },
    },
    qf_list)
end

return T
