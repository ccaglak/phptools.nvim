local api = vim.api

local displayed = {}
local function make_popup(width, height, offset)
  return {
    relative = "editor",
    anchor = "SE",
    width = width,
    height = height,
    row = vim.o.lines - offset,
    col = vim.o.columns,
  }
end

local function close_notification(win, buf)
  api.nvim_win_close(win, true)
  api.nvim_buf_delete(buf, { force = true })
  displayed[buf] = nil
end

local M = {}

M.notify = function(msg)
  if not msg then
    return
  end

  local lines = vim.split(msg, "\n")
  local max_width = math.floor(vim.o.columns / 3.5)
  local height = #lines

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local offset = 1
  for _, popup in pairs(displayed) do
    offset = offset + popup.height + 1
  end

  local win = api.nvim_open_win(buf, false, make_popup(max_width, height, offset))

  displayed[buf] = { win = win, height = height }

  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then
      vim.defer_fn(function()
        close_notification(win, buf)
      end, 500)
    end
  end, 3000)

  return buf
end

return M
