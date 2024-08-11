vim.api.nvim_create_user_command("PhpMethod", require("phptools").method, {})
vim.api.nvim_create_user_command("PhpClass", require("phptools").class, {})
vim.api.nvim_create_user_command("PhpNamespace", require("phptools").namespace, {})
vim.api.nvim_create_user_command("PhpGetSet", require("phptools").getset, {})
vim.api.nvim_create_user_command("PhpScripts", require("phptools").scripts, {})
vim.api.nvim_create_user_command("PhpRefactor", require("phptools").refactor, {})
vim.api.nvim_create_user_command("PhpCreate", require("phptools").create, {})

if not vim.uv then
    vim.uv = vim.loop
end
if not vim.lsp.get_clients then -- remove in v12
    vim.lsp.get_clients = vim.lsp.get_active_clients
end
