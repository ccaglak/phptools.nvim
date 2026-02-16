-- main module file
-- Standard PHP project root markers (used globally)
_G.PHP_ROOT_MARKERS = { ".git", "composer.json", ".env" }

_G.sep = vim.uv.os_uname().sysname == "Windows_NT" and "\\" or "/"
function _G.get_php_root()
  return vim.fs.root(0, _G.PHP_ROOT_MARKERS) or vim.uv.cwd()
end

function string.ucfirst(str)
  return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

function string.lcfirst(str)
  return string.lower(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

-- delete first char
function string.dltfirst(str)
  return str:sub(2)
end

---@class Config
local config = {
  ui = {
    enable = true,
    fzf = false,
  },

  custom_toggles = {
    enable = false,
  },

  gf = {
    enable = true,
    max_depth = 5,
    project_root_markers = _G.PHP_ROOT_MARKERS,
    excluded_dirs = { "vendor", "node_modules", ".git" },
    custom_constants = {},
  },

  property_hooks = {
    enable = true,
    custom_templates = {},
  },
}

local M = {}
local module_cache = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  if M.config.custom_toggles.enable then
    require("phptools.toggle").setup(M.config.custom_toggles)
  end

  if M.config.ui.enable then
    require("phptools.ui").setup()
  end

  if M.config.gf.enable then
    require("phptools.gf").setup(M.config.gf)
  end
end

-- Lazy load and cache modules
local function load_module(module_path)
  if not module_cache[module_path] then
    module_cache[module_path] = require(module_path)
  end
  return module_cache[module_path]
end

M.smart = function()
  load_module("phptools.smart"):run()
end

M.method = function()
  load_module("phptools.method"):run()
end

M.class = function()
  load_module("phptools.class"):run()
end

M.getset = function()
  load_module("phptools.getset"):run()
end

M.propertyhooks = function()
  load_module("phptools.property_hooks"):run(M.config.property_hooks)
end

M.scripts = function()
  load_module("phptools.composer"):scripts()
end

M.refactor = function()
  load_module("phptools.refactor").refactor()
end

M.create = function()
  load_module("phptools.create"):run()
end

M.namespace = function()
  load_module("phptools.composer"):resolve()
end

load_module("phptools.gf")

return M
