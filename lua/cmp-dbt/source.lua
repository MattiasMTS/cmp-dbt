-- source is the source of the completion items.
local source = {}

local ma = require("cmp-dbt.manifest")
local constants = require("cmp-dbt.constants")
local queries = require("cmp-dbt.queries")
local utils = require("cmp-dbt.utils")

function source:new()
  local cls = {
    dbt = ma:new(),
    querier = queries:new(),
    manifest = {},
    manifest_path = "",
    found_sources = {},
    enable_reserved_keywords = false, -- TODO: add from config later
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
  for m, desc in pairs(items) do
    -- TODO: add more metadata to the cmp menu,
    -- e.g. kind being "cte", "model", "source", "macro", etc.
    table.insert(out, {
      label = m,
      documentation = get_documentation(desc),
    })
  end
  return out
end

-- TODO: continue here, add e.g. column completion, macros, test, etc.
function source:get_completion()
  local out = {}
  local cursor_before_line = utils:get_cursor_before_line()

  local cte_references = self.querier:get_cte_references()
  if cte_references then
    utils:merge_tables(out, cte_references)
  end

  -- if macro keyword found

  -- reserved keywords
  if self.enable_reserved_keywords then
    for _, keyword in pairs(constants.reserved_sql_keywords) do
      out[keyword.name] = { type = keyword.type, description = keyword.description }
    end
  end

  -- if source keyword found
  -- -> suggest models from sources
  if cursor_before_line:match("source") then
    local cmp_sources = self:completion_for_source(cursor_before_line)
    return convert_many_to_completion_item(cmp_sources)
  end

  local nodes = self:completion_for_nodes()
  if nodes then
    utils:merge_tables(out, nodes)
  end

  return convert_many_to_completion_item(out)
end

function source:completion_for_nodes()
  local nodes = self.manifest.nodes or {}

  local out = {}
  for model, meta in pairs(nodes) do
    -- skip tests, just a bunch of hashes
    if model:match("test") then
    else
      -- captures the last part of the string -> model_name
      model = model:match("([^.]*)$")
      out[model] = meta
    end
  end

  return out
end

function source:completion_for_macros(line)
  local macros = self.manifest.macros or {}
  local cursor_before_line = line or utils:get_cursor_before_line()

  local out = {}
  for model, meta in pairs(macros) do
    model = model:match("([^.]*)$")
    out[model] = meta
  end
  return out
end

function source:completion_for_source(line)
  local sources = self.manifest.sources or {}
  local cursor_before_line = line or utils:get_cursor_before_line()

  -- if we are using e.g. {{ source('source_name', ) }} then we want
  -- to see all the models for that source_name.
  if self.found_sources then
    for found_source, _ in pairs(self.found_sources) do
      if cursor_before_line:match(found_source) then
        local out = {}
        for model, meta in pairs(sources) do
          if model:match(found_source) then
            -- captures the last part of the string -> model_name
            model = model:match("([^.]*)$")
            out[model] = meta
          end
        end
        return out
      end
    end
  end

  -- if we are using e.g. {{ source('') }} then we want
  -- to see all the sources.
  for model, meta in pairs(sources) do
    -- captures the 2nd to last part of the string -> source_name
    model = model:match("([^%.]+)%.[^%.]+$")
    self.found_sources[model] = meta
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
  return { ".", "{", "(", '"' }
end

function source:get_debug_name()
  return "cmp-dbt"
end

return source
