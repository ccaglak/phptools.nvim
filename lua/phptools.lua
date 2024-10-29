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

  require("phptools.toggle").setup(M.config.toggle_options)

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

vim.keymap.set("n", "<Leader>ta", require("phptools.tests").test.all, { desc = "Run all tests" })
vim.keymap.set("n", "<Leader>tf", require("phptools.tests").test.file, { desc = "Run current file tests" })
vim.keymap.set("n", "<Leader>tl", require("phptools.tests").test.line, { desc = "Run test at cursor" })
vim.keymap.set("n", "<Leader>ts", require("phptools.tests").test.filter, { desc = "Search and run test" })
vim.keymap.set("n", "<Leader>tp", require("phptools.tests").test.parallel, { desc = "Run tests in parallel" })
vim.keymap.set("n", "<Leader>tr", require("phptools.tests").test.rerun, { desc = "Rerun last test" })

return M
