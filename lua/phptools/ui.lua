local api = vim.api
local M = {}

-- Override vim.ui with custom implementations
M.setup = function()
  vim.ui.select = M.select
  vim.ui.input = M.input
end

M.select = function(items, opts, on_choice)
  local buf = api.nvim_create_buf(false, true)
  local width = 60
  local height = #items + 2

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
  })

  -- Set window options
  api.nvim_win_set_option(win, "cursorline", true)
  api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")

  -- Format items based on kind
  local lines = { opts.prompt or "Select one:" }
  for i, item in ipairs(items) do
    local display = item
    if opts.format_item then
      display = opts.format_item(item)
    end
    table.insert(lines, string.format("%d. %s", i, display))
  end

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Keymaps
  local function close_window()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end

  local keymaps = {
    ["<CR>"] = function()
      local idx = vim.fn.line(".") - 1
      close_window()
      if idx > 0 and idx <= #items then
        on_choice(items[idx], idx)
      else
        on_choice(nil, nil)
      end
    end,
    ["q"] = function()
      close_window()
      on_choice(nil, nil)
    end,
    ["<Esc>"] = function()
      close_window()
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

  -- Set cursor position
  api.nvim_win_set_cursor(win, { 2, 0 })
end

M.input = function(opts, on_confirm)
  local buf = api.nvim_create_buf(false, true)
  local width = math.max(40, #(opts.prompt or "") + 5)
  local height = 1

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = opts.prompt or "Input",
    title_pos = "center",
  })

  -- Set window options
  api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")

  -- Set initial content
  local default = opts.default or ""
  api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  api.nvim_buf_set_option(buf, "modifiable", true)

  -- Handle completion if provided
  if opts.completion then
    vim.bo[buf].completefunc = opts.completion
  end

  -- Enter insert mode
  vim.cmd("startinsert!")
  if default ~= "" then
    api.nvim_win_set_cursor(win, { 1, #default })
  end

  local function close_window()
    if api.nvim_win_is_valid(win) then
      vim.cmd("stopinsert")
      api.nvim_win_close(win, true)
    end
  end

  -- Keymaps
  local keymaps = {
    ["<CR>"] = function()
      local input = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
      close_window()
      on_confirm(input)
    end,
    ["<Esc>"] = function()
      close_window()
      on_confirm(nil)
    end,
  }

  for key, mapping in pairs(keymaps) do
    vim.keymap.set("i", key, mapping, { buffer = buf, nowait = true })
  end
end

return M
