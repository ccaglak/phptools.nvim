local ui = require("phptools").config.ui.enable

if ui then
  vim.ui.select = require("phptools.ui").select
end

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
  filter = "%s --filter='%s'",
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

local function get_test_names(callback)
  vim.schedule(function()
    vim.fn.jobstart({
      "rg",
      "--multiline",
      "--multiline-dotall",
      "-g",
      "*Test.php",
      "-e",
      "@test[\\s\\S]*?function\\s+([\\w_]+)",
      "-e",
      "function\\s+(test[\\w_]+)",
      "-e",
      "test\\(['\"]([^'\"]+)['\"]",
      "-e",
      "it\\(['\"]([^'\"]+)['\"]",
      "tests/",
      "--no-filename",
      "--only-matching",
    }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          local test_names = {}
          for _, line in ipairs(data) do
            local test_name = line:match("function%s+([%w_]+)")
              or line:match("test%(['\"]([^'\"]+)['\"]")
              or line:match("it%(['\"]([^'\"]+)['\"]")

            if test_name then
              table.insert(test_names, test_name)
            end
          end
          callback(test_names)
        end
      end,
    })
  end)
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
  if args and type == "file" then
    if not string.match(args, "Test%.php$") then
      vim.notify("Not a test file. File must end with Test.php", vim.log.levels.WARN)
      return nil
    end
  end
  local template = command_templates[type]
  return template and string.format(template, base_cmd, args or "")
end

function M.run(type, args)
  local command = get_test_command(type, args)

  if not command then
    return
  end

  last_test.type = type
  last_test.args = args

  local output_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(output_buf, "php-test-output")
  vim.api.nvim_buf_set_option(output_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(output_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(output_buf, "bufhidden", "wipe")

  vim.api.nvim_buf_set_keymap(output_buf, "n", "q", "<cmd>q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(output_buf, "n", "<Esc>", "<cmd>q<CR>", { noremap = true, silent = true })

  -- gf
  vim.api.nvim_buf_set_option(output_buf, "path", vim.fn.getcwd() .. "/**")
  vim.api.nvim_buf_set_option(output_buf, "suffixesadd", ".php")
  vim.api.nvim_buf_set_option(output_buf, "includeexpr", "substitute(v:fname, '\\\\', '/', 'g')")
  vim.api.nvim_buf_set_keymap(output_buf, "n", "gf", "<cmd>wincmd gf<CR>", { noremap = true, silent = true })
  -- gf

  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.5)
  local win = vim.api.nvim_open_win(output_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    pattern = "php-test-output",
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
    once = true,
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
    get_test_names(function(test_names)
      vim.ui.select(test_names, {
        prompt = "Select test to run:",
        format_item = function(item)
          return item
        end,
      }, function(choice)
        if choice then
          M.run("filter", choice)
        end
      end)
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
