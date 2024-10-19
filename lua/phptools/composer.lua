local N = {}

local api = vim.api

local cache = {
  composer_json = nil,
}

local sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"
local root = vim.fs.root(0, { "composer.json", ".git" }) or vim.uv.cwd()

-- split to remove
local function parse(str)
  local psr = ""
  for match in str:gmatch("[a-zA-Z0-9]+") do
    psr = psr .. match:gsub("^.", string.upper) .. "\\"
  end
  return "namespace " .. psr:sub(1, -2) .. ";"
end

function N.resolve_namespace(current_dir)
  local composer_data = N.read_composer_file()
  if not composer_data then
    return nil
  end

  local prefix_and_src = N.get_prefix_and_src()
  current_dir = current_dir or vim.fn.expand(":h")
  current_dir = vim.fn.fnamemodify(current_dir, ":h")
  current_dir = current_dir:gsub(root, ""):gsub(sep, "\\")

  -- Remove filename and extension

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

function N.generate_use_statement(filepath)
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
      vim.notify("Namespace already exists", "", "warn")
    end
  end
end

function N:scripts()
  local composer = N.read_composer_file()
  if composer == nil or not composer.scripts then
    vim.notify("No Composer scripts found", vim.log.levels.ERROR)
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
    vim.notify("Executing: " .. command, vim.log.levels.INFO)

    local output_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(output_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(output_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_keymap(output_buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.8)
    local win = vim.api.nvim_open_win(output_buf, true, {
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
