-- PHP Constant Resolution for goto file
-- Resolves PHP constants, class constants, environment variables, and concatenated paths in require/include statements

local M = {}
local utils = require("phptools.utils")
local np = utils.normalize_path

local const_cache = {}

local env_cache = {}

local config = {
  max_depth = 5,
  excluded_dirs = { "vendor", "node_modules", ".git" },
  custom_constants = {},
}

local function get_project_root()
  return _G.get_php_root()
end

local function parse_env_file(env_path)
  if env_cache[env_path] then
    return env_cache[env_path]
  end

  local env_vars = {}
  if vim.fn.filereadable(env_path) == 0 then
    env_cache[env_path] = env_vars
    return env_vars
  end

  local lines = vim.fn.readfile(env_path)
  for _, line in ipairs(lines) do
    if line:match("^%s*$") or line:match("^%s*#") then
      goto continue
    end

    local key, value = line:match("^%s*([A-Z_][A-Z0-9_]*)%s*=%s*(.+)%s*$")
    if key and value then
      value = value:gsub("^['\"]", ""):gsub("['\"]$", "")
      env_vars[key] = value
    end

    ::continue::
  end

  env_cache[env_path] = env_vars
  return env_vars
end

local function resolve_env_variable(var_name)
  local sys_value = vim.fn.getenv(var_name)
  if sys_value ~= vim.NIL then
    return sys_value
  end

  local root = get_project_root()
  if root then
    local env_path = np(root .. "/.env")
    local env_vars = parse_env_file(env_path)
    if env_vars[var_name] then
      return env_vars[var_name]
    end
  end

  return nil
end

local function find_class_constant(class_name, const_name)
  local cache_key = class_name .. "::" .. const_name
  if const_cache[cache_key] then
    return const_cache[cache_key]
  end

  local root = get_project_root()
  if not root then
    return nil
  end

  local escaped_class = class_name:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")
  local class_search_cmd = string.format(
    "rg -H \"class\\s+%s\" --max-count=1 --color never %s",
    escaped_class,
    vim.fn.shellescape(root)
  )

  local class_result = vim.fn.systemlist(class_search_cmd)
  if not class_result or #class_result == 0 then
    return nil
  end

  local class_file = class_result[1]:match("([^:]+):")
  if not class_file then
    return nil
  end

  local escaped_const = const_name:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")
  local const_search_cmd = string.format(
    "rg -H \"(public\\s+)?const\\s+%s\\s*=\" --max-count=1 --color never %s",
    escaped_const,
    vim.fn.shellescape(class_file)
  )

  local const_result = vim.fn.systemlist(const_search_cmd)
  if not const_result or #const_result == 0 then
    return nil
  end

  local const_line = const_result[1]:match("[^:]+:(.+)") or const_result[1]
  if not const_line then
    return nil
  end

  local value = const_line:match("const%s+" .. escaped_const .. "%s*=%s*['\"]([^'\"]*)['\"]")
  if not value then
    return nil
  end

  const_cache[cache_key] = value
  return value
end

