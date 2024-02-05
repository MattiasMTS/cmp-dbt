-- source is the source of the completion items.
local source = {}

-- local utils = require("cmp-dbt.utils")
local ma = require("cmp-dbt.manifest")

function source:new()
  local cls = {
    dbt = ma:new(),
    manifest = {},
    manifest_path = "",
  }
  setmetatable(cls, self)
  self.__index = self

  -- setup cron job to check for manifest changes
  cls.dbt:cron_manifest(function()
    cls:handle_manifest_setter()
  end)

  return cls
end

function source:handle_manifest_setter()
  self.dbt:load_manifest(function(manifest)
    self.manifest = manifest
    self.manifest_path = self.dbt.manifest_path
  end)
end

-- TODO: continue here to add good documentation for the completion items
local function get_documentation(item)
  local ok, parsed = pcall(vim.fn.json_encode, item)
  if ok then
    return parsed
  end
  return ""
end

local function convert_many_to_completion_item(items)
  local out = {}
  for k, v in pairs(items) do
    -- extract the last part of the model (has to be unique)
    k = k:match("([^.]*)$")
    table.insert(out, {
      label = k,
      kind = vim.lsp.protocol.CompletionItemKind.Text,
      documentation = get_documentation(v),
    })
  end
  return out
end

-- TODO: continue here, add e.g. column completion, macros, test, etc.
function source:get_completion()
  local nodes = self.manifest.nodes or {}
  return convert_many_to_completion_item(nodes)
end

function source:is_available()
  if self.manifest_path == "" then
    self.dbt:load_manifest(function(manifest)
      self.manifest = manifest
      self.manifest_path = self.dbt.manifest_path
    end)
  end

  return self.manifest_path ~= ""
end

function source:get_trigger_characters()
  return { ".", "{", "(", " " }
end

function source:get_debug_name()
  return "cmp-dbt"
end

return source
