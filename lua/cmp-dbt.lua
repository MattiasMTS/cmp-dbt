local M = {}

function M:setup() end

function M:new()
  local o = require("cmp-dbt.nvim-cmp")
  return o:new()
end

return M
