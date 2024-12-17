local api = vim.api
local fn = vim.fn

local notify = require("phptools.notify").notify

local M = {}

M.setup = function()
  vim.ui.select = M.norm_select
  vim.ui.input = M.input
end

function M.fzf_select(items, opts, on_choice)
  local height, width = vim.o.lines, vim.o.columns
  local row = math.floor(height * 0.25)
  local col = math.floor(width * 0.25)
  local win_height = math.ceil(height * 0.5)
  local win_width = math.ceil(width * 0.5)

  local buffer = api.nvim_create_buf(false, true)
  local window = api.nvim_open_win(buffer, true, {
    relative = "editor",
    row = row,
    col = col,
    height = win_height,
    width = win_width,
  })

  fn.clearmatches(window)

  api.nvim_buf_set_keymap(buffer, "n", "<Esc>", "<cmd>close<CR>", { noremap = true, silent = true })

  -- Set buffer options
  api.nvim_set_option_value("buftype", "nofile", { buf = buffer })
  api.nvim_set_option_value("swapfile", false, { buf = buffer })
  api.nvim_set_option_value("bufhidden", "wipe", { buf = buffer })
  vim.bo[buffer].filetype = "fzf"

  local formatted_items = vim.tbl_map(function(item)
    return opts.format_item and opts.format_item(item) or tostring(item)
  end, items)

  local fzf_opts = table.concat({
    opts.prompt and string.format("--prompt=%s\\>\\ ", fn.shellescape(opts.prompt)) or "",
  }, " ")

  local result = fn.tempname()
  local job = fn.termopen("fzf 2>/dev/null 1>" .. result, {
    env = {
      FZF_DEFAULT_COMMAND = 'printf "%s\n" ' .. table.concat(vim.tbl_map(fn.shellescape, formatted_items), " "),
      FZF_DEFAULT_OPTS = fzf_opts,
    },
    on_exit = function(_, code)
      if api.nvim_buf_is_valid(buffer) then
        api.nvim_buf_delete(buffer, {})
      end

      if code == 0 then
        for line in io.lines(result) do
          for i, item in ipairs(formatted_items) do
            if item == line then
              on_choice(items[i], i)
              break
            end
          end
        end
      else
        on_choice(nil, nil)
      end
      fn.delete(result)
    end,
  })

  if not job or job == 0 or job == -1 then
    notify("Could not start fzf job", vim.log.levels.ERROR)
    return
  end
end

M.norm_select = function(items, opts, on_choice)
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
  api.nvim_set_option_value("cursorline", true, { win = win })
  api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

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
  api.nvim_set_option_value("modifiable", false, { buf = buf })
  api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

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
  api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })

  local default = opts.default or ""
  api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  api.nvim_set_option_value("modifiable", true, { buf = buf })
  -- Enhanced completion setup
  if opts.completion then
    vim.bo[buf].omnifunc = opts.completion
    -- Enable completion menu settings
    vim.opt_local.completeopt = { "menu", "menuone", "noselect" }
    -- Auto trigger completion
    vim.keymap.set("i", "<Tab>", function()
      if vim.fn.pumvisible() == 1 then
        return "<C-n>"
      else
        vim.fn.feedkeys(vim.fn.nr2char(vim.fn.getchar()), "n")
        return vim.fn.complete(vim.fn.col("."), opts.completion_items or {})
      end
    end, { buffer = buf, expr = true })
  end

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