local function find_php_constant(const_name, max_depth, visited)
  max_depth = max_depth or config.max_depth
  visited = visited or {}

  if visited[const_name] then
    vim.notify("Circular constant reference detected: " .. const_name, vim.log.levels.WARN)
    return nil
  end

  if max_depth <= 0 then
    vim.notify("Max recursion depth reached while resolving: " .. const_name, vim.log.levels.WARN)
    return nil
  end

  if const_cache[const_name] then
    return const_cache[const_name]
  end

  if config.custom_constants[const_name] then
    return config.custom_constants[const_name]
  end

  visited[const_name] = true

  local root = get_project_root()
  if not root then
    return nil
  end

  local escaped_name = const_name:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")
  local cmd = string.format(
    "rg -H \"define\\s*\\(\\s*['\\\"]%s['\\\"]\" --max-count=1 --color never %s",
    escaped_name,
    vim.fn.shellescape(root)
  )

  local result = vim.fn.systemlist(cmd)
  if not result or #result == 0 then
    return nil
  end

  local full_line = result[1]
  local const_file, line = full_line:match("([^:]+):(.*)")
  if not line then
    line = full_line
    const_file = nil
  end

  local value = line:match("define%s*%(%s*['\"].-['\"]%s*,%s*(.-)%s*[%);]")
  if not value then
    value = line:match("define%s*%(%s*['\"].-['\"]%s*,%s*([^)]+)")
    if not value then
      return nil
    end
  end

  value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[;%)]$", "")

  if value:match("__DIR__") and const_file then
    local const_dir = vim.fn.fnamemodify(const_file, ":h")
    value = value:gsub("__DIR__", const_dir)
  end

  local nested_const = value:match("([A-Z_][A-Z0-9_]*)%s*%.")
  if nested_const then
    local nested_value = find_php_constant(nested_const, max_depth - 1, visited)
    if nested_value then
      local escaped_pattern = nested_const:gsub("[.^$*+?()-\\[\\]|]", "%%%0")
      local escaped_replacement = nested_value:gsub("%%", "%%%%")
      value = value:gsub(escaped_pattern, escaped_replacement)
    end
  end

  local parts = {}
  for part in value:gmatch("[^%.]+") do
    part = part:gsub("^%s+", ""):gsub("%s+$", "")

    if part:match("^['\"]") then
      part = part:gsub("^['\"]", ""):gsub("['\"]$", "")
      if part ~= "" then
        table.insert(parts, part)
      end
    elseif part ~= "" and part ~= "." then
      if not part:match("^[A-Z_][A-Z0-9_]*$") then
        table.insert(parts, part)
      end
    end
  end

  local result_path = nil
  if #parts > 0 then
    result_path = table.concat(parts, "")
  end

  if result_path then
    const_cache[const_name] = result_path
  end

  return result_path
end

local function build_filepath(base_path, file_path)
  return np(base_path .. "/" .. file_path)
end

local function resolve_and_open_file(filepath)
  filepath = utils.normalize_path(filepath)

  if filepath:match("%.%.") then
    filepath = vim.fn.resolve(filepath)
  end

  if vim.fn.filereadable(filepath) == 1 then
    vim.cmd("normal! m'")
    return utils.open_file(filepath, "File not found: " .. filepath)
  else
    vim.notify("File not found: " .. filepath, vim.log.levels.WARN)
    return false
  end
end

local function find_static_variable(var_name)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local escaped_var = var_name:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")

  for line_num, line in ipairs(lines) do
    if line:match("static%s+%$" .. escaped_var .. "%s*=") then
      local array_lines = { line }
      local is_array = line:match("%[") ~= nil

      if is_array then
        local current_line = line_num
        local next_line = line
        while current_line < #lines and not next_line:match("%]") do
          current_line = current_line + 1
          next_line = lines[current_line]
          if not next_line then
            break
          end
          table.insert(array_lines, next_line)
          if next_line:match("%]") then
            break
          end
        end
      end

      return table.concat(array_lines, " ")
    end
  end

  return nil
end

