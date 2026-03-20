-- Utility functions for phptools and larago
local M = {}

--- Split string by separator
-- @param path string The string to split
-- @param sep string The separator (default: ".")
-- @return table The split parts
function M.split(path, sep)
  sep = sep or "."
  local pattern = string.format("([^%s]+)", sep)
  local parts = {}
  for part in string.gmatch(path, pattern) do
    table.insert(parts, part)
  end
  return parts
end

--- Get OS-specific path separator
-- @return string The path separator ("/" or "\\")
function M.get_path_sep()
  return vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"
end

--- Get LSP position parameters (UTF-16 encoded)
-- @return table Position parameters for LSP requests
function M.make_position_params()
  return vim.lsp.util.make_position_params(nil, "utf-16")
end

--- Get project root with optional markers override
-- @param markers table|nil Custom root markers (default: uses _G.PHP_ROOT_MARKERS or standard markers)
-- @return string Project root path
function M.get_project_root(markers)
  markers = markers or _G.PHP_ROOT_MARKERS or { ".git", "composer.json", ".env" }
  return vim.fs.root(0, markers) or vim.uv.cwd()
end

--- Normalize path - standardizes separators and removes trailing slashes
-- @param path string The path to normalize
-- @return string Normalized path
function M.normalize_path(path)
  if not path then
    return ""
  end
  local sep = M.get_path_sep()
  -- Replace mixed separators with current OS separator
  path = path:gsub("[/\\]", sep)
  -- Remove duplicate separators
  path = path:gsub(sep .. sep, sep)
  -- Remove trailing separator (except for root)
  if path ~= sep then
    path = path:gsub(sep .. "$", "")
  end
  return path
end

--- Get or create a buffer for a file
-- @param filename string The file path
-- @return number Buffer number
function M.get_or_create_buffer(filename)
  if vim.fn.bufexists(filename) ~= 0 then
    return vim.fn.bufnr(filename)
  end
  return vim.fn.bufadd(filename)
end

--- Add lines to a buffer at specified position
-- @param bufnr number The buffer number
-- @param lines table Array of lines to add
-- @param insert_before_last_line boolean Insert before last line (default: true)
-- @param save_buffer boolean Save buffer after insertion (default: false)
function M.add_lines_to_buffer(bufnr, lines, insert_before_last_line, save_buffer)
  if insert_before_last_line == nil then
    insert_before_last_line = true
  end

  -- Load buffer if not already loaded
  if vim.fn.bufloaded(bufnr) == 0 then
    vim.fn.bufload(bufnr)
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local insert_line = insert_before_last_line and (line_count - 1) or line_count

  -- Insert the lines
  vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, lines)

  -- Save buffer if requested
  if save_buffer then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent! write! | silent! edit")
    end)
  end
end

--- Get the insertion point for new declarations (after namespace/declare, before class/use)
-- Scans current buffer for PHP file structure markers
-- @return number Line number for insertion, number offset (0 or column)
function M.get_insertion_point()
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local insertion_point = 2

  for i, line in ipairs(content) do
    if line:match("^declare") then
      insertion_point = i
    elseif line:match("^namespace") then
      return i, 0
    elseif line:match("^use%s") or line:match("^class%s") or line:match("^final%s") or line:match("^interface%s") or line:match("^abstract%s") or line:match("^trait%s") or line:match("^enum%s") then
      return insertion_point
    end
  end

  return insertion_point, nil
end

--- Convert kebab-case to StudlyCase (PascalCase)
-- @param name string The kebab-case name (e.g., "user-profile")
-- @return string The StudlyCase name (e.g., "UserProfile")
function M.kebab_to_studly(name)
  if not name or name == "" then
    return ""
  end

  local parts = M.split(name, "-")
  local result = {}

  for _, part in ipairs(parts) do
    if part ~= "" then
      table.insert(result, part:sub(1, 1):upper() .. part:sub(2))
    end
  end

  return table.concat(result, "")
end

function M.studly_to_kebab(name)
  if not name or name == "" then
    return ""
  end

  local kebab = name:gsub("([a-z])([A-Z])", "%1-%2"):lower()
  return kebab
