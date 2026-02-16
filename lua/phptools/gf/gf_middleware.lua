-- GF Middleware: Middleware stack navigation
-- Handles finding and opening Laravel middleware files

local M = {}
local gf_utils = require("phptools.gf.gf_utils")
local np = gf_utils.normalize_path

local PATTERNS = {
  route_middleware = "Route::middleware%s*%(%s*['\"]([^'\"]+)['\"]",
  arrow_middleware = "->middleware%s*%(%s*['\"]([^'\"]+)['\"]",
  array_middleware = "middleware%s*%(%s*%[%s*['\"]([^'\"]+)['\"]",
}

local DIRECTORIES = {
  middleware = "app/Http/Middleware",
}

local MIDDLEWARE_ALIASES = {
  ["auth"] = "Authenticate",
  ["guest"] = "RedirectIfAuthenticated",
  ["verified"] = "EnsureEmailIsVerified",
  ["throttle"] = "ThrottleRequests",
}

function M.find_middleware(middleware_name)
  if not middleware_name or middleware_name == "" then
    return nil
  end

  local root = gf_utils.get_project_root() or vim.fn.getcwd()

  -- Try direct lookup
  local middleware_file = np(root .. "/" .. DIRECTORIES.middleware .. "/" .. middleware_name .. ".php")
  if vim.fn.filereadable(middleware_file) == 1 then
    return middleware_file
  end

  -- Try with alias resolution
  if MIDDLEWARE_ALIASES[middleware_name] then
    local file = np(root .. "/" .. DIRECTORIES.middleware .. "/" .. MIDDLEWARE_ALIASES[middleware_name] .. ".php")
    if vim.fn.filereadable(file) == 1 then
      return file
    end
  end

  -- Try globpath and fallback
  local primary = DIRECTORIES.middleware .. "/**/" .. middleware_name .. ".php"
  local fallback = "**/" .. middleware_name .. ".php"
  return gf_utils.search_file(primary, fallback)
end

function M.detect_middleware_call()
  local line = vim.fn.getline(".")
  return line:match(PATTERNS.route_middleware) or
         line:match(PATTERNS.arrow_middleware) or
         line:match(PATTERNS.array_middleware)
end

function M.goto_middleware()
  return gf_utils.handle_navigation(
    M.detect_middleware_call,
    M.find_middleware,
    function(middleware_name) return "Opened middleware: " .. middleware_name end
  )
end

return M
