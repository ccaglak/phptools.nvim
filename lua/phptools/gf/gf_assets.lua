-- GF Assets: Asset file navigation
-- Handles finding and opening asset files (CSS, JS, images, etc.)

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

local PATTERNS = {
  asset_fn = "asset%s*%(%s*['\"]([^'\"]+)['\"]",
  assets_blade = "@assets%s*%(%s*['\"]([^'\"]+)['\"]",
  src_attr = 'src%s*=%s*["\']([^"\']+)["\']',
  href_attr = 'href%s*=%s*["\']([^"\']+)["\']',
  -- Template variable concatenation: href="{{ $var }}path/to/file"
  template_var_concat = 'href%s*=%s*["\']{{%s*.-%s*}}([^"\']+)["\']',
  src_template_var_concat = 'src%s*=%s*["\']{{%s*.-%s*}}([^"\']+)["\']',
  -- Regular asset files (not minified)
  js_file = "%.js$",
  css_file = "%.css$",
  -- Minified assets
  min_js = "%.min%.js$",
  min_css = "%.min%.css$",
}

function M.find_asset(asset_path)
  if not asset_path or asset_path == "" then
    return nil
  end

  -- Skip binary and image files
  if gf_utils.is_binary_file(asset_path) then
    gf_utils.notify_warn("Cannot navigate to binary file: " .. asset_path)
    return nil
  end

  -- Strip query parameters
  asset_path = asset_path:gsub("%?.*", "")

  -- Strip leading ./
  asset_path = asset_path:gsub("^%./", "")

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  -- Check if file is minified and look for source file
  local source_path = asset_path
  if asset_path:match(PATTERNS.min_js) then
    source_path = asset_path:gsub(PATTERNS.min_js, ".js")
  elseif asset_path:match(PATTERNS.min_css) then
    source_path = asset_path:gsub(PATTERNS.min_css, ".css")
  end

  -- Try source file first (if different from original)
  if source_path ~= asset_path then
    -- Try resources directory first
    local source_file = np(root .. "/resources/" .. source_path)
    if vim.fn.filereadable(source_file) == 1 then
      gf_utils.notify_info("Opening source file instead of minified: " .. source_path)
      return source_file
    end

    -- Try public directory
    local public_source = np(root .. "/public/" .. source_path)
    if vim.fn.filereadable(public_source) == 1 then
      gf_utils.notify_info("Opening source file instead of minified: " .. source_path)
      return public_source
    end

    -- Try relative to current file directory
    local current_file = vim.fn.expand("%:p:h")
    local relative_source = np(current_file .. "/" .. source_path)
    if vim.fn.filereadable(relative_source) == 1 then
      gf_utils.notify_info("Opening source file instead of minified: " .. source_path)
      return relative_source
    end

    -- Fallback: Search entire project for source file
    local filename = source_path:match("([^/]+)$")
    if filename then
      local pattern = "**/" .. filename
      local results = vim.fn.globpath(root, pattern, 0, 1)
      if results and #results > 0 then
        gf_utils.notify_info("Opening source file instead of minified: " .. source_path)
        return results[1]
      end
    end
  end

  -- Fall back to original path
  local function try_asset_path(path)
    -- Try resources directory first
    local asset_file = np(root .. "/resources/" .. path)
    if vim.fn.filereadable(asset_file) == 1 then
      return asset_file
    end

    -- Try public directory
    local public_file = np(root .. "/public/" .. path)
    if vim.fn.filereadable(public_file) == 1 then
      return public_file
    end

    -- Try relative to current file directory
    local current_file = vim.fn.expand("%:p:h")
    local relative_file = np(current_file .. "/" .. path)
    if vim.fn.filereadable(relative_file) == 1 then
      return relative_file
    end

    -- Fallback: Search entire project for asset file
    local filename = path:match("([^/]+)$")
    if filename then
      local pattern = "**/" .. filename
      local results = vim.fn.globpath(root, pattern, 0, 1)
      if results and #results > 0 then
        return results[1]
      end
    end

    return nil
  end

  -- Try exact path first
  local result = try_asset_path(asset_path)
  if result then
    return result
  end

  -- If path has no extension, try adding .js and .css extensions
  if not asset_path:match("%.%w+$") then
    -- Try with .js extension
    result = try_asset_path(asset_path .. ".js")
    if result then
      return result
    end

    -- Try with .css extension
    result = try_asset_path(asset_path .. ".css")
    if result then
      return result
    end
  end

  return nil
end

function M.detect_asset_call()
  local line = vim.fn.getline(".")
  -- Try template variable concatenation patterns first (more specific)
  local result = line:match(PATTERNS.template_var_concat) or
                 line:match(PATTERNS.src_template_var_concat)
  if result and result:match("%S") then
    -- Only return if there's actual content after the variable (not just whitespace)
    return result
  end

  -- Fall back to regular patterns
  return line:match(PATTERNS.asset_fn) or
         line:match(PATTERNS.assets_blade) or
         line:match(PATTERNS.src_attr) or
         line:match(PATTERNS.href_attr)
end

function M.goto_asset()
  return gf_utils.handle_navigation(
    M.detect_asset_call,
    M.find_asset,
    function(asset_path) return "Opened asset: " .. asset_path end
  )
end

return M
