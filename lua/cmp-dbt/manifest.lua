local Path = require("plenary.path")
local context_manager = require("plenary.context_manager")

-- ManifestLoader class definition
local ManifestLoader = {}

-- Constructor for ManifestLoader
function ManifestLoader:new()
  local cls = {
    manifest_cache = {},
    manifest_path = nil,
    last_manifest_timestamp = nil,
    interval_ms = 5000,
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

-- find the dbt_project.yml by traversing upwards
local function find_dbt_project()
  local current_dir = vim.fn.expand("%:p:h")
  local project_path = ""

  -- TODO: support dbt_project.yaml and windows \\ paths
  while current_dir ~= "/" do
    project_path = Path:new(current_dir, "dbt_project.yml"):absolute()
    if vim.fn.filereadable(project_path) == 1 then
      break
    else
      current_dir = Path:new(current_dir):parent():absolute()
    end
  end

  return project_path
end

-- Find the manifest.json within the target folder
local function find_manifest_json(project_path)
  local target_path = Path:new(Path:new(project_path):parent(), "target")
  local manifest_path = Path:new(target_path, "manifest.json"):absolute()

  return manifest_path
end

-- Public method to load the manifest.json asynchronously with caching
function ManifestLoader:load_manifest(callback)
  local project_path = find_dbt_project()

  if project_path == "" then
    -- TODO: convert to debug logging
    vim.notify_once("dbt_project.yml not found!")
    return
  end

  local manifest_path = find_manifest_json(project_path)

  if vim.fn.filereadable(manifest_path) ~= 1 then
    -- TODO: convert to debug logging
    vim.notify_once("manifest.json not found in the target folder!")
    return
  end

  if not self.manifest_cache[manifest_path] or self:manifest_updated(manifest_path) then
    local with = context_manager.with
    local open = context_manager.open

    with(open(manifest_path, "r"), function(f)
      local data = vim.fn.json_decode(f:read())
      self.manifest_cache[manifest_path] = data
      self.manifest_path = manifest_path
      callback(data)
    end)
  end

  callback(self.manifest_cache[manifest_path])
end

-- Check if the manifest file has been updated
function ManifestLoader:manifest_updated(manifest_path)
  local current_timestamp = vim.fn.getftime(manifest_path)
  if not self.last_manifest_timestamp or current_timestamp > self.last_manifest_timestamp then
    self.last_manifest_timestamp = current_timestamp
    return true
  end
  return false
end

-- Poll the manifest.json for changes
function ManifestLoader:cron_manifest(callback)
  local timer = vim.loop.new_timer()
  timer:start(
    self.interval_ms,
    self.interval_ms,
    vim.schedule_wrap(function()
      if self:manifest_updated(self.manifest_path) then
        callback()
      end
    end)
  )
end

return ManifestLoader
