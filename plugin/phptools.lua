vim.api.nvim_create_user_command("PhpMethod", require("phptools").method, {})
vim.api.nvim_create_user_command("PhpClass", require("phptools").class, {})
vim.api.nvim_create_user_command("PhpNamespace", require("phptools").namespace, {})
vim.api.nvim_create_user_command("PhpGetSet", require("phptools").getset, {})
vim.api.nvim_create_user_command("PhpScripts", require("phptools").scripts, {})
vim.api.nvim_create_user_command("PhpRefactor", require("phptools").refactor, {})
if not vim.uv then
  vim.uv = vim.loop
end

local function reload()
  require("plenary.reload").reload_module("phptools")
  vim.cmd.source("/Users/oguz/Desktop/Workspace/phptools.nvim/plugin/phptools.lua")
  print("reloaded")
end

vim.keymap.set("n", "<leader>kk", function()
  reload()
end)
