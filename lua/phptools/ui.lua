--[[
================================================================================
                           PHPTOOLS UI MODULE
================================================================================
Provides Neovim UI primitives: floating windows, selection menus, input dialogs,
and notifications
Features:
- Centered floating windows with customizable size and styling
- Interactive selection menu (norm_select) with keyboard navigation
- Text input dialog with optional default value
- FZF-based fuzzy selection (if fzf available)
- Output buffer creation for command results
- Color-coded notifications with auto-dismissal
================================================================================
]]

local api = vim.api
local fn = vim.fn

local M = {}

--- Default window configuration constants
-- @private
local DEFAULT_WINDOW_CONFIG = {
  style = "minimal",
  border = "rounded",
  relative = "editor",
}

--- Default UI sizes
-- @private
local DEFAULT_SIZES = {
  select_width = 60,
  select_item_height = 1,
  input_min_width = 40,
}

--- Highlight level mappings for notification styling
-- @private
local NOTIFY_HIGHLIGHTS = {
  [vim.log.levels.ERROR] = "NotifyError",
  [vim.log.levels.INFO] = "NotifyInfo",
  [vim.log.levels.WARN] = "NotifyWarn",
}

--- Default notification configuration constants
-- @private
local NOTIFY_DEFAULTS = {
  timeout = 3000,
  border = "none",
  position = "SE",
  style = "minimal",
}

--- Create popup window configuration for notifications
-- Helper to build window options with proper positioning
-- @param width number Width of notification window
-- @param height number Height of notification window
-- @param offset number Vertical offset from bottom
-- @param opts table Configuration options (position, style, border)
-- @return table Window configuration for nvim_open_win
-- @private
local function make_popup_opts(width, height, offset, opts)
  return {
    relative = "editor",
    anchor = opts.position or NOTIFY_DEFAULTS.position,
    width = width,
    height = height,
    row = vim.o.lines - offset,
    col = vim.o.columns,
    style = opts.style or NOTIFY_DEFAULTS.style,
    border = opts.border or NOTIFY_DEFAULTS.border,
  }
end

