local M = {}
local ui = require("phptools.ui")

-- Configuration
local config = require("phptools").config
local vim_ui_select = config.ui.fzf and ui.fzf_select or vim.ui.select

-- Test pattern regexes for matching test definitions (exported for testing)
M.TEST_PATTERNS = {
  annotation = ".*@test.*",
  method = "public%s+function%s+([%w_]+)",
  function_only = "function%s+([%w_]+)",
  test_prefix = "public%s+function%s+(test[%w_]+)",
  test_function = "function%s+(test[%w_]+)",
  test_call = "test%(['\"]([^'\"]+)['\"]",
  it_block = "it%(['\"]([^'\"]+)['\"]",
}
local TEST_PATTERNS = M.TEST_PATTERNS

-- Test extraction patterns for ripgrep
local TEST_EXTRACTION_PATTERNS = {
  "@test[\\s\\S]*?function\\s+([\\w_]+)",
  "function\\s+(test[\\w_]+)",
  "test\\(['\"]([^'\"]+)['\"]",
  "it\\(['\"]([^'\"]+)['\"]",
}

-- Command templates for different test run modes (exported for testing)
M.COMMAND_TEMPLATES = {
  all = "%s",
  filter = "%s --filter='%s'",
  file = "%s %s",
  parallel = "%s --parallel",
}
local COMMAND_TEMPLATES = M.COMMAND_TEMPLATES

-- Window configuration (exported for testing)
M.WINDOW_CONFIG = {
  width_ratio = 0.7,
  height_ratio = 0.5,
  style = "minimal",
  border = "rounded",
}
local WINDOW_CONFIG = M.WINDOW_CONFIG

M.last_test = {
  type = nil,
  args = nil,
}
local last_test = M.last_test

function M.detect_test_framework()
  return vim.fn.filereadable("./vendor/bin/pest") == 1 and "./vendor/bin/pest" or "./vendor/bin/phpunit"
end

function M.extract_test_name(line)
  -- Try to match each test pattern
  for _, pattern in ipairs({
    "function%s+([%w_]+)",
    "test%(['\"]([^'\"]+)['\"]",
    "it%(['\"]([^'\"]+)['\"]",
  }) do
    local test_name = line:match(pattern)
    if test_name then
      return test_name
    end
  end
  return nil
end

local function get_test_names(callback)
  if not callback then
    return
  end

  vim.schedule(function()
    -- Build ripgrep command with extraction patterns
    local rg_cmd = { "rg", "--multiline", "--multiline-dotall", "-g", "*Test.php" }
    for _, pattern in ipairs(TEST_EXTRACTION_PATTERNS) do
      table.insert(rg_cmd, "-e")
      table.insert(rg_cmd, pattern)
    end
    table.insert(rg_cmd, "tests/")
    table.insert(rg_cmd, "--no-filename")
    table.insert(rg_cmd, "--only-matching")

    vim.fn.jobstart(rg_cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data and #data > 0 then
          local test_names = {}
          for _, line in ipairs(data) do
            local test_name = M.extract_test_name(line)
            if test_name then
              table.insert(test_names, test_name)
            end
          end
          callback(test_names)
        else
          callback({})
        end
      end,
    })
  end)
end

function M.get_nearest_test()
  local current_line = vim.fn.line(".")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  if not lines or #lines == 0 then
    return nil
  end

  -- Walk backwards from current line to find a test
  for i = current_line, 1, -1 do
    local line = lines[i]

    -- Check for @test annotation followed by method definition
    if line:match(TEST_PATTERNS.annotation) and i < #lines then
      local next_line = lines[i + 1]
      local method_name = next_line:match(TEST_PATTERNS.method) or next_line:match(TEST_PATTERNS.function_only)
      if method_name then
        return method_name
      end
    end

    -- Check for test method/function definitions
    local test_name = line:match(TEST_PATTERNS.test_prefix)
      or line:match(TEST_PATTERNS.test_function)
      or line:match(TEST_PATTERNS.test_call)
      or line:match(TEST_PATTERNS.it_block)

    if test_name then
      return test_name
    end
  end
  return nil
end

function M.get_test_command(type, args)
  local template = COMMAND_TEMPLATES[type]
  if not template then
    vim.notify("Invalid test type: " .. tostring(type), vim.log.levels.ERROR)
    return nil
  end

  -- Validate file type tests
  if args and type == "file" then
    if not args:match("Test%.php$") then
      vim.notify("Not a test file. File must end with Test.php", vim.log.levels.WARN)
      return nil
    end
  end

  local base_cmd = M.detect_test_framework()
  if not base_cmd or not vim.fn.filereadable(base_cmd) then
    vim.notify("Test framework not found. Install phpunit or pest.", vim.log.levels.ERROR)
    return nil
  end

  return string.format(template, base_cmd, args or "")
end

function M.run(type, args)
  local command = M.get_test_command(type, args)

  if not command then
    return
  end

  -- Store test info for rerun functionality
  last_test.type = type
  last_test.args = args

  -- Create and setup output buffer with gf navigation
  local win, output_buf = ui.window({ name = "php-test-output" }, M.WINDOW_CONFIG.width_ratio, M.WINDOW_CONFIG.height_ratio, {
    style = M.WINDOW_CONFIG.style,
    border = M.WINDOW_CONFIG.border,
  })

  -- Setup gf (go to file) navigation - additional setup beyond standard output buffer
  vim.api.nvim_set_option_value("path", vim.fn.getcwd() .. "/**", { buf = output_buf })
  vim.api.nvim_set_option_value("suffixesadd", ".php", { buf = output_buf })
  vim.api.nvim_set_option_value("includeexpr", "substitute(v:fname, '\\\\', '/', 'g')", { buf = output_buf })
  local keymap_opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(output_buf, "n", "gf", "<cmd>wincmd gf<CR>", keymap_opts)

  -- Close window on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    pattern = "php-test-output",
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
    once = true,
  })

  -- Start test command and stream output to buffer
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 and vim.api.nvim_buf_is_valid(output_buf) then
        vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and vim.api.nvim_buf_is_valid(output_buf) then
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
    get_test_names(function(test_names)
      if not test_names or #test_names == 0 then
        vim.notify("No tests found", vim.log.levels.WARN)
        return
      end

      vim_ui_select(test_names, {
        prompt = "Select test to run:",
      }, function(choice)
        if choice then
          M.run("filter", choice)
        end
      end)
    end)
  end,

  selected = function()
    local test_files = vim.fn.glob("tests/**/*Test.php", false, true)
    if not test_files or #test_files == 0 then
      vim.notify("No test files found", vim.log.levels.WARN)
      return
    end

    vim_ui_select(test_files, {
      prompt = "Select test file to run:",
      format_item = function(item)
        return vim.fn.fnamemodify(item, ":.")
      end,
    }, function(choice)
      if choice then
        M.run("file", choice)
      end
    end)
  end,

  file = function()
    local file = vim.fn.expand("%:p")
    M.run("file", file)
  end,

  line = function()
    local test_name = M.get_nearest_test()
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
