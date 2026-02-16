-- GF Twigs: Twig template navigation
-- Handles finding and opening twig template files

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path
local rp = gf_utils.relative_path

local PATTERNS = {
  -- Core Twig tags for template composition
  include = [[{%%\s*include%s+['"]([^'"]+)['"]%s*%%}]],
  extends = [[{%%\s*extends%s+['"]([^'"]+)['"]%s*%%}]],
  from = [[{%%\s*from%s+['"]([^'"]+)['"]%s+import]],
  import = [[{%%\s*import%s+['"]([^'"]+)['"]%s+as]],
  embed = [[{%%\s*embed%s+['"]([^'"]+)['"]%s*%%}]],
  use = [[{%%\s*use%s+['"]([^'"]+)['"]%s*%%}]],

  -- Symfony-specific function patterns
  render_controller = [[render%s*%(%s*controller%s*%(%s*['"]([^'":]+):([^'"]+)['"]%s*%)]],
  asset = [[asset%s*%(%s*['"]([^'"]+)['"]%s*%)]],

  -- relative_path() function: relative_path('http://example.com/assets/app.css')
  -- Extracts full path from URL: /assets/app.css
  relative_path = [[relative_path%s*%(%s*['"](https?://[^/]+(/[^'"]*))['"]\s*%)]],

  -- File paths in twig filters: {{ '/path/to/file.txt'|filter_name(...) }}
  file_in_filter = [[['"]([^'"]+\.(?:txt|php|js|css|html|md|json|yaml|xml))['"]%s*\|]],
}

local DIRECTORIES = {
  templates = { "templates", "app/templates", "resources/views" },
}

function M.find_template(template_path)
  if not template_path or template_path == "" then
    return nil
  end

  -- Skip binary and image files
  if gf_utils.is_binary_file(template_path) then
    gf_utils.notify_warn("Cannot navigate to binary file: " .. template_path)
    return nil
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  -- Check if this is a Symfony controller reference (e.g., App\Controller\BlogController)
  if template_path:match("\\") then
    -- It's a fully qualified class name, handle as controller
    local controller_class = template_path:gsub("\\", "/")

    -- Try to find in src directory (Symfony standard)
    local controller_file = np(root .. "/src/" .. controller_class .. ".php")
    if vim.fn.filereadable(controller_file) == 1 then
      return controller_file
    end

    -- Try app directory
    controller_file = np(root .. "/app/" .. controller_class .. ".php")
    if vim.fn.filereadable(controller_file) == 1 then
      return controller_file
    end

    -- Fallback: search project for the class
    local filename = controller_class:match("([^/]+)$")
    if filename then
      local pattern = "**/src/**/" .. filename .. ".php"
      local results = vim.fn.globpath(root, pattern, 0, 1)
      if results and #results > 0 then
        return results[1]
      end
    end

    return nil
  end

  -- Check if this looks like a file path with extension (e.g., /path/to/file.txt)
  if template_path:match("%.[a-z]+$") and template_path:match("^/") then
    -- Treat as absolute path from project root
    local file_path = np(root .. template_path)
    if vim.fn.filereadable(file_path) == 1 then
      return file_path
    end

    -- Try relative to current directory
    file_path = template_path
    if vim.fn.filereadable(file_path) == 1 then
      return file_path
    end

    -- Try from project root without leading slash
    file_path = np(root .. "/" .. template_path)
    if vim.fn.filereadable(file_path) == 1 then
      return file_path
    end
  end

  -- Normalize path: remove leading ./ and trailing extensions if present
  template_path = template_path:gsub("^%./", "")

  -- Try common template directories
  for _, template_dir in ipairs(DIRECTORIES.templates) do
    -- Try with .html.twig extension
    local twig_file = np(root .. "/" .. template_dir .. "/" .. template_path .. ".html.twig")
    if vim.fn.filereadable(twig_file) == 1 then
      return twig_file
    end

    -- Try with .twig extension
    local twig_file_short = np(root .. "/" .. template_dir .. "/" .. template_path .. ".twig")
    if vim.fn.filereadable(twig_file_short) == 1 then
      return twig_file_short
    end

    -- Try exact path (already has extension)
    local exact_file = np(root .. "/" .. template_dir .. "/" .. template_path)
    if vim.fn.filereadable(exact_file) == 1 then
      return exact_file
    end
  end

  -- Fallback: Search entire project for twig file
  local filename = template_path:match("([^/]+)$")
  if filename then
    local pattern = "**/templates/**/" .. filename .. "*"
    local results = vim.fn.globpath(root, pattern, 0, 1)
    if results and #results > 0 then
      return results[1]
    end

    -- Try without templates directory constraint
    pattern = "**/" .. filename .. "*.twig"
    results = vim.fn.globpath(root, pattern, 0, 1)
    if results and #results > 0 then
      return results[1]
    end
  end

  return nil
end

function M.detect_twig_reference()
  local line = vim.fn.getline(".")
  -- Try all twig template patterns first
  local template_ref = line:match(PATTERNS.include) or
                       line:match(PATTERNS.extends) or
                       line:match(PATTERNS.from) or
                       line:match(PATTERNS.import) or
                       line:match(PATTERNS.embed) or
                       line:match(PATTERNS.use)

  if template_ref then
    return template_ref
  end

  -- Try Symfony controller pattern: controller('Namespace\\ClassName:method')
  local controller_ref = line:match(PATTERNS.render_controller)
  if controller_ref then
    return controller_ref
  end

  -- Try asset pattern
  local asset_ref = line:match(PATTERNS.asset)
  if asset_ref then
    return asset_ref
  end

  -- Try relative_path() with URL: relative_path('http://example.com/file.txt')
  local url_filename = line:match(PATTERNS.relative_path)
  if url_filename then
    return url_filename
  end

  -- Try file path in twig filter: {{ '/path/to/file.txt'|filter(...) }}
  local file_in_filter = line:match(PATTERNS.file_in_filter)
  if file_in_filter then
    return file_in_filter
  end

  return nil
end


function M.goto_twig_template()
  return gf_utils.handle_navigation(
    M.detect_twig_reference,
    M.find_template,
    function(template_path) return "Opened twig template: " .. template_path end
  )
end

function M._toTwig(template_path)
  -- Navigate to twig template from path
  if not template_path or template_path == "" then
    gf_utils.notify_warn("No template path provided")
    return false
  end

  local template_file = M.find_template(template_path)
  if template_file and vim.fn.filereadable(template_file) == 1 then
    vim.cmd("edit " .. template_file)
    gf_utils.notify_info("Opened twig template: " .. template_path)
    return true
  else
    gf_utils.notify_warn("Twig template not found: " .. template_path)
    return false
  end
end

function M.get_twig_files(directory)
  -- Get all twig files in a directory
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local search_dir = directory or "templates"

  local twig_files = vim.fn.globpath(root, search_dir .. "/**/*.twig", 0, 1)
  if twig_files and #twig_files > 0 then
    return twig_files
  end
  return {}
end

function M.browse_templates()
  -- Browse and open twig templates
  local twig_files = M.get_twig_files()

  if #twig_files == 0 then
    gf_utils.notify_warn("No twig templates found")
    return false
  end

  -- Use ui.select to pick a template
  vim.ui.select(twig_files, {
    prompt = "Select twig template: ",
    format_item = function(item)
      return rp(item)
    end,
  }, function(choice)
    if choice then
      vim.cmd("edit " .. choice)
      gf_utils.notify_info("Opened twig template")
    end
  end)

  return true
end

return M
