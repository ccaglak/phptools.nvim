vim.api.nvim_create_user_command("PhpMethod", require("phpUtils").method, {})
vim.api.nvim_create_user_command("PhpClass", require("phpUtils").class, {})
vim.api.nvim_create_user_command("PhpScripts", require("phpUtils").commands, {})
