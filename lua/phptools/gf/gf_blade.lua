-- GF Blade: Blade template navigation
-- Handles Blade directives, components, sections, and template navigation

local M = {}
local utils = require("phptools.utils")
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path
local rp = gf_utils.relative_path

-- ============================================================================
-- Blade Paths
-- ============================================================================

function M.get_paths()
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  return {
    views = np(root .. "/resources/views"),
    components = np(root .. "/resources/views/components"),
    app_components = np(root .. "/app/View/Components"),
  }
end

-- ============================================================================
-- Component Detection
-- ============================================================================

function M.get_component_under_cursor()
  local line = vim.fn.getline(".")
  local component = line:match("</x%-([%w%-%.]+)") or line:match("<x%-([%w%-%.]+)")
  if component then
    return component:gsub("%.", "/")
  end
  local livewire = line:match("@livewire%('([%w%-%.]+)'%)")
  if livewire then
    return livewire:gsub("%.", "/")
  end
  return nil
end

function M.find_component_file(component_name)
  local paths = M.get_paths()
  local studly_name = utils.kebab_to_studly(component_name)
  local possible = {
    np(paths.components .. "/" .. component_name .. ".blade.php"),
    np(paths.views .. "/" .. component_name .. ".blade.php"),
    np(paths.app_components .. "/" .. studly_name .. ".php"),
  }
  for _, file in ipairs(possible) do
    if vim.fn.filereadable(file) == 1 then
      return file
    end
  end

  -- Fallback: glob search in views directory
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local results = vim.fn.globpath(root .. "/resources/views", "**/" .. component_name .. ".blade.php", 0, 1)
  if results and #results > 0 then
    return results[1]
  end

  return nil
end

-- ============================================================================
-- Component Navigation
-- ============================================================================

function M.goto_component()
  local component = M.get_component_under_cursor()
  if not component then
    gf_utils.notify_warn("No component found under cursor")
    return
  end
  local file = M.find_component_file(component)
  if file then
    vim.cmd("edit " .. file)
    gf_utils.notify_info("Opened: " .. rp(file))
  else
    gf_utils.notify_warn("Component file not found: " .. component)
  end
end

function M.list_components()
  local paths = M.get_paths()
  local components = {}
  local handle = io.popen('find "' .. paths.components .. '" -name "*.blade.php" 2>/dev/null')
  if handle then
    for line in handle:lines() do
      local escaped = paths.components:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
      local rel = line:gsub(escaped .. "[/\\]", ""):gsub("%.blade%.php$", "")
      table.insert(components, rel)
    end
    handle:close()
  end
  return components
end

function M.browse_components()
  local components = M.list_components()
  if #components == 0 then
    gf_utils.notify_warn("No Blade components found")
    return
  end
  vim.ui.select(components, { prompt = "Browse Blade components: " }, function(choice)
    local paths = M.get_paths()
    local file = np(paths.components .. "/" .. choice .. ".blade.php")
    if vim.fn.filereadable(file) == 1 then
      vim.cmd("edit " .. file)
    end
  end)
end

-- ============================================================================
-- Blade Template Navigation
-- ============================================================================

function M._toBlade(txt)
  if not txt or txt == "" then
    return
  end
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local parts = utils.split(txt, ".")
  local is_laravel = gf_utils.is_laravel_project()

  -- Try Laravel path first if it's a Laravel project
  if is_laravel then
    local path = root .. "/resources/views"
    for i = 1, #parts - 1 do
      path = path .. "/" .. parts[i]
    end

    local blade_file = np(path .. "/" .. parts[#parts] .. ".blade.php")

    if vim.fn.filereadable(blade_file) == 1 then
      vim.cmd("edit " .. blade_file)
      return
    end
  end

  -- Sitewide search from root
  local search_name = parts[#parts] .. ".blade.php"
  local found_files = {}

  -- Use vim.fn.globpath to find files
  if vim.fn.globpath then
    local glob_result = vim.fn.globpath(root, "**/" .. search_name, 0, 1)
    if glob_result and #glob_result > 0 then
      found_files = glob_result
    end
  end

  -- Fallback to find command if glob didn't work
  if #found_files == 0 then
    local find_cmd = 'find "' .. root .. '" -type f -name "' .. search_name .. '" 2>/dev/null'
    local handle = io.popen(find_cmd)
    if handle then
      local output = handle:read("*a")
      handle:close()

      if output and output ~= "" then
        for line in output:gmatch("[^\n]+") do
          if line ~= "" then
            table.insert(found_files, line)
          end
        end
      end
    end
  end

  if #found_files == 1 then
    vim.cmd("edit " .. found_files[1])
    gf_utils.notify_info("Opened: " .. rp(found_files[1]))
    return
  elseif #found_files > 1 then
    -- Multiple files found, let user choose
    local display_files = {}
    for _, f in ipairs(found_files) do
      table.insert(display_files, rp(f))
    end
    vim.ui.select(display_files, { prompt = "Multiple Blade files found: " }, function(choice)
      local root = gf_utils.get_project_root() or vim.fn.getcwd()
      vim.cmd("edit " .. np(root .. "/" .. choice))
    end)
    return
  end

  gf_utils.notify_warn("Blade file not found: " .. search_name)
end

function M.to_section(section_name)
  if not section_name or section_name == "" then
    gf_utils.notify_warn("No section name provided")
    return
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local is_laravel = gf_utils.is_laravel_project()
  local results = {}

  -- Try Laravel resources path first if it's a Laravel project
  if is_laravel then
    local search_path = np(root .. "/resources")
    if vim.fn.isdirectory(search_path) == 1 then
      results = utils.rg_search("@section%s*%(%s*['\"]" .. section_name, search_path, { list = true }) or {}
    end
  end

  -- If not found, search sitewide from root
  if #results == 0 then
    results = utils.rg_search("@section%s*%(%s*['\"]" .. section_name, root, { list = true }) or {}
  end

  if not results or #results == 0 then
    gf_utils.notify_warn("Section not found: " .. section_name)
    return
  end

  if #results == 1 then
    vim.cmd("edit " .. results[1])
  else
    local display_results = {}
    for _, r in ipairs(results) do
      table.insert(display_results, rp(r))
    end
    vim.ui.select(display_results, { prompt = "Select section: " }, function(choice)
      if choice then
        local root = gf_utils.get_project_root() or vim.fn.getcwd()
        vim.cmd("edit " .. np(root .. "/" .. choice))
      end
    end)
  end
end

return M