--- Display a notification popup in the SE corner
-- Creates a temporary floating window with colored message text
-- Auto-closes after configured timeout
-- @param msg string Message text (supports newlines for multi-line messages)
-- @param level number Notification level (vim.log.levels.ERROR/INFO/WARN)
-- @param opts table|nil Optional configuration {timeout, border, position, style, winhl}
-- @return number|nil Buffer ID of notification, or nil if message is empty
function M.notify(msg, level, opts)
  if not msg then
    return
  end
  level = level or vim.log.levels.INFO
  opts = opts or {}

  local lines = vim.split(msg, "\n")
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate max line width for proper window sizing
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end
  max_width = math.min(max_width, 80) -- Cap at 80 chars for readability

  local win = api.nvim_open_win(buf, false, make_popup_opts(max_width, #lines, 1, opts))

  local ns = api.nvim_create_namespace("phptools_notify")
  vim.hl.range(buf, ns, NOTIFY_HIGHLIGHTS[level] or "NotifyInfo", { 0, 0 }, { -1, 0 })
  api.nvim_set_option_value("winhl", opts.winhl or "Normal:Normal", { win = win })

  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
      api.nvim_buf_delete(buf, { force = true })
    end
  end, opts.timeout or NOTIFY_DEFAULTS.timeout)

  return buf
end

--- Setup module: Replace Neovim's default vim.ui implementations
-- Integrates phptools UI functions as system-wide handlers
function M.setup()
  vim.ui.select = M.norm_select
  vim.ui.input = M.input
  vim.notify = M.notify
end

--- Create a centered floating window with common configuration
-- Abstracts repetitive window positioning and styling
-- @param buf number Buffer number to display
-- @param width_ratio number Width as fraction of viewport (e.g., 0.7 = 70%)
-- @param height_ratio number Height as fraction of viewport (e.g., 0.5 = 50%)
-- @param opts table|nil Optional window styling (style, border, title, etc.)
-- @return number Window ID, or nil if creation failed
-- @private
local function create_window(buf, width_ratio, height_ratio, opts)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end

  opts = opts or {}
  width_ratio = math.min(width_ratio or 0.7, 1.0)  -- Clamp to max 100%
  height_ratio = math.min(height_ratio or 0.5, 1.0)

  local width = math.floor(vim.o.columns * width_ratio)
  local height = math.floor(vim.o.lines * height_ratio)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Merge with defaults
  local win_config = vim.tbl_extend("force", DEFAULT_WINDOW_CONFIG, {
    relative = opts.relative or "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = opts.style,
    border = opts.border,
    title = opts.title,
    title_pos = opts.title_pos,
  })

  local ok, win = pcall(function()
    return api.nvim_open_win(buf, true, win_config)
  end)

  if ok and win then
    return win
  end
  return nil
end

--- Setup output buffer with standard options and keymaps
-- Used for command output, test results, and logging
-- @param buf number Buffer number to configure
-- @param opts table|nil Configuration options
--   - name: string Buffer name (default: "output")
--   - close_keys: table Keys that close the window (default: {"q", "<Esc>"})
-- @private
local function setup_buffer(buf, opts)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  opts = opts or {}
  local buf_name = opts.name or "output"
  local close_keys = opts.close_keys or { "q", "<Esc>" }

  -- Set buffer options
  api.nvim_buf_set_name(buf, buf_name)
  api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  api.nvim_set_option_value("swapfile", false, { buf = buf })
  api.nvim_set_option_value("bufhidden", opts.bufhidden or "wipe", { buf = buf })

  -- Setup close keymaps
  for _, key in ipairs(close_keys) do
    pcall(function()
      api.nvim_buf_set_keymap(buf, "n", key, "<cmd>q<CR>", { noremap = true, silent = true })
    end)
  end

  return true
end

--- Create floating window and close it properly
-- Helper to ensure window is closed and buffer is cleaned up
-- @param win number Window ID to close
-- @param buf number Buffer ID to cleanup
-- @private
local function close_window(win, buf)
  if win and api.nvim_win_is_valid(win) then
    pcall(function() api.nvim_win_close(win, true) end)
  end
  if buf and api.nvim_buf_is_valid(buf) then
    pcall(function() api.nvim_buf_delete(buf, { force = true }) end)
  end
end

--- Create a centered floating window (legacy name, delegates to create_window)
-- @param buf number The buffer to display
-- @param width_ratio number Width as ratio of screen (e.g., 0.6 for 60%)
-- @param height_ratio number Height as ratio of screen (e.g., 0.8 for 80%)
-- @param opts table Optional styling (style, border, etc.)
-- @return number Window ID
function M.create_centered_float(buf, width_ratio, height_ratio, opts)
  return create_window(buf, width_ratio, height_ratio, opts)
end

--- Setup and create an output buffer in a centered floating window
-- Consolidates buffer creation, setup, and window display in one operation
-- @param buf_opts table|nil Buffer configuration (name, close_keys, etc.)
-- @param width_ratio number|nil Width as viewport fraction (default: 0.7)
-- @param height_ratio number|nil Height as viewport fraction (default: 0.5)
-- @param window_opts table|nil Window styling (style, border, title, etc.)
-- @return number Window ID, number Buffer ID (or nil, nil if failed)
function M.window(buf_opts, width_ratio, height_ratio, window_opts)
  buf_opts = buf_opts or {}
  width_ratio = width_ratio or 0.7
  height_ratio = height_ratio or 0.5
  window_opts = window_opts or {}

  -- Create buffer
  local output_buf = api.nvim_create_buf(false, true)
  if not output_buf then
    M.notify("Failed to create output buffer", vim.log.levels.ERROR)
    return nil, nil
  end

  -- Setup buffer
  if not setup_buffer(output_buf, buf_opts) then
    api.nvim_buf_delete(output_buf, { force = true })
    M.notify("Failed to setup output buffer", vim.log.levels.ERROR)
    return nil, nil
  end

  -- Create window
  local win = create_window(output_buf, width_ratio, height_ratio, window_opts)
  if not win then
    api.nvim_buf_delete(output_buf, { force = true })
    M.notify("Failed to create output window", vim.log.levels.ERROR)
    return nil, nil
  end

  return win, output_buf
end

--- Fuzzy select using fzf command-line tool
-- Requires fzf to be installed and in PATH
-- @param items table Array of items to select from
-- @param opts table|nil Selection options (prompt, format_item, etc.)
-- @param on_choice function Callback(selected_item, index) - called with selection or (nil, nil)
function M.fzf_select(items, opts, on_choice)
  if not items or #items == 0 then
    on_choice(nil, nil)
    return
  end

  opts = opts or {}
  on_choice = on_choice or function() end

  local buffer = api.nvim_create_buf(false, true)
  if not buffer then
    M.notify("Could not create fzf buffer", vim.log.levels.ERROR)
    on_choice(nil, nil)
    return
  end

  -- Setup fzf window (custom positioning, not centered)
  local height, width = vim.o.lines, vim.o.columns
  local row = math.floor(height * 0.25)
  local col = math.floor(width * 0.25)
  local win_height = math.ceil(height * 0.5)
  local win_width = math.ceil(width * 0.5)

  local ok, window = pcall(function()
    return api.nvim_open_win(buffer, true, {
      relative = "editor",
      row = row,
      col = col,
      height = win_height,
      width = win_width,
      style = "minimal",
      border = "rounded",
    })
  end)

  if not ok or not window then
    api.nvim_buf_delete(buffer, { force = true })
    M.notify("Could not create fzf window", vim.log.levels.ERROR)
    on_choice(nil, nil)
    return
  end

  -- Setup buffer
  api.nvim_set_option_value("buftype", "nofile", { buf = buffer })
  api.nvim_set_option_value("swapfile", false, { buf = buffer })
  api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer })
  api.nvim_set_option_value("filetype", "fzf", { buf = buffer })

  -- Format items for display
  local formatted_items = vim.tbl_map(function(item)
    return opts.format_item and opts.format_item(item) or tostring(item)
  end, items)

  -- Build fzf options
  local fzf_opts = opts.prompt and string.format("--prompt=%s\\>\\ ", fn.shellescape(opts.prompt)) or ""

  -- Run fzf
  local result_file = fn.tempname()
  local fzf_cmd = "fzf 2>/dev/null 1>" .. result_file
  local fzf_env = {
    FZF_DEFAULT_COMMAND = 'printf "%s\n" ' .. table.concat(vim.tbl_map(fn.shellescape, formatted_items), " "),
    FZF_DEFAULT_OPTS = fzf_opts,
  }

  local job = fn.termopen(fzf_cmd, {
    env = fzf_env,
    on_exit = function(_, code)
      close_window(window, buffer)

      if code == 0 then
        -- User made a selection
        for line in io.lines(result_file) do
          for i, item in ipairs(formatted_items) do
            if item == line then
              on_choice(items[i], i)
              fn.delete(result_file)
              return
            end
          end
        end
      else
        -- User cancelled
        on_choice(nil, nil)
      end
      fn.delete(result_file)
    end,
  })

  if not job or job == 0 or job == -1 then
    close_window(window, buffer)
    M.notify("Failed to start fzf", vim.log.levels.ERROR)
    on_choice(nil, nil)
  end
