local N = {}

local api = vim.api
local utils = require("phptools.utils")
local ui = require("phptools.ui")


--- Cache for composer.json data
-- @private
local cache = {
  composer_json = nil,
  composer_file = nil,    -- Track file path for invalidation
  composer_mtime = nil,   -- Track modification time for cache invalidation
  prefix_and_src = nil,
}

--- Autoload configuration keys
-- @private
local AUTOLOAD_KEY = "autoload"
local AUTOLOAD_DEV_KEY = "autoload-dev"
local PSR4_KEY = "psr-4"

local sep = utils.get_path_sep()

local function get_root()
  return vim.fs.root(0, _G.PHP_ROOT_MARKERS) or vim.uv.cwd()
end

--- Parse directory path into PHP namespace
-- Converts path segments to PascalCase and joins with backslashes
-- @param str string Directory path (e.g., "app/Models/User")
-- @return string Namespace declaration (e.g., "namespace App\\Models\\User;")
-- @private
local function parse(str)
  local psr = ""
  for match in str:gmatch("[a-zA-Z0-9]+") do
    psr = psr .. match:gsub("^.", string.upper) .. "\\"
  end
  return "namespace " .. psr:sub(1, -2) .. ";"
end

--- Resolve PHP namespace for current directory based on PSR-4 mapping
-- Uses composer.json PSR-4 autoload configuration to determine namespace
-- @param current_dir string|nil Directory to resolve (defaults to current file directory)
-- @return string|nil Namespace declaration (e.g., "namespace App\\Models;") or nil if unmapped
function N.resolve_namespace(current_dir)
  if not current_dir then
    current_dir = vim.fn.expand("%:h")
  end

  local prefix_and_src = N.get_prefix_and_src()
  if not prefix_and_src then
    return nil
  end

  current_dir = current_dir:gsub(get_root(), ""):gsub(sep, "\\"):gsub("%.php$", "")

  for _, entry in ipairs(prefix_and_src) do
    local src_with_backslash = entry.src:gsub(sep, "\\")
    if current_dir:find(src_with_backslash) then
      return parse(current_dir:gsub(src_with_backslash, entry.prefix))
    end
  end
  return nil
end

--- Read and cache composer.json file with invalidation on file changes
-- Caches composer.json content but invalidates if file is modified
-- @return table|nil Parsed composer.json or nil if file not found
function N.read_composer_file()
  local filename = vim.fn.findfile("composer.json", ".;")
  if filename == "" then
    return nil
  end

  -- Check if cache is still valid (same file and not modified)
  local mtime = vim.fn.getftime(filename)
  if cache.composer_json and cache.composer_file == filename and cache.composer_mtime == mtime then
    return cache.composer_json
  end

  -- Cache is stale or doesn't exist, reload file
  local content = vim.fn.readfile(filename)
  cache.composer_json = vim.json.decode(table.concat(content, "\n"))
  cache.composer_file = filename
  cache.composer_mtime = mtime

  -- Invalidate dependent caches
  cache.prefix_and_src = nil

  return cache.composer_json
end

--- Generate PHP use statement for a file based on PSR-4 mapping
-- Resolves the full namespace for a file and generates a use statement
-- @param filepath string Absolute file path
-- @return string|nil Use statement (e.g., "use App\\Models\\User;") or nil if unmapped
function N.generate_use_statement(filepath)
  if not filepath then
    return nil
  end

  local prefix_and_src = N.get_prefix_and_src()
  if not prefix_and_src then
    return nil
  end

  local relative_path = filepath:gsub(get_root(), "")
  relative_path = relative_path:gsub(sep, "\\")
  for _, entry in ipairs(prefix_and_src) do
    if entry.src then
      local src_pattern = entry.src:gsub("\\$", "")  -- Remove trailing separator for matching
      if relative_path:find(src_pattern) then
        local namespace = relative_path:gsub(entry.src, entry.prefix)
        -- Clean up: fix double backslashes and remove .php extension
        namespace = namespace:gsub("\\\\", "\\"):gsub("%.php$", "")
        return "use " .. namespace .. ";"
      end
    end
  end
