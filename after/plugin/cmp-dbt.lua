local ok, cmp = pcall(require, "cmp")
if not ok then
  return
end

cmp.register_source("cmp-dbt", require("cmp-dbt"):new())
