-- source is the source of the completion items.
local source = {}

-- local utils = require("cmp-dbt.utils")
local ma = require("cmp-dbt.manifest")
local utils = require("cmp-dbt.utils")

function source:new()
  local cls = {
    dbt = ma:new(),
    manifest = {},
    manifest_path = "",
    found_sources = {},
  }
  setmetatable(cls, self)
  self.__index = self

  -- setup cron job to check for manifest changes
  cls.dbt:cron_manifest(function()
    cls:set_manifest()
  end)

  return cls
end

function source:set_manifest()
  self.dbt:load_manifest(function(manifest)
    self.manifest = manifest
    self.manifest_path = self.dbt.manifest_path
  end)
end

-- TODO: continue here to add good documentation for the completion items
local function get_documentation(item)
  if not item then
    return ""
  end

  local ok, parsed = pcall(vim.fn.json_encode, item)
  if ok then
    return parsed
  end
  return ""
end

local function convert_many_to_completion_item(items)
  local out = {}
  for k, v in pairs(items) do
    table.insert(out, {
      label = '"' .. k .. '"',
      kind = vim.lsp.protocol.CompletionItemKind.Text,
      documentation = get_documentation(v),
    })
  end
  return out
end

-- TODO: continue here, add e.g. column completion, macros, test, etc.
function source:get_completion()
  -- local macros = self.manifest.macros or {}
  local cursor_before_line = utils:get_cursor_before_line()

  -- if source is found in the line, then we want to complete for source
  if cursor_before_line:match("source") then
    local cmp_sources = self:completion_for_source(cursor_before_line)
    return convert_many_to_completion_item(cmp_sources)
  end

  -- default to nodes if no other completion is found
  local nodes = self:completion_for_nodes(cursor_before_line)
  return convert_many_to_completion_item(nodes)
end

function source:completion_for_nodes(line)
  local nodes = self.manifest.nodes or {}
  -- local cursor_before_line = line or utils:get_cursor_before_line()

  local out = {}
  for k, v in pairs(nodes) do
    k = k:match("([^.]*)$")
    out[k] = v
  end

  return out
end

function source:completion_for_source(line)
  local sources = self.manifest.sources or {}
  local cursor_before_line = line or utils:get_cursor_before_line()

  -- if we are using e.g. {{ source('source_name', ) }} then we want
  -- to see all the models for that source_name.
  if self.found_sources then
    for f, _ in pairs(self.found_sources) do
      if cursor_before_line:match(f) then
        local out = {}
        for k, v in pairs(sources) do
          if k:match(f) then
            -- captures the last part of the string -> model_name
            k = k:match("([^.]*)$")
            out[k] = v
          end
        end
        return out
      end
    end
  end

  -- if we are using e.g. {{ source('') }} then we want
  -- to see all the sources.
  for k, v in pairs(sources) do
    -- captures the 2nd to last part of the string -> source_name
    k = k:match("([^%.]+)%.[^%.]+$")
    self.found_sources[k] = v
  end
  return self.found_sources
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
