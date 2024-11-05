local api = vim.api

local hls = {
  [vim.log.levels.ERROR] = "NotifyError",
  [vim.log.levels.INFO] = "NotifyInfo",
  [vim.log.levels.WARN] = "NotifyWarn",
}

local defaults = {
  timeout = 3000,
  border = "none",
  position = "SE",
  style = "minimal",
  width_ratio = 3,
}

local function make_popup_opts(width, height, offset, opts)
  return {
    relative = "editor",
    anchor = opts.position or defaults.position,
    width = width,
    height = height,
    row = vim.o.lines - offset,
    col = vim.o.columns,
    style = opts.style or defaults.style,
    border = opts.border or defaults.border
  }
end

local M = {}
M.notify = function(msg, level, opts)
  if not msg then return end
  level = level or vim.log.levels.INFO
  opts = opts or {}

  local lines = vim.split(msg, "\n")
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = api.nvim_open_win(buf, false, make_popup_opts(#msg, #lines, 1, opts))

  local ns = api.nvim_create_namespace("phptools_notify")
  api.nvim_buf_add_highlight(buf, ns, hls[level] or "NotifyInfo", 0, 0, -1)
  api.nvim_set_option_value("winhl", opts.winhl or "Normal:Normal", { win = win })

  vim.defer_fn(function()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
      api.nvim_buf_delete(buf, { force = true })
    end
  end, opts.timeout or defaults.timeout)

  return buf
end
return M