end

--- Get PSR-4 namespace to source directory mappings from composer.json
-- Extracts PSR-4 prefixes and source directories from both autoload and autoload-dev
-- @return table|nil Array of {prefix, src} mappings or nil if autoload not configured
function N.get_prefix_and_src()
  if cache.prefix_and_src then
    return cache.prefix_and_src
  end

  local composer_data = N.read_composer_file()
  if not composer_data or not composer_data[AUTOLOAD_KEY] then
    return nil
  end

  local result = {}
  local trailing_sep = sep .. "$"

  --- Extract PSR-4 mappings from a table (autoload or autoload-dev)
  -- @param psr4_table table Table with namespace prefix → source directory mappings
  -- @private
  local function add_psr4_mappings(psr4_table)
    if psr4_table then
      for prefix, src in pairs(psr4_table) do
        table.insert(result, {
          prefix = prefix,
          src = src:gsub(trailing_sep, "")  -- Remove trailing separator
        })
      end
    end
  end

  -- Add mappings from main autoload
  add_psr4_mappings(composer_data[AUTOLOAD_KEY][PSR4_KEY])

  -- Add mappings from autoload-dev
  if composer_data[AUTOLOAD_DEV_KEY] then
    add_psr4_mappings(composer_data[AUTOLOAD_DEV_KEY][PSR4_KEY])
  end

  cache.prefix_and_src = result
  return result
end

--- Insert resolved namespace into current buffer
-- Resolves namespace from current directory and inserts at proper location
-- Uses utils.get_insertion_point() to find correct position (after declare, before class)
function N:resolve()
  local ns = N.resolve_namespace()
  if not ns then
    vim.notify("Could not resolve namespace for current directory", vim.log.levels.WARN)
    return
  end

  local insertion_line = utils.get_insertion_point()
  if not insertion_line then
    vim.notify("Could not find insertion point in buffer", vim.log.levels.WARN)
    return
  end

  api.nvim_buf_set_lines(0, insertion_line, insertion_line, false, { ns })
  vim.notify("Namespace inserted", vim.log.levels.INFO)
end

--- List and run Composer scripts from composer.json
-- Displays configured scripts in an interactive menu and executes selected script
-- Shows output in a floating window with real-time streaming
function N:scripts()
  local composer = N.read_composer_file()
  if not composer or not composer.scripts then
    vim.notify("No Composer scripts found in composer.json", vim.log.levels.WARN)
    return
  end

  -- Build task list from scripts
  local tasks = {}
  for key, value in pairs(composer.scripts) do
    table.insert(tasks, {
      name = key,
      description = type(value) == "string" and value or "No description"
    })
  end

  if #tasks == 0 then
    vim.notify("No Composer scripts found in composer.json", vim.log.levels.WARN)
    return
  end

  -- Sort tasks by name for consistent display
  table.sort(tasks, function(a, b) return a.name < b.name end)

  -- Use improved UI selection with better UX
  vim.ui.select(tasks, {
    prompt = "Select Composer script: ",
    format_item = function(item)
      return string.format("%s: %s", item.name, item.description)
    end,
  }, function(selection)
    if not selection then
      return
    end

    local command = "composer " .. selection.name
    vim.notify("Executing: " .. command, vim.log.levels.INFO)

    -- Create output window for command results
    local win, output_buf = ui.window({ name = "composer-output" }, 0.6, 0.8)

    vim.fn.jobstart(command, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data and vim.api.nvim_buf_is_valid(output_buf) then
          vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
        end
      end,
      on_stderr = function(_, data)
        if data and vim.api.nvim_buf_is_valid(output_buf) then
          vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
        end
      end,
      on_exit = function(_, exit_code)
        if vim.api.nvim_buf_is_valid(output_buf) then
          vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, {
            "",
            "Process exited with code: " .. exit_code
          })
        end
      end,
    })
  end)
end

return N