end

--- Unified ripgrep search with error handling
-- @param pattern string The search pattern
-- @param path string The directory to search in
-- @param opts table Optional ripgrep options (glob, color, etc)
-- @return table List of results or empty table on error
function M.rg_search(pattern, path, opts)
  if not pattern or not path then
    return {}
  end

  opts = opts or {}

  local ok, result = pcall(function()
    local cmd = { "rg" }

    -- Add glob pattern if specified
    if opts.glob then
      table.insert(cmd, "-g")
      table.insert(cmd, opts.glob)
    end

    -- Add other options
    if opts.files then
      table.insert(cmd, "--files")
    end
    if opts.list then
      table.insert(cmd, "-l")
    end
    if opts.color == false then
      table.insert(cmd, "--color=never")
    end

    table.insert(cmd, pattern)
    table.insert(cmd, path)

    local output = vim.system(cmd):wait()

    if output and output.stdout and output.stdout:gsub("%s", "") ~= "" then
      local lines = vim.split(output.stdout, "\n")
      -- Filter out empty lines
      local filtered = {}
      for _, line in ipairs(lines) do
        if line and line:gsub("%s", "") ~= "" then
          table.insert(filtered, line)
        end
      end
      return filtered
    end
    return {}
  end)

  if not ok then
    vim.notify("Ripgrep search error: " .. (result or "unknown error"), vim.log.levels.WARN)
    return {}
  end

  return result or {}
end

--- Open file in editor with optional fallback message
-- @param file_path string The file path to open
-- @param not_found_msg string Optional message if file doesn't exist
function M.open_file(file_path, not_found_msg)
  if not file_path or file_path == "" then
    return false
  end

  if vim.fn.filereadable(file_path) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
    return true
  else
    if not_found_msg then
      vim.notify(not_found_msg, vim.log.levels.INFO)
    end
    return false
  end
end

--- Search for files and prompt user if multiple results
-- @param search_results table List of file paths
-- @param prompt_title string Title for selection prompt
-- @param callback function Callback function called with selected item
function M.select_from_results(search_results, prompt_title, callback)
  if not search_results or #search_results == 0 then
    return
  end

  if #search_results == 1 then
    if callback then
      callback(search_results[1])
    else
      M.open_file(search_results[1])
    end
    return
  end

  -- Multiple results - prompt user
  vim.schedule(function()
    vim.ui.select(search_results, {
      prompt = prompt_title or "Select file: ",
    }, function(item)
      if item then
        if callback then
          callback(item)
        else
          M.open_file(item)
        end
      end
    end)
  end)
end

--- Unified Template Registry for Code Generation
-- Central registry for all code generation templates across phptools modules
M.templates = {
  -- Method/Function templates
  methods = {
    default = "    public function %s()\n    {\n        // TODO: \n    }",
    static = "    public static function %s()\n    {\n        // TODO: \n    }",
    enum_case = "    case %s; // TODO: ",
  },

  -- Control structure templates (for refactoring)
  control_structures = {
    ["if"] = "if (%s) {\n%s\n}",
    ["foreach"] = "foreach (%s as %s) {\n%s\n}",
    ["for"] = "for (%s; %s; %s) {\n%s\n}",
    ["while"] = "while (%s) {\n%s\n}",
    ["do_while"] = "do {\n%s\n} while (%s);",
    ["try_catch"] = "try {\n%s\n} catch (Exception $e) {\n%s\n}",
  },

  -- Function/method definition templates
  definitions = {
    ["function"] = "function %s(%s)\n{\n%s\n}",
    ["method"] = "public function %s(%s)\n{\n%s\n}",
  },

  -- Entity templates (class, interface, trait, enum)
  entities = {
    ["class"] = "class %s\n{\n    //\n}",
    ["interface"] = "interface %s\n{\n    //\n}",
    ["trait"] = "trait %s\n{\n    //\n}",
    ["enum"] = "enum %s\n{\n    //\n}",
    ["abstract"] = "abstract class %s\n{\n    //\n}",
  },

  -- Property hook templates (PHP 8.4)
  hooks = {
    simple_get = "get => $this->%s",
    simple_set = "set($value) => $this->%s = $value",
  },
}

