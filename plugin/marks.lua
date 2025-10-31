local skip_setup = (function()
  if vim.g.marks == nil then return false end
  if vim.g.marks.skip_setup == nil then return false end
  return vim.g.marks.skip_setup
end)()

if skip_setup then return end
require "marks".setup()
