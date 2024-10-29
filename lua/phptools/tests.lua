local M = {}

-- Patterns
local test_patterns = {
  annotation = ".*@test.*",
  method = "public%s+function%s+([%w_]+)",
  function_only = "function%s+([%w_]+)",
  test_prefix = "public%s+function%s+(test[%w_]+)",
  test_function = "function%s+(test[%w_]+)",
  test_call = "test%(['\"]([^'\"]+)['\"]",
  it_block = "it%(['\"]([^'\"]+)['\"]",
}

local command_templates = {
  all = "%s",
  filter = "%s --filter=%s",
  file = "%s %s",
  parallel = "%s --parallel",
}

local last_test = {
  type = nil,
  args = nil,
}

local function detect_test_framework()
  return vim.fn.filereadable("./vendor/bin/pest") == 1 and "./vendor/bin/pest" or "./vendor/bin/phpunit"
end

local test_cache = {
  names = {},
  timestamps = {},
}

local function get_test_names()
  local test_dir = vim.fn.getcwd() .. "/tests"
  local all_test_names = {}

  local handle = vim.fn.glob(test_dir .. "/**/*Test.php", false, true)
  for _, file in ipairs(handle) do
    local modified = vim.fn.getftime(file)

    -- Check cache validity
    if test_cache.timestamps[file] == modified and test_cache.names[file] then
      vim.list_extend(all_test_names, test_cache.names[file])
    else
      local file_tests = {}
      local content = vim.fn.readfile(file)

      -- Existing test parsing logic here
      for i, line in ipairs(content) do
        if line:match(test_patterns.annotation) and i < #content then
          local next_line = content[i + 1]
          local method_name = next_line:match(test_patterns.method) or next_line:match(test_patterns.function_only)
          if method_name then
            table.insert(file_tests, method_name)
          end
        end

        local test_name = line:match(test_patterns.test_prefix)
          or line:match(test_patterns.test_function)
          or line:match(test_patterns.test_call)
          or line:match(test_patterns.it_block)

        if test_name then
          table.insert(file_tests, test_name)
        end
      end

      -- Update cache
      test_cache.names[file] = file_tests
      test_cache.timestamps[file] = modified
      vim.list_extend(all_test_names, file_tests)
    end
  end

  return all_test_names
end

local function get_nearest_test()
  local current_line = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for i = current_line, 1, -1 do
    local line = lines[i]

    if line:match(test_patterns.annotation) and i < #lines then
      local next_line = lines[i + 1]
      local method_name = next_line:match(test_patterns.method) or next_line:match(test_patterns.function_only)
      if method_name then
        return method_name
      end
    end

    local test_name = line:match(test_patterns.test_prefix)
      or line:match(test_patterns.test_function)
      or line:match(test_patterns.test_call)
      or line:match(test_patterns.it_block)

    if test_name then
      return test_name
    end
  end
  return nil
end

local function get_test_command(type, args)
  local base_cmd = detect_test_framework()
  local template = command_templates[type]
  return template and string.format(template, base_cmd, args or "")
end

function M.run(type, args)
  local command = get_test_command(type, args)
  last_test.type = type
  last_test.args = args

  local output_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(output_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(output_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe")

  local width = math.floor(vim.o.columns * 0.8)
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
  })
end

M.test = {
  all = function()
    M.run("all")
  end,
  filter = function()
    local test_names = get_test_names()
    require("phptools.ui").select(test_names, {
      prompt = "Select test to run:",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if choice then
        M.run("filter", choice)
      end
    end)
  end,
  file = function()
    local file = vim.fn.expand("%:p")
    M.run("file", file)
  end,
  line = function()
    local test_name = get_nearest_test()
    if test_name then
      M.run("filter", test_name)
    else
      vim.notify("No test found near cursor", vim.log.levels.WARN)
    end
  end,
  parallel = function()
    M.run("all", "--parallel")
  end,
  rerun = function()
    if last_test.type then
      M.run(last_test.type, last_test.args)
    else
      vim.notify("No previous test to rerun", vim.log.levels.INFO)
    end
  end,
}

return M