--- Get template by category and name
-- @param category string Template category (methods, control_structures, entities, etc.)
-- @param name string Template name within category
-- @return string|nil The template string or nil if not found
function M.get_template(category, name)
  if not M.templates[category] then
    return nil
  end
  return M.templates[category][name]
end

--- Get all template names in a category
-- @param category string Template category
-- @return table List of template names
function M.get_template_names(category)
  if not M.templates[category] then
    return {}
  end
  return vim.tbl_keys(M.templates[category])
end

--- Query definition from LSP
-- Synchronously requests textDocument/definition from LSP server
-- @param params table LSP position parameters from utils.make_position_params()
-- @param timeout number Optional timeout in milliseconds (default: 1000)
-- @return table Array of definition locations or nil if not found
function M.get_definition(params, timeout)
  timeout = timeout or 1000
  local results = vim.lsp.buf_request_sync(0, "textDocument/definition", params, timeout)

  if results and not vim.tbl_isempty(results) then
    for _, result in pairs(results) do
      if result.result and #result.result > 0 then
        return result.result
      end
    end
  end

  return nil
end

--- Jump to definition location
-- Opens the file and positions cursor at definition
-- @param definition_location table LSP location object with uri and range
-- @return boolean True if successful
function M.jump_to_definition(definition_location)
  if not definition_location then
    return false
  end

  local result = vim.lsp.util.show_document(definition_location, "utf-8")
  return result ~= nil
end

--- Query document symbols from LSP
-- Synchronously requests textDocument/documentSymbol from LSP server
-- @param params table LSP position parameters
-- @param timeout number Optional timeout in milliseconds (default: 5000)
-- @return table Array of document symbols or nil if not found
function M.get_symbols(params, timeout)
  timeout = timeout or 5000
  local results = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, timeout)

  if results and not vim.tbl_isempty(results) then
    for _, response in ipairs(results) do
      if response and response.result then
        return response.result
      end
    end
  end

  return nil
end

--- Flatten nested symbol hierarchy
-- Recursively flattens a tree of symbols into a single array
-- @param symbols table Array of symbol objects (may have children)
-- @param result table Optional accumulator for recursion
-- @return table Flattened array of symbols
function M.flatten_symbols(symbols, result)
  result = result or {}

  for _, symbol in ipairs(symbols) do
    table.insert(result, symbol)
    if symbol.children then
      M.flatten_symbols(symbol.children, result)
    end
  end

  return result
end

--- Find symbol by name and optional kind
-- @param symbols table Array of document symbols (flattened)
-- @param name string Symbol name to search for
-- @param kind number Optional LSP SymbolKind to filter by
-- @return table Symbol object or nil if not found
function M.find_symbol(symbols, name, kind)
  for _, symbol in ipairs(symbols) do
    if symbol.name == name then
      if kind == nil or symbol.kind == kind then
        return symbol
      end
    end
  end
  return nil
end

--- Find all symbols of a specific kind
-- @param symbols table Array of document symbols (flattened)
-- @param kind number LSP SymbolKind to filter by
-- @return table Array of matching symbols
function M.find_symbols_by_kind(symbols, kind)
  local matches = {}

  for _, symbol in ipairs(symbols) do
    if symbol.kind == kind then
      table.insert(matches, symbol)
    end
  end

  return matches
end

--- Generic LSP query for any method with flexible result handling
-- Synchronously requests any LSP method from LSP server
-- @param params table LSP position parameters
-- @param method string LSP method name (e.g., "textDocument/definition")
-- @param timeout number Optional timeout in milliseconds (default: 1000)
-- @return table Raw LSP results or nil if not found
function M.query(params, method, timeout)
  timeout = timeout or 1000
  local results = vim.lsp.buf_request_sync(0, method, params, timeout)

  if results and not vim.tbl_isempty(results) then
    for _, result in pairs(results) do
      if result.result and #result.result > 0 then
        return result.result
      end
    end
  end

  return nil
end

return M
