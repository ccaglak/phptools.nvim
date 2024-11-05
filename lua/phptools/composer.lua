local N = {}

local api = vim.api
local notify = require("phptools.notify").notify

local cache = {
  composer_json = nil,
}

local sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"
local root = vim.fs.root(0, { "composer.json", ".git" }) or vim.uv.cwd()

local function normalize_path(path)
  path = path:gsub("[/\\]", sep)
  path = path:gsub(sep .. sep, sep)
  path = path:gsub(sep .. "$", "")
  return path
end

local function is_drupal_project()
  local indicators = {
    normalize_path("/web/core/composer.json"),
    normalize_path("/web/core/lib/Drupal.php"),
  }

  for _, path in ipairs(indicators) do
    if vim.fn.filereadable(root .. path) == 1 then
      return true
    end
  end

  local composer_data = vim.json.decode(vim.fn.join(vim.fn.readfile(root .. sep .. "composer.json"), "\n"))
  if composer_data and composer_data.require then
    for dep, _ in pairs(composer_data.require) do
      if dep:match("^drupal/") or dep == "drupal/core" then
        return true
      end
    end
  end

  return false
end

-- split to remove
local function parse(str)
  local psr = ""
  for match in str:gmatch("[a-zA-Z0-9]+") do
    psr = psr .. match:gsub("^.", string.upper) .. "\\"
  end
  return "namespace " .. psr:sub(1, -2) .. ";"
end

function N.get_prefix_and_src_psr4()
  local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()
  local autoload_file = root .. normalize_path("/vendor/composer/autoload_psr4.php")
  if vim.fn.filereadable(autoload_file) ~= 1 then
    return nil
  end

  local content = vim.fn.readfile(autoload_file)
  local psr4_map = {}

  for _, line in ipairs(content) do
    local prefix, path = line:match("['\"]([^'\"]+)['\"]%s*=>%s*array%(.-['\"]([^'\"]+)['\"]") -- double qoutes

    if prefix and path then
      path = path
      table.insert(psr4_map, {
        prefix = prefix,
        src = path,
      })
    end
  end
  return psr4_map
end

function N.resolve_from_autoload_psr4()
  local psr4_map = N.get_prefix_and_src_psr4()
  if #psr4_map == 0 then
    return
  end

  local root = vim.fs.root(0, { ".git" }) or vim.uv.cwd()

  local current_dir = vim.fn.expand("%:h")
  current_dir = sep .. current_dir:gsub(root, "")

  for _, entry in ipairs(psr4_map or {}) do
    if current_dir:find(entry.src) ~= nil then
      return "namespace "
          .. current_dir:gsub(entry.src, entry.prefix):gsub("\\\\", "\\"):gsub("\\$", ""):gsub(sep, "")
          .. ";"
    end
  end
end

function N.generate_use_statement_psr4(filepath)
  local prefix_and_src = N.get_prefix_and_src_psr4()
  local relative_path = filepath:gsub(root, "")
  relative_path = relative_path:gsub(sep, "\\")
  for _, entry in ipairs(prefix_and_src or {}) do
    if relative_path:find(entry.src) ~= nil then
      local namespace = relative_path:gsub(entry.src, entry.prefix)
      namespace = namespace:gsub("\\\\", "\\"):gsub("%.php$", "")
      return "use " .. namespace:gsub(sep, "") .. ";"
    end
  end

  -- return nil
end

function N.generate_use_statement(filepath)
  if not is_drupal_project() then
    return N.generate_use_statement_composer(filepath)
  else
    return N.generate_use_statement_psr4(filepath)
  end
end

function N.resolve_namespace(current_dir)
  if not is_drupal_project() then
    return N.resolve_namespace_composer(current_dir)
  else
    return N.resolve_from_autoload_psr4()
  end
end

function N.resolve_namespace_composer(current_dir)
  local composer_data = N.read_composer_file()
  if not composer_data then
    return nil
  end

  local prefix_and_src = N.get_prefix_and_src()
  current_dir = current_dir or vim.fn.expand("%:h")
  current_dir = current_dir:gsub(root, ""):gsub(sep, "\\"):gsub(".php$", "")

  for _, entry in ipairs(prefix_and_src or {}) do
    if current_dir:find(entry.src) ~= nil then
      return parse(current_dir:gsub(entry.src, entry.prefix))
    end
  end
