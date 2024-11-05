local phptools = require("phptools")

local command_map = {
  Method = "Method",
  Class = "Class",
  Namespace = "Namespace",
  GetSet = "GetSet",
  Scripts = "Scripts",
  Refactor = "Refactor",
  Create = "Create",
  Composer = "Composer",
  DrupalAutoloader = "DrupalAutoloader",
}

local function execute_command(command)
  local fn = phptools[command:lower()]
  if type(fn) == "function" then
    fn()
  else
    error("Command not implemented: " .. command)
  end
end

local function php_command(opts)
  local args = opts.fargs
  if #args == 0 then
    print("Usage: Php <command> [args...]")
    return
  end

  local command = args[1]
  command = command_map[command] or command

  local success, err = pcall(execute_command, command)
  if not success then
    vim.api.nvim_err_writeln("PhpTools error: " .. err)
  end
end

vim.api.nvim_create_user_command("PhpTools", php_command, {
  nargs = "+",
  complete = function(_, _, _)
    return vim.tbl_keys(command_map)
  end,
})

if not vim.uv then
  vim.uv = vim.loop
end
if not vim.lsp.get_clients then -- to be removed v12
  vim.lsp.get_clients = vim.lsp.get_active_clients
end

if not vim.lsp.util.show_document then -- to be removed v12
  vim.lsp.util.show_document = vim.lsp.util.jump_to_location
end
