require "mini.test".setup()

local expect = MiniTest.expect
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set()
T["dummy"] = function()
  expect.equality(1, 1)
end

return T
