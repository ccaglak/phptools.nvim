-- GF Logs: Log file navigation and tailing
-- Handles finding, browsing, and tailing Laravel log files

local M = {}
local ui = require("phptools.ui")
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

-- ============================================================================
-- Log Directory Detection
-- ============================================================================

function M.find_log_dir()
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  local possible = {
    np(root .. "/storage/logs"),
    np(root .. "/laravel/storage/logs"),
    np(root .. "/../storage/logs"),
  }
  for _, path in ipairs(possible) do
    if vim.fn.isdirectory(path) == 1 then
      return path
    end
  end
  return nil
end

-- ============================================================================
-- Log File Discovery
-- ============================================================================

function M.get_log_files()
  local log_dir = M.find_log_dir()
  if not log_dir then
    return {}
  end
  local log_files = {}
  local files = vim.fn.globpath(log_dir, "*.log", 0, 1)
  for _, file in ipairs(files) do
    local stat = vim.loop.fs_stat(file)
    if stat then
      table.insert(log_files, {
        path = file,
        name = vim.fn.fnamemodify(file, ":t"),
        size = stat.size,
        mtime = stat.mtime.sec,
      })
    end
  end
  table.sort(log_files, function(a, b)
    return a.mtime > b.mtime
  end)
  return log_files
end

-- ============================================================================
-- Log Browsing
-- ============================================================================

function M.browse()
  local log_files = M.get_log_files()
  if #log_files == 0 then
    gf_utils.notify_warn("No log files found")
    return
  end
  local displays = {}
  for _, log in ipairs(log_files) do
    local size_mb = string.format("%.2f MB", log.size / 1024 / 1024)
    table.insert(displays, string.format("%s (%s)", log.name, size_mb))
  end
  ui.norm_select(displays, "Browse logs: ", function(choice)
    for _, log in ipairs(log_files) do
      local display = string.format("%s (%.2f MB)", log.name, log.size / 1024 / 1024)
      if display == choice then
        vim.cmd("edit " .. log.path)
        gf_utils.notify_info("Opened: " .. log.name)
        break
      end
    end
  end)
end

-- ============================================================================
-- Log Tailing
-- ============================================================================

function M.tail()
  local log_dir = M.find_log_dir()
  if not log_dir then
    gf_utils.notify_error("Laravel project not found")
    return
  end
  local laravel_log = np(log_dir .. "/laravel.log")
  if vim.fn.filereadable(laravel_log) == 0 then
    gf_utils.notify_warn("Log file not found")
    return
  end
  vim.cmd("tabnew")
  vim.cmd("terminal tail -f " .. vim.fn.shellescape(laravel_log))
  vim.cmd("startinsert")
end

return M
