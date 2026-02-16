-- GF Functions: Function definition navigation
-- Handles finding and opening function definitions

local M = {}
local gf_utils = require("phptools.gf.gf_utils")

local DIRECTORIES = {
  functions = { "app/Helpers", "app/Functions", "app/Services", "app/Utils", "bootstrap" },
}

function M.find_function(func_name)
  if not func_name or func_name == "" then
    return nil
  end

  local pattern_match = function(line) return line:match("function%s+" .. func_name .. "%s*%(") end

  -- First try app-specific directories
  local file, line_num = gf_utils.search_in_files(pattern_match, DIRECTORIES.functions, "**/*.php")
  if file then
    return file, line_num
  end

  -- If not found locally, search project root (excluding vendor, node_modules, .git)
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  if root then
    local escaped_func = func_name:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")
    -- Use -n flag to get line numbers in format: file:line:content
    -- Exclude vendor, node_modules, .git directories
    local cmd = string.format(
      "rg -n \"function\\s+%s\\s*\\(\" --max-count=1 --color never --glob '!vendor' --glob '!node_modules' --glob '!.git' %s",
      escaped_func,
      vim.fn.shellescape(root)
    )
    local result = vim.fn.systemlist(cmd)
    if result and #result > 0 then
      -- Parse format: /path/to/file.php:123:function content
      local file, line_num = result[1]:match("([^:]+):(%d+):")
      if file and line_num then
        return file, tonumber(line_num)
      end
    end
  end

  -- Fallback: search vendor directory if not found in project root
  if root then
    local escaped_func = func_name:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")
    local cmd = string.format(
      "rg -n \"function\\s+%s\\s*\\(\" --max-count=1 --color never %s/vendor",
      escaped_func,
      vim.fn.shellescape(root)
    )
    local result = vim.fn.systemlist(cmd)
    if result and #result > 0 then
      -- Parse format: /path/to/file.php:123:function content
      local file, line_num = result[1]:match("([^:]+):(%d+):")
      if file and line_num then
        return file, tonumber(line_num)
      end
    end
  end

  return nil
end

function M.detect_function_call()
  local line = vim.fn.getline(".")
  local col = vim.fn.col(".")

  -- Pattern: function_name()
  local func_pattern = line:match("([a-z_][a-z0-9_]*)%s*%(")
  if func_pattern then
    return func_pattern
  end

  -- Helper pattern: helper_function() or custom functions
  local words = {}
  for word in line:gmatch("([a-z_][a-z0-9_]*)") do
    table.insert(words, word)
  end

  if #words > 0 then
    return words[#words]
  end

  return nil
end

function M.goto_function()
  return gf_utils.handle_navigation(
    M.detect_function_call,
    M.find_function,
    function(func_name) return "Found function: " .. func_name end
  )
end

return M
