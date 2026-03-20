-- GF Livewire: Livewire component navigation
-- Handles Livewire component discovery and component/view toggling

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

-- ============================================================================
-- Livewire Paths
-- ============================================================================

function M.get_paths()
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  return {
    components = np(root .. "/app/Livewire"),
    views = np(root .. "/resources/views/livewire"),
  }
end

-- ============================================================================
-- Component Discovery
-- ============================================================================

function M.find_components()
  local paths = M.get_paths()
  local components = {}
  local handle = io.popen('find "' .. paths.components .. '" -name "*.php" 2>/dev/null')
  if handle then
    for line in handle:lines() do
      local escaped = paths.components:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
      local rel = line:gsub(escaped .. "[/\\]", ""):gsub("%.php$", "")
      table.insert(components, rel)
    end
    handle:close()
  end
  return components
end

function M.browse_components()
  local components = M.find_components()
  if #components == 0 then
    gf_utils.notify_warn("No Livewire components found")
    return
  end
  vim.ui.select(components, { prompt = "Browse Livewire components: " }, function(choice)
    local paths = M.get_paths()
    local file = np(paths.components .. "/" .. choice .. ".php")
    if vim.fn.filereadable(file) == 1 then
      vim.cmd("edit " .. file)
    end
  end)
end

-- ============================================================================
-- Component/View Toggle
-- ============================================================================

function M.toggle_files()
  local current = vim.fn.expand("%:p")
  local paths = M.get_paths()

  if current:find(paths.components, 1, true) then
    -- In component file, go to view
    local escaped = paths.components:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local comp_name = current:gsub(escaped .. "[/\\]", ""):gsub("%.php$", "")
    local view_name = comp_name:gsub("%.", "-"):gsub("_", "-"):lower()
    local blade = np(paths.views .. "/" .. view_name .. ".blade.php")
    if vim.fn.filereadable(blade) == 1 then
      vim.cmd("edit " .. blade)
      gf_utils.notify_info("Opened Livewire view")
    else
      gf_utils.notify_warn("Blade view not found")
    end
  elseif current:find(paths.views, 1, true) then
    -- In view file, go to component
    local escaped = paths.views:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local view = current:gsub(escaped .. "[/\\]", ""):gsub("%.blade%.php$", "")
    local comp = view:gsub("%-", "_"):gsub("[/\\]", ".")
    local php = np(paths.components .. "/" .. comp:gsub("%.", "/") .. ".php")
    if vim.fn.filereadable(php) == 1 then
      vim.cmd("edit " .. php)
      gf_utils.notify_info("Opened Livewire component")
    else
      gf_utils.notify_warn("Component not found")
    end
  end
end

-- ============================================================================
-- Livewire Path Resolution
-- ============================================================================

function M.resolve_component_path(component_name)
  if not component_name or component_name == "" then
    return nil
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  local parts = {}
  for part in component_name:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  local class_name = parts[#parts]:gsub("%-", "_"):gsub("(.)", function(c)
    return c:upper()
  end, 1)

  local dirs = {}
  for i = 1, #parts - 1 do
    local part = parts[i]
    table.insert(dirs, part:gsub("(.)", function(c) return c:upper() end, 1))
  end

  local base_path = root .. "/app/Livewire"
  for _, dir in ipairs(dirs) do
    base_path = base_path .. "/" .. dir
  end

  return np(base_path .. "/" .. class_name .. ".php")
end

function M.search_blade_usage(component_name)
  if not component_name or component_name == "" then
    return {}
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local search_path = np(root .. "/resources")

  if vim.fn.isdirectory(search_path) == 0 then
    return {}
  end

  local utils = require("phptools.utils")
  local pattern = "@livewire%('?" .. component_name
  local results = utils.rg_search(pattern, search_path, { list = true })
  return results or {}
end

return M
