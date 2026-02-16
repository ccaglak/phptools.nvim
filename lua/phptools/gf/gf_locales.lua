-- GF Locales: Locale file navigation
-- Handles finding and opening Laravel locale/translation files

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

local PATTERNS = {
  trans_fn = "__%(\"?'?([^'\"%)]+)",
  trans_func = "trans%(\"?'?([^'\"%)]+)",
  trans_choice = "trans_choice%(\"?'?([^'\"%)]+)",
}

function M.find_locale_file(key_path)
  if not key_path or key_path == "" then
    return nil
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  -- Split key path: messages.welcome → messages.php
  local parts = {}
  for part in key_path:gmatch("[^.]+") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return nil
  end

  local file_name = parts[1]

  -- Try default locale (en) first
  local locale_file = np(root .. "/resources/lang/en/" .. file_name .. ".php")
  if vim.fn.filereadable(locale_file) == 1 then
    return locale_file
  end

  -- Try globpath in resources/lang/
  local pattern = "resources/lang/**/" .. file_name .. ".php"
  local results = vim.fn.globpath(root, pattern, 0, 1)
  if results and #results > 0 then
    return results[1]
  end

  -- Fallback: Search entire project for locale files
  local pattern = "**/" .. file_name .. ".php"
  local results = vim.fn.globpath(root, pattern, 0, 1)
  if results and #results > 0 then
    return results[1]
  end

  return nil
end

function M.detect_locale_call()
  local line = vim.fn.getline(".")
  return line:match(PATTERNS.trans_fn) or
         line:match(PATTERNS.trans_func) or
         line:match(PATTERNS.trans_choice)
end

function M.goto_locale()
  return gf_utils.handle_navigation(
    M.detect_locale_call,
    M.find_locale_file,
    function(key_path) return "Opened locale file for: " .. key_path end
  )
end

return M
