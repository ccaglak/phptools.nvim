local phptools = require("phptools")

local command_map = {
  Smart = "Smart",
  Method = "Method",
  Class = "Class",
  Namespace = "Namespace",
  GetSet = "GetSet",
  PropertyHooks = "PropertyHooks",
  Scripts = "Scripts",
  Refactor = "Refactor",
  Create = "Create",
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
    vim.notify("Usage: :PhpTools <command>\nAvailable commands: " .. table.concat(vim.tbl_keys(command_map), ", "), vim.log.levels.WARN)
    return
  end

  local command = args[1]
  command = command_map[command] or command

  local success, err = pcall(execute_command, command)
  if not success then
    vim.notify("PhpTools error: " .. err, vim.log.levels.ERROR)
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