end

function N.read_composer_file()
  if cache.composer_json then
    return cache.composer_json
  end

  local filename = vim.fn.findfile("composer.json", ".;")
  if filename == "" then
    return
  end
  local content = vim.fn.readfile(filename)

  cache.composer_json = vim.json.decode(table.concat(content, "\n"))
  return cache.composer_json
end

function N.generate_use_statement_composer(filepath)
  local composer_data = N.read_composer_file()
  if not composer_data then
    return nil
  end

  local prefix_and_src = N.get_prefix_and_src()
  local relative_path = filepath:gsub(root, "")
  relative_path = relative_path:gsub(sep, "\\")
  for _, entry in ipairs(prefix_and_src or {}) do
    if relative_path:find(entry.src:sub(1, -1)) ~= nil then
      local namespace = relative_path:gsub(entry.src, entry.prefix)
      namespace = namespace:gsub("\\\\", "\\"):gsub("%.php$", "")
      return "use " .. namespace:gsub(sep, "") .. ";"
    end
  end

  -- return nil
end

-- Get prefix and src from composer.json
function N.get_prefix_and_src()
  local composer_data = N.read_composer_file()

  if composer_data == nil or composer_data["autoload"] == nil then
    return nil, nil
  end

  local autoload = composer_data["autoload"]
  local result = {}

  if autoload["psr-4"] ~= nil then
    for prefix, src in pairs(autoload["psr-4"]) do
      table.insert(result, { prefix = prefix, src = src:gsub(sep .. "$", "") })
    end
  end

  if composer_data["autoload-dev"]["psr-4"] ~= nil then
    for prefix, src in pairs(composer_data["autoload-dev"]["psr-4"]) do
      table.insert(result, { prefix = prefix, src = src:gsub(sep .. "$", "") })
    end
  end

  return result
end

function N.get_insertion_point()
  local content = api.nvim_buf_get_lines(0, 0, -1, false)
  local insertion_point = 2

  for i, line in ipairs(content) do
    if vim.fn.match(line, "^\\(declare\\)") >= 0 then
      insertion_point = i
    elseif vim.fn.match(line, "^\\(namespace\\)") >= 0 then
      return i, vim.fn.match(line, "^\\(namespace\\)")
    elseif vim.fn.match(line, "^\\(use\\|class\\|final\\|interface\\|abstract\\|trait\\|enum\\)") >= 0 then
      return insertion_point
    end
  end

  return insertion_point, nil
end

function N:resolve()
  local ns = N.resolve_namespace()
  if ns then
    local insertion, ok = N.get_insertion_point()
    if not ok then
      api.nvim_buf_set_lines(0, insertion, insertion, false, { ns })
    else
      notify("Namespace already exists", "", "warn")
    end
  end
end

function N:scripts()
  local composer = N.read_composer_file()
  if composer == nil or not composer.scripts then
    notify("No Composer scripts found", vim.log.levels.ERROR)
    return
  end

  local tasks = {}
  for key, value in pairs(composer.scripts) do
    table.insert(tasks, { name = key, description = type(value) == "string" and value or "No description" })
  end

  vim.ui.select(tasks, {
    prompt = "Run Tasks",
    format_item = function(item)
      return string.format("%s: %s", item.name, item.description)
    end,
  }, function(selection)
    if not selection then
      return
    end

    local command = "composer " .. selection.name
    notify("Executing: " .. command, vim.log.levels.INFO)

    local output_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = output_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = output_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = output_buf })
    vim.api.nvim_buf_set_keymap(output_buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.8)
    vim.api.nvim_open_win(output_buf, true, {
      relative = "editor",
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = "minimal",
      border = "rounded",
    })

    vim.fn.jobstart(command, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
        end
      end,
      on_stderr = function(_, data)
        if data then
          vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
        end
      end,
      on_exit = function(_, exit_code)
        vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, { "", "Process exited with code: " .. exit_code })
      end,
    })
  end)
end

return N
