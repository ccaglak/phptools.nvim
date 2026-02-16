-- GF Inertia: Inertia.js component navigation
-- Handles finding and opening Inertia page components from PHP controllers

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

local PATTERNS = {
  inertia_helper = "inertia%s*%(%s*['\"]([^'\"]+)['\"]",
  inertia_render = "Inertia::render%s*%(%s*['\"]([^'\"]+)['\"]",
  route_inertia = "Route::inertia%s*%(%s*['\"][^'\"]*['\"]%s*,%s*['\"]([^'\"]+)['\"]",
}

local EXTENSIONS = { ".vue", ".jsx", ".tsx", ".js", ".ts", ".svelte" }

local function get_page_paths()
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local config_file = np(root .. "/config/inertia.php")

  if vim.fn.filereadable(config_file) == 1 then
    local lines = vim.fn.readfile(config_file)
    local content = table.concat(lines, "\n")
    local page_path = content:match("['\"]page_paths['\"]%s*=>%s*%[%s*resource_path%s*%(%s*['\"]([^'\"]+)['\"]")
    if page_path then
      return { np(root .. "/resources/" .. page_path) }
    end
  end

  return {
    np(root .. "/resources/js/Pages"),
    np(root .. "/resources/js/pages"),
    np(root .. "/resources/pages"),
  }
end

function M.find_inertia_component(component_name)
  if not component_name or component_name == "" then
    return nil
  end

  -- Convert dot notation to slash: Pages.Dashboard → Pages/Dashboard
  local path = component_name:gsub("%.", "/")
  local page_paths = get_page_paths()

  for _, base_path in ipairs(page_paths) do
    -- Try each extension
    for _, ext in ipairs(EXTENSIONS) do
      local file = np(base_path .. "/" .. path .. ext)
      if vim.fn.filereadable(file) == 1 then
        return file
      end
    end

    -- Try as directory with index file
    for _, ext in ipairs(EXTENSIONS) do
      local file = np(base_path .. "/" .. path .. "/index" .. ext)
      if vim.fn.filereadable(file) == 1 then
        return file
      end
    end
  end

  return nil
end

function M.detect_inertia_call()
  local line = vim.fn.getline(".")
  return line:match(PATTERNS.route_inertia)
    or line:match(PATTERNS.inertia_render)
    or line:match(PATTERNS.inertia_helper)
end

function M.goto_inertia()
  return gf_utils.handle_navigation(
    M.detect_inertia_call,
    M.find_inertia_component,
    function(component) return "Opened Inertia component: " .. component end
  )
end

return M