function M.resolve_php_include()
  local line = vim.api.nvim_get_current_line()

  if line:match("__DIR__") then
    local current_file = vim.fn.expand("%:p")
    local current_dir = vim.fn.fnamemodify(current_file, ":h")

    local dir_concat_pattern = "__DIR__%s*%.%s*['\"]([^'\"]+)['\"]"
    local file_part = line:match(dir_concat_pattern)

    if file_part then
      local filepath = build_filepath(current_dir, file_part)
      resolve_and_open_file(filepath)
    else
      resolve_and_open_file(current_dir)
    end
    return
  end

  if not (line:match("require_once") or line:match("include_once") or
          line:match("require") or line:match("include")) then
    return nil
  end

  local array_var, array_idx = line:match("%$([a-z_][a-z0-9_]*)%s*%[([%w_'\"]+)%]")
  if array_var and array_idx then
    local idx = tonumber(array_idx)
    local is_numeric = idx ~= nil
    local array_key = is_numeric and array_idx or array_idx:gsub("['\"]", "")

    local static_def = find_static_variable(array_var)
    if static_def then
      local array_content = static_def

      local elements = {}
      if is_numeric then
        for const_n, file_p in array_content:gmatch("([A-Z_][A-Z0-9_]*)%s*%.%s*['\"]([^'\"]+)['\"]") do
          table.insert(elements, { const = const_n, file = file_p })
        end
        for path in array_content:gmatch("['\"]([^'\"]+)['\"]") do
          if not array_content:match("[A-Z_][A-Z0-9_]*%s*%.%s*['\"]" .. path:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "%%%1") .. "['\"]") then
            table.insert(elements, { const = nil, file = path })
          end
        end

        if idx < 0 or idx >= #elements then
          vim.notify("Array index out of bounds: $" .. array_var .. "[" .. idx .. "]", vim.log.levels.WARN)
          return
        end

        local const_name = elements[idx + 1].const
        local file_part = elements[idx + 1].file

        if const_name then
          local const_value = find_php_constant(const_name)
          if const_value then
            local filepath = build_filepath(const_value, file_part)
            resolve_and_open_file(filepath)
            return
          end
        else
          local root = get_project_root()
          if root then
            local filepath = np(root .. "/" .. file_part)
            if resolve_and_open_file(filepath) then
              return
            end
          end
        end
        return
      else
        for key, value in array_content:gmatch("['\"]([^'\"]+)['\"]%s*=>%s*['\"]([^'\"]+)['\"]") do
          if key == array_key then
            local root = get_project_root()
            if root then
              local filepath = np(root .. "/" .. value)
              if resolve_and_open_file(filepath) then
                return
              end
            end
            return
          end
        end

        vim.notify("Array key not found: $" .. array_var .. "['" .. array_key .. "']", vim.log.levels.WARN)
        return
      end
    end

    local root = get_project_root()
    if not root then
      vim.notify("Could not find project root", vim.log.levels.WARN)
      return
    end

    local escaped_var = array_var:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "\\%1")
    local cmd = string.format(
      "rg -n '\\$%s\\s*=\\s*\\[' --max-count=1 --color never %s",
      escaped_var,
      vim.fn.shellescape(root)
    )

    local result = vim.fn.systemlist(cmd)
    if not result or #result == 0 then
      vim.notify("Array definition not found: $" .. array_var, vim.log.levels.WARN)
      return
    end

    local array_result = result[1]
    local array_file, array_line_num, array_first_line = array_result:match("([^:]+):(%d+):(.+)")

    if not array_line_num then
      vim.notify("Could not parse array location from: " .. array_result, vim.log.levels.WARN)
      return
    end

    local start_line = tonumber(array_line_num)
    if not start_line then
      vim.notify("Invalid array line number: " .. array_line_num, vim.log.levels.WARN)
      return
    end

    local array_lines = { array_first_line }
    local file_ok, file_lines = pcall(vim.fn.readfile, array_file)

    if file_ok and file_lines then
      local current_line = start_line
      while current_line < start_line + 100 and current_line <= #file_lines do
        current_line = current_line + 1
        local line = file_lines[current_line]
        if not line then
          break
        end
        table.insert(array_lines, line)
        if line:match("%]") then
          break
        end
      end
    end

    local array_content = table.concat(array_lines, " ")

    local elements = {}
    for const_n, file_p in array_content:gmatch("([A-Z_][A-Z0-9_]*)%s*%.%s*['\"]([^'\"]+)['\"]") do
      table.insert(elements, { const = const_n, file = file_p })
    end

    for path in array_content:gmatch("['\"]([^'\"]+)['\"]") do
      if not array_content:match("[A-Z_][A-Z0-9_]*%s*%.%s*['\"]" .. path:gsub("([%^$%(%)%.%*%+%-%?%[%]%\\|])", "%%%1") .. "['\"]") then
        table.insert(elements, { const = nil, file = path })
      end
    end

    if idx < 0 or idx >= #elements then
      if #elements == 0 then
        vim.notify("Array is empty: " .. array_var, vim.log.levels.WARN)
      else
        vim.notify("Array index out of bounds: " .. array_var .. "[" .. idx .. "] (array has " .. #elements .. " elements, valid indices are 0-" .. (#elements - 1) .. ")", vim.log.levels.WARN)
      end
      return
    end

    local const_name = elements[idx + 1].const
    local file_part = elements[idx + 1].file

    if const_name then
      local const_value = find_php_constant(const_name)
      if not const_value then
        vim.notify("Constant not found: " .. const_name, vim.log.levels.WARN)
        return
      end

      local filepath = build_filepath(const_value, file_part)
      resolve_and_open_file(filepath)
      return
    else
      local root = get_project_root()
      if root then
        local filepath = np(root .. "/" .. file_part)
        if resolve_and_open_file(filepath) then
          return
        end
      else
        vim.notify("Could not find project root", vim.log.levels.WARN)
      end
      return
    end
  end

  local class_const_pattern = "([A-Z][a-zA-Z0-9_]*)%s*::%s*([A-Z_][A-Z0-9_]*)%s*%.%s*['\"]([^'\"]+)['\"]"
  local class_name, class_const_name, file_part = line:match(class_const_pattern)

  if class_name and class_const_name then
    local const_value = find_class_constant(class_name, class_const_name)
    if not const_value then
      vim.notify("Class constant not found: " .. class_name .. "::" .. class_const_name, vim.log.levels.WARN)
      return
    end

    local filepath = build_filepath(const_value, file_part)
    resolve_and_open_file(filepath)
    return
  end

  local simple_class_const = "([A-Z][a-zA-Z0-9_]*)%s*::%s*([A-Z_][A-Z0-9_]*)"
  class_name, class_const_name = line:match(simple_class_const)
  if class_name and class_const_name then
    local const_value = find_class_constant(class_name, class_const_name)
    if const_value then
      resolve_and_open_file(const_value)
      return
    end
  end

  local env_var = line:match("getenv%(['\"]([A-Z_][A-Z0-9_]*)['\"]%)")
    or line:match("env%(['\"]([A-Z_][A-Z0-9_]*)['\"]%)")
  if env_var then
    local env_value = resolve_env_variable(env_var)
    if not env_value then
      vim.notify("Environment variable not found: " .. env_var, vim.log.levels.WARN)
      return
    end

    local file_part = line:match("getenv%(['\"][A-Z_][A-Z0-9_]*['\"]%)%s*%.%s*['\"]([^'\"]+)['\"]")
      or line:match("env%(['\"][A-Z_][A-Z0-9_]*['\"]%)%s*%.%s*['\"]([^'\"]+)['\"]")

    if file_part then
      local filepath = build_filepath(env_value, file_part)
      resolve_and_open_file(filepath)
    else
      resolve_and_open_file(env_value)
    end
    return
  end

  local const_pattern = "([A-Z_][A-Z0-9_]*)%s*%.%s*['\"]([^'\"]+)['\"]"
  local const_name, file_part = line:match(const_pattern)

  if not const_name then
    local simple_pattern = "['\"]([^'\"]+)['\"]"
    file_part = line:match(simple_pattern)
    if file_part then
      local root = get_project_root()
      if root then
        local filepath = np(root .. "/" .. file_part)
        if resolve_and_open_file(filepath) then
          return
        end
      else
        vim.notify("Could not find project root", vim.log.levels.WARN)
        return
      end
    end
    vim.notify("No valid file path or constant found. Expected format: require 'path/file' or require CONST . '/path'", vim.log.levels.WARN)
    return
  end

  local const_value = find_php_constant(const_name)
  if not const_value then
    vim.notify("Constant not found: " .. const_name, vim.log.levels.WARN)
    return
  end

  local filepath = build_filepath(const_value, file_part)
  resolve_and_open_file(filepath)
end

return M