end

--- Interactive selection menu with numbered items
-- Displays items in a floating window with keyboard navigation
-- @param items table Array of items to select from
-- @param opts table|nil Options (prompt: string, format_item: function)
-- @param on_choice function Callback(selected_item, index) or (nil, nil) if cancelled
function M.norm_select(items, opts, on_choice)
  if not items or #items == 0 then
    on_choice(nil, nil)
    return
  end

  opts = opts or {}
  on_choice = on_choice or function() end

  -- Create buffer
  local buf = api.nvim_create_buf(false, true)
  if not buf then
    M.notify("Failed to create selection buffer", vim.log.levels.ERROR)
    on_choice(nil, nil)
    return
  end

  -- Calculate dimensions
  local width = DEFAULT_SIZES.select_width
  local height = #items + 2  -- +2 for prompt line and spacing
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Create window
  local ok, win = pcall(function()
    return api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
    })
  end)

  if not ok or not win then
    api.nvim_buf_delete(buf, { force = true })
    M.notify("Failed to create selection window", vim.log.levels.ERROR)
    on_choice(nil, nil)
    return
  end

  -- Setup window options
  api.nvim_set_option_value("cursorline", true, { win = win })
  api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

  -- Prepare display lines
  local lines = { opts.prompt or "Select one:" }
  for i, item in ipairs(items) do
    local display = opts.format_item and opts.format_item(item) or tostring(item)
    table.insert(lines, string.format("%d. %s", i, display))
  end

  -- Setup buffer content
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_set_option_value("modifiable", false, { buf = buf })
  api.nvim_set_option_value("bufhidden", "hide", { buf = buf })

  -- Setup keymaps
  local keymaps = {
    ["<CR>"] = function()
      local idx = vim.fn.line(".") - 1
      close_window(win, buf)
      if idx > 0 and idx <= #items then
        on_choice(items[idx], idx)
      else
        on_choice(nil, nil)
      end
    end,
    ["q"] = function()
      close_window(win, buf)
      on_choice(nil, nil)
    end,
    ["<Esc>"] = function()
      close_window(win, buf)
      on_choice(nil, nil)
    end,
    ["j"] = "j",
    ["k"] = "k",
  }

  for key, mapping in pairs(keymaps) do
    if type(mapping) == "function" then
      vim.keymap.set("n", key, mapping, { buffer = buf, nowait = true })
    else
      vim.keymap.set("n", key, mapping, { buffer = buf })
    end
  end

  -- Position cursor on first item
  api.nvim_win_set_cursor(win, { 2, 0 })
