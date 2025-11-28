-- main module file
require("phptools.funcs")

---@class Config
local config = {
  ui = {
    enable = true,
    fzf = false,
  },

  custom_toggles = {
    enable = false,
  },
}

local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})

  if M.config.custom_toggles.enable == true then
    require("phptools.toggle").setup(M.config.custom_toggles)
  end

  if M.config.ui.enable == true then
    require("phptools.ui").setup()
  end
end

M.method = function()
  require("phptools.method"):run()
end

M.class = function()
  require("phptools.class"):run()
end

M.getset = function()
  require("phptools.getset"):run()
end

M.scripts = function()
  require("phptools.composer"):scripts()
end

M.refactor = function()
  require("phptools.refactor").refactor()
end

M.create = function()
  require("phptools.create"):run()
end

M.namespace = function()
  require("phptools.composer"):resolve()
end

return M
