-- source is the source of the completion items.
local source = {}

local utils = require("cmp-dbt.utils")

function source:new()
  local cls = {
    dbt = require("cmp-dbt.dbt"):new(),
    manifest = {},
  }
  setmetatable(cls, self)
  self.__index = self

  cls:set_manifest_async()
  return cls
end

function source:set_manifest_async()
  local timeout_ms = 1000
  vim.defer_fn(function()
    self.dbt:load_manifest(function(manifest)
      self.manifest = manifest
    end)
  end, timeout_ms)
end

function source:get_completion()
  local cursor_before_line = utils:get_cursor_before_line()

  return {}
end

function source:is_available()
  return true
end

function source:get_trigger_characters()
  return { ".", "{", " " }
end

function source:get_debug_name()
  return "cmp-dbt"
end

return source
