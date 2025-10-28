require "mini.test".setup()
local child = MiniTest.new_child_neovim()

local dummy_dir = "dummy_dir"
local dummy_file = vim.fs.joinpath(dummy_dir, "dummy_file.txt")

--- @param row number
--- @param col number
local function get_hl_names(row, col)
  local ns = child.api.nvim_create_namespace "marks.nvim"
  local ext_marks = child.api.nvim_buf_get_extmarks(0, ns, { row - 1, col, }, { row - 1, col, }, { details = true, })
  return vim.tbl_map(function(mark) return mark[4].hl_group end, ext_marks)
end

local expect_hl = MiniTest.new_expectation(
  "hls set",
  --- @class ExpectHlOpts
  --- @field row number
  --- @field col number
  --- @field set boolean
  --- @param opts ExpectHlOpts
  function(opts)
    local hl_names = get_hl_names(opts.row, opts.col)
    if opts.set then
      return hl_names[1] == "MarkCol"
    else
      return vim.tbl_count(hl_names) == 0
    end
  end,
  --- @param opts ExpectHlOpts
  function(opts)
    if opts.set then
      return ("Expected hl to be set at row %s, col %s, was not"):format(opts.row, opts.col)
    else
      return ("Expected hl not to be set at row %s, col %s, was"):format(opts.row, opts.col)
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
    local mark = child.api.nvim_buf_get_mark(0, opts.letter)
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

local expect_sign = MiniTest.new_expectation(
  "sign placed",
  --- @class ExpectSignOpts
  --- @field letter string
  --- @field placed boolean
  --- @param opts ExpectSignOpts
  function(opts)
    if opts.placed then
      local placed_sign = child.fn.sign_getplaced(0, { group = "marks.nvim", })[1].signs[1]
      return placed_sign.name == opts.letter
    else
      local signs = child.fn.sign_getplaced(0, { group = "marks.nvim", })[1].signs
      return not vim.tbl_contains(signs, function(sign)
        return sign.name == opts.letter
      end, { predicate = true, })
    end
  end,
  --- @param opts ExpectSignOpts
  function(opts)
    if opts.placed then
      return ("Expected sign %s to be placed, was not"):format(opts.letter)
    else
      return ("Expected sign %s not to be placed, was"):format(opts.letter)
    end
  end
)

local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      vim.fn.mkdir(dummy_dir)
      vim.fn.writefile({ "alpha", "bravo", "charlie", }, dummy_file)

      child.restart { "-u", "scripts/minimal_init.lua", }
      child.cmd "set signcolumn=yes"
      child.lua [[M = require('marks')]]
      child.lua [[M.setup()]]
      child.cmd("edit " .. dummy_file)
    end,
    post_case = function()
      vim.fn.delete(dummy_dir, "rf")
    end,
    post_once = child.stop,
  },
}

T["toggle_next_local_mark"] = function()
  expect_sign { letter = "a", placed = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }

  child.lua [[M.toggle_next_local_mark()]]

  expect_sign { letter = "a", placed = true, }
  expect_buffer_mark { letter = "a", set = true, row = 1, col = 0, }

  child.lua [[M.toggle_next_local_mark()]]

  expect_sign { letter = "a", placed = false, }
  expect_buffer_mark { letter = "a", set = false, row = 1, col = 0, }

  child.lua [[M.toggle_next_local_mark()]]

  expect_sign { letter = "b", placed = false, }
  expect_buffer_mark { letter = "b", set = false, row = 2, col = 1, }

  child.type_keys "jl"
  expect_sign { letter = "b", placed = false, }
  expect_buffer_mark { letter = "b", set = false, row = 2, col = 1, }
end

return T
