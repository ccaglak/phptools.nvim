-- main module file
local method = require("phptools.method")
local class = require("phptools.class")
local namespace = require("phptools.namespace")
local getset = require("phptools.getset")
local scripts = require("phptools.composer")
local refactor = require("phptools.refactor")
local artisan = require("phptools.artisan")
require("phptools.funcs")

---@class Config
---@field opt string
local config = {
  ui = false,
}

local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  if M.config.ui == true then
    require("phptools.ui")
  end
end

M.method = function()
  method:run()
end

M.class = function()
  class:run()
end

M.namespace = function()
  namespace:run()
end

M.getset = function()
  getset:run()
end

M.scripts = function()
  scripts:scripts()
end

M.refactor = function()
  refactor:run()
end

M.artisan = function()
  artisan:run()
end
return M
