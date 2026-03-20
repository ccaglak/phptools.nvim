-- GF Routes: Laravel route navigation
-- Handles browsing and navigation to Laravel routes

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

-- ============================================================================
-- Route Retrieval
-- ============================================================================

function M.get_routes()
  local root = gf_utils.get_project_root() or vim.fn.getcwd()
  if vim.fn.filereadable(np(root .. "/artisan")) == 0 then
    return nil, "Not in a Laravel project"
  end
  local cmd = string.format('cd "%s" && php artisan route:list --compact 2>/dev/null', root)
  local handle = io.popen(cmd)
  if not handle then
    return nil, "Failed to execute artisan"
  end
  local routes = {}
  for line in handle:lines() do
    if line and line:match("%S") and not line:match("^[+%-|%s]*$") and not line:match("^%s*Method%s") then
      local parts = {}
      for part in line:gmatch("%S+") do
        table.insert(parts, part)
      end
      if #parts >= 2 then
        local method = parts[1]
        local uri = parts[2]
        local action = parts[#parts]
        table.insert(routes, {
          method = method,
          uri = uri,
          action = action,
          display = string.format("%s %s", method, uri),
        })
      end
    end
  end
  handle:close()
  return routes, nil
end

-- ============================================================================
-- Controller Navigation
-- ============================================================================

function M.parse_controller_action(action)
  if not action or action:match("Closure") then
    return nil, nil
  end
  local controller, method = action:match("([^@]+)@([^@]+)")
  if controller and method then
    return controller, method
  end
  return nil, nil
end

function M.find_controller_file(controller_name)
  if not controller_name then
    return nil
  end
  local cwd = vim.fn.getcwd()
  local file_path = controller_name:gsub("App\\Http\\Controllers\\", ""):gsub("\\", "/")
  local possible = {
    np(cwd .. "/app/Http/Controllers/" .. file_path .. ".php"),
    np(cwd .. "/app/Controllers/" .. file_path .. ".php"),
  }
  for _, file in ipairs(possible) do
    if vim.fn.filereadable(file) == 1 then
      return file
    end
  end
  return nil
end

function M.goto_controller(controller, method)
  local file = M.find_controller_file(controller)
  if not file then
    gf_utils.notify_warn("Controller file not found")
    return
  end
  vim.cmd("edit " .. file)
  if method then
    vim.cmd("normal! gg")
    local pattern = "function\\s\\+" .. method .. "\\s*("
    if vim.fn.search(pattern) > 0 then
      vim.cmd("normal! zz")
      gf_utils.notify_info("Found method: " .. method)
    end
  end
end

-- ============================================================================
-- Route Browser
-- ============================================================================

function M.browse()
  local routes, err = M.get_routes()
  if not routes then
    gf_utils.notify_error(err or "Unknown error")
    return
  end
  if #routes == 0 then
    gf_utils.notify_warn("No routes found")
    return
  end
  local displays = {}
  for _, route in ipairs(routes) do
    table.insert(displays, route.display)
  end
  vim.ui.select(displays, { prompt = "Browse routes: " }, function(choice)
    for _, route in ipairs(routes) do
      if route.display == choice then
        local controller, method = M.parse_controller_action(route.action)
        if controller then
          M.goto_controller(controller, method)
        else
          gf_utils.notify_warn("No controller found for: " .. route.uri)
        end
        break
      end
    end
  end)
end

return M
