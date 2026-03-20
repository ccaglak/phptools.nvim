-- GF Utilities: Shared functions for all GF navigation features
-- Provides common patterns for file search, navigation, and notifications

local M = {}
local utils = require("phptools.utils")

-- ============================================================================
-- Configuration & State Management
-- ============================================================================

local config = {
  max_depth = 5,
  excluded_dirs = { "vendor", "node_modules", ".git" },
  custom_constants = {},
  supported_file_types = { "php", "blade", "twig" },  -- File types where gf features are enabled
  blade_patterns = {
    include = [=[@?include%s*%(%s*['"]([^'"]+)['"]%s*%)]=],
    livewire = [=[@?livewire%s*%(%s*['"]([^'"]+)['"]%s*%)]=],
    component = [=[@?component%s*%(%s*['"]([^'"]+)['"]%s*%)]=],
    extends = [=[@?extends%s*%(%s*['"]([^'"]+)['"]%s*%)]=],
    section = [=[@?section%s*%(%s*['"]([^'"]+)['"]%s*%)]=],
    wire = [[wire:(%w+)%s*=%s*"?([^"]*)"?]],
  },
  twig_patterns = {
    include = [[{%%\s*include%s+['"]([^'"]+)['"]%s*%%}]],
    extends = [[{%%\s*extends%s+['"]([^'"]+)['"]%s*%%}]],
    from = [[{%%\s*from%s+['"]([^'"]+)['"]%s+import]],
    import = [[{%%\s*import%s+['"]([^'"]+)['"]%s+as]],
    embed = [[{%%\s*embed%s+['"]([^'"]+)['"]%s*%%}]],
  },
  cache = {
    blade_parser_available = nil,
  },
}

-- ============================================================================
-- Notification Helpers
-- ============================================================================

function M.normalize_path(path)
  return utils.normalize_path(path)
end

function M.relative_path(path)
  if not path or path == "" then
    return path
  end
  local root = M.get_project_root()
  if root then
    local escaped = root:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    path = path:gsub("^" .. escaped .. "[/\\]?", "")
  end
  return path
end

function M.notify_info(msg)
  vim.notify(msg, vim.log.levels.INFO, { title = "GF" })
end

function M.notify_warn(msg)
  vim.notify(msg, vim.log.levels.WARN, { title = "GF" })
end

function M.notify_error(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "GF" })
end

-- ============================================================================
-- Project Detection & Root Helpers
-- ============================================================================

function M.get_project_root()
  return _G.get_php_root()
end

function M.is_laravel_project()
  local root = M.get_project_root()
  if not root then
    return false
  end

  local np = M.normalize_path
  -- Primary check: artisan file
  local artisan_file = np(root .. "/artisan")
  if vim.fn.filereadable(artisan_file) == 1 then
    return true
  end

  -- Fallback checks for Laravel indicators
  local composer_file = np(root .. "/composer.json")
  if vim.fn.filereadable(composer_file) == 1 then
    local content = vim.fn.readfile(composer_file)
    local composer_str = table.concat(content, "\n")
    if composer_str:match("laravel/framework") or composer_str:match("laravel/laravel") then
      return true
    end
  end

  -- Check for Laravel directory structure
  if vim.fn.isdirectory(np(root .. "/resources/views")) == 1 and
     vim.fn.isdirectory(np(root .. "/app/Http/Controllers")) == 1 then
    return true
  end

  return false
end

-- ============================================================================
-- File Search & Navigation Utilities
-- ============================================================================

-- Universal file search: tries multiple locations with fallback to project root
function M.search_file(primary_pattern, fallback_pattern)
  local root = M.get_project_root() or vim.fn.getcwd()

  -- Try primary pattern (Laravel-specific directory)
  if primary_pattern then
    local results = vim.fn.globpath(root, primary_pattern, 0, 1)
    if results and #results > 0 then
      return results[1]
    end
  end

  -- Try fallback pattern (project root search)
  if fallback_pattern then
    local results = vim.fn.globpath(root, fallback_pattern, 0, 1)
    if results and #results > 0 then
      return results[1]
    end
  end

  return nil
end

-- Navigate to file and position cursor (optionally at specific line)
function M.goto_file(file, line_num, message)
  if not file then
    return false
  end

  vim.cmd("edit " .. file)
  if line_num then
    vim.api.nvim_win_set_cursor(0, { line_num, 0 })
  end

  if message then
    M.notify_info(message)
  end

  return true
end

-- Generic feature handler: detect, find, navigate pattern
function M.handle_navigation(detect_fn, find_fn, message_fn)
  local item = detect_fn()
  if not item then
    return false
  end

  local file, line_num = find_fn(item)
  if file then
    M.goto_file(file, line_num, message_fn(item))
    return true
  end

  return false
end

-- Search for pattern in PHP files across directories
function M.search_in_files(pattern_match, search_dirs, fallback_glob)
  local root = M.get_project_root() or vim.fn.getcwd()

  -- Try specific directories first
  for _, dir in ipairs(search_dirs or {}) do
    local glob_pattern = dir .. "/**/*.php"
    local results = vim.fn.globpath(root, glob_pattern, 0, 1)

    if results then
      for _, file in ipairs(results) do
        local content = vim.fn.readfile(file)
        for line_num, line_content in ipairs(content) do
          if pattern_match(line_content) then
            return file, line_num
          end
        end
      end
    end
  end

  -- Fallback: Search entire project
  if fallback_glob then
    local results = vim.fn.globpath(root, fallback_glob, 0, 1)
    if results then
      for _, file in ipairs(results) do
        if file:match("vendor") == nil then  -- Skip vendor
          local content = vim.fn.readfile(file)
          for line_num, line_content in ipairs(content) do
            if pattern_match(line_content) then
              return file, line_num
            end
          end
        end
      end
    end
  end

  return nil
end

-- Build a filepath by joining base_path and file_path intelligently
function M.build_filepath(base_path, file_path)
  return M.normalize_path(base_path .. "/" .. file_path)
end

-- Normalize, resolve, and open a file
function M.resolve_and_open_file(filepath)
  filepath = utils.normalize_path(filepath)

  -- Try to resolve relative paths (..)
  if filepath:match("%.%.") then
    filepath = vim.fn.resolve(filepath)
  end

  if vim.fn.filereadable(filepath) == 1 then
    vim.cmd("normal! m'")
    return utils.open_file(filepath)
  else
    M.notify_warn("File not found: " .. M.relative_path(filepath))
    return false
  end
end

-- ============================================================================
-- Configuration Accessors
-- ============================================================================

function M.get_config()
  return config
end

function M.set_config(user_config)
  if user_config then
    if user_config.max_depth then
      config.max_depth = user_config.max_depth
    end
    if user_config.excluded_dirs then
      config.excluded_dirs = user_config.excluded_dirs
    end
    if user_config.custom_constants then
      for const_name, const_value in pairs(user_config.custom_constants) do
        config.custom_constants[const_name] = const_value
      end
    end
    if user_config.supported_file_types then
      config.supported_file_types = user_config.supported_file_types
    end
  end
end

function M.is_supported_file_type(file_type)
  -- Check if the given file type is in the supported list
  for _, supported_type in ipairs(config.supported_file_types) do
    if file_type == supported_type then
      return true
    end
  end
  return false
end

function M.get_blade_patterns()
  return config.blade_patterns
end

function M.get_twig_patterns()
  return config.twig_patterns
end

-- ============================================================================
-- PHP Class Name Detection
-- ============================================================================

function M.detect_php_class_name()
  -- Detect fully qualified PHP class names like App\Controller\ProductController
  -- Matches patterns in various contexts: comments, strings, abbr tags, etc.
  local line = vim.fn.getline(".")

  -- Match fully qualified class names: Namespace\Class or App\Controller\ClassName
  -- Supports escaped backslashes (\\) and regular backslashes (\)
  local class_name = line:match("([A-Z][A-Za-z0-9]*\\\\[A-Z][A-Za-z0-9\\]*)")

  if not class_name then
    -- Try with regular backslashes
    class_name = line:match("([A-Z][A-Za-z0-9]*\\[A-Z][A-Za-z0-9\\]*)")
  end

  if not class_name then
    -- Try more permissive pattern for abbr titles and other contexts
    class_name = line:match('title="([^"]*\\[^"]*)"') or
                line:match("title='([^']*\\[^']*)'")
  end

  return class_name
end

-- ============================================================================
-- Binary File Detection
-- ============================================================================

local BINARY_EXTENSIONS = {
  "webp", "jpg", "jpeg", "png", "gif", "bmp", "ico", "svg", "tiff",
  "pdf", "zip", "tar", "gz", "rar", "7z", "exe", "bin", "dll", "so",
  "dylib", "o", "a", "lib", "class", "pyc", "pyo", "jar", "war", "ear",
  "woff", "woff2", "ttf", "otf", "eot", "mp3", "mp4", "avi", "mov", "flv",
  "wav", "flac", "aac", "m4a", "ogg", "iso", "dmg", "app",
}

function M.is_binary_file(filepath)
  -- Check if file has a binary extension
  if not filepath or filepath == "" then
    return false
  end

  local ext = filepath:match("%.([^%.]+)$")
  if not ext then
    return false
  end

  ext = ext:lower()
  for _, binary_ext in ipairs(BINARY_EXTENSIONS) do
    if ext == binary_ext then
      return true
    end
  end

  return false
end

function M.find_php_class_file(class_name)
  -- Find a PHP class file from fully qualified class name
  if not class_name or class_name == "" then
    return nil
  end

  -- Convert namespace to file path: App\Controller\BlogController -> App/Controller/BlogController
  local class_path = class_name:gsub("\\", "/")
  local root = M.get_project_root() or vim.fn.getcwd()
  local np = M.normalize_path

  -- Try to find in src directory (Symfony standard)
  local class_file = np(root .. "/src/" .. class_path .. ".php")
  if vim.fn.filereadable(class_file) == 1 then
    return class_file
  end

  -- Try app directory
  class_file = np(root .. "/app/" .. class_path .. ".php")
  if vim.fn.filereadable(class_file) == 1 then
    return class_file
  end

  -- Fallback: search project for the class
  local filename = class_path:match("([^/]+)$")
  if filename then
    local pattern = "**/src/**/" .. filename .. ".php"
    local results = vim.fn.globpath(root, pattern, 0, 1)
    if results and #results > 0 then
      return results[1]
    end
  end

  return nil
end

-- ============================================================================
-- Blade Parser Detection
-- ============================================================================

function M.has_blade_parser()
  if config.cache.blade_parser_available ~= nil then
    return config.cache.blade_parser_available
  end
  local ok = pcall(function()
    vim.treesitter.language.add("blade")
  end)
  config.cache.blade_parser_available = ok
  return ok
end

return M