end

--- Text input dialog with optional default value
-- Displays an input field in a floating window
-- @param opts table|nil Input configuration
--   - prompt: string Label text
--   - default: string Default input value
-- @param on_confirm function Callback(input) - called with text or nil if cancelled
function M.input(opts, on_confirm)
  opts = opts or {}
  on_confirm = on_confirm or function() end

  -- Create buffer
  local buf = api.nvim_create_buf(false, true)
  if not buf then
    M.notify("Failed to create input buffer", vim.log.levels.ERROR)
    on_confirm(nil)
    return
  end

  -- Calculate dimensions
  local default = opts.default or ""
  local width = math.max(DEFAULT_SIZES.input_min_width, #(opts.prompt or "") + 5)
  local height = 1
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- Create window
  local ok, win = pcall(function()
    return api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = opts.prompt or "Input",
      title_pos = "center",
    })
  end)

  if not ok or not win then
    api.nvim_buf_delete(buf, { force = true })
    M.notify("Failed to create input window", vim.log.levels.ERROR)
    on_confirm(nil)
    return
  end

  -- Setup window
  api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

  -- Setup buffer content
  api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  api.nvim_set_option_value("modifiable", true, { buf = buf })

  -- Enter insert mode and position cursor
  vim.cmd("startinsert!")
  if default ~= "" then
    api.nvim_win_set_cursor(win, { 1, vim.fn.strdisplaywidth(default) })
  end

  -- Setup keymaps
  local keymaps = {
    ["<CR>"] = function()
      local input_text = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
      vim.cmd("stopinsert")
      close_window(win, buf)
      on_confirm(input_text)
    end,
    ["<Esc>"] = function()
      vim.cmd("stopinsert")
      close_window(win, buf)
      on_confirm(nil)
    end,
  }

  for key, mapping in pairs(keymaps) do
    vim.keymap.set("i", key, mapping, { buffer = buf, nowait = true })
  end
end

--- Setup output buffer with standard options and keymaps
-- Public function for backward compatibility
-- @param buf number The buffer number to setup
-- @param opts table|nil Optional configuration
--   - name: string Buffer name (default: "output")
--   - close_keys: table Keys to close window (default: {"q", "<Esc>"})
function M.setup_output_buffer(buf, opts)
  setup_buffer(buf, opts)
end

return M
