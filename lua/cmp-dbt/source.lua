-- source is the source of the completion items.
local source = {}

function source:new()
  local cls = {}
  setmetatable(cls, self)
  self.__index = self
  return cls
end

-- TODO:
function source:get_completion()
  return {}
end

function source:get_trigger_characters()
  return { " " }
end

function source:get_debug_name()
  return "cmp-dbt"
end

return source
