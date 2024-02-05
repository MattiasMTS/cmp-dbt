local Path = require("plenary.path")

-- ManifestLoader class definition
local ManifestLoader = {}

-- Constructor for ManifestLoader
function ManifestLoader:new()
  local cls = {
    manifest_cache = {},
  }
  setmetatable(cls, self)
  self.__index = self
  return cls
end

-- find the dbt_project.yml by traversing upwards
local function find_dbt_project()
  local current_dir = vim.fn.expand("%:p:h")
  local project_path = ""

  -- TODO: replace / with os separator and dbt_project.yml with yaml/yml
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

-- Private method to find the manifest.json within the target folder
local function find_manifest_json(project_path)
  local target_path = Path:new(Path:new(project_path):parent(), "target")
  local manifest_path = Path:new(target_path, "manifest.json"):absolute()

  return manifest_path
end

-- Public method to load the manifest.json asynchronously with caching
function ManifestLoader:load_manifest(callback)
  local project_path = find_dbt_project()

  if project_path == "" then
    vim.notify_once("dbt_project.yml not found!")
    return
  end

  local manifest_path = find_manifest_json(project_path)

  if vim.fn.filereadable(manifest_path) ~= 1 then
    vim.notify_once("manifest.json not found in the target folder!")
    return
  end

  if not self.manifest_cache[manifest_path] then
    local ok, data = pcall(vim.fn.json_decode, vim.fn.readfile(manifest_path))
    if ok then
      self.manifest_cache[manifest_path] = data
      callback(data)
    end
  end

  callback(self.manifest_cache[manifest_path])
end

return ManifestLoader
