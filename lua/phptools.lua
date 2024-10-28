-- main module file
require("phptools.funcs")

---@class Config
---@field opt string
local config = {
  ui = true,
  create = false,
  toggle_options = {},
}

local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  if M.config.create == true then
    vim.api.nvim_create_autocmd("BufNewFile", {
      pattern = "*.php",
      callback = function()
        if vim.fn.expand("%:e") == "php" then
          require("phptools.create"):run()
        end
      end,
      group = vim.api.nvim_create_augroup("PhpToolsCreateFile", { clear = true }),
    })
  end
  if M.config.ui == true then
    require("phptools.ui")
  end
  require("phptools.toggle").setup(M.config.toggle_options)
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
