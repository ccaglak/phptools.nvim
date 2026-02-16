-- GF Components: Nested Blade component navigation
-- Handles finding and opening nested Blade components

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

local PATTERNS = {
  component_tag = "<x%-([a-z0-9%-%.]+)",
  livewire_tag = "<livewire:([a-z0-9%-%.]+)",
}

function M.find_nested_component(component_path)
  if not component_path or component_path == "" then
    return nil
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  -- Convert dot notation to path: forms.input → forms/input.blade.php
  local file_path = component_path:gsub("%.", "/")

  -- Try resources/views/components/ first (Laravel standard)
  local component_file = np(root .. "/resources/views/components/" .. file_path .. ".blade.php")
  if vim.fn.filereadable(component_file) == 1 then
    return component_file
  end

  -- Try globpath in resources/views/components/
  local pattern = "resources/views/components/**/" .. file_path .. ".blade.php"
  local results = vim.fn.globpath(root, pattern, 0, 1)
  if results and #results > 0 then
    return results[1]
  end

  -- Fallback: Search entire project for blade files matching component name
  local pattern = "**/" .. file_path .. ".blade.php"
  local results = vim.fn.globpath(root, pattern, 0, 1)
  if results and #results > 0 then
    return results[1]
  end

  return nil
end

function M.detect_nested_component()
  local line = vim.fn.getline(".")
  local component = line:match(PATTERNS.component_tag)
  if component then
    return component:gsub("%-", ".")  -- kebab-case to dot notation
  end
  local livewire = line:match(PATTERNS.livewire_tag)
  if livewire then
    return livewire:gsub("%-", ".")
  end
  return nil
end

function M.goto_nested_component()
  return gf_utils.handle_navigation(
    M.detect_nested_component,
    M.find_nested_component,
    function(component_path) return "Opened component: " .. component_path end
  )
end

return M
