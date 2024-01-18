local M = {}
local uv = vim.uv or vim.loop
M.composer = function()
  local cf = M.composer_file_load()
  if cf == nil then
    return
  end

  local auto = cf.autoload["psr-4"]
  for index, value in pairs(auto) do -- Todo multiple
    return index, value
  end
end

M.composer_file_load = function()
  if M.cmpsr then
    return M.cmpsr
  end

  local composer = uv.cwd() .. "/composer.json"
  local exists = uv.fs_stat(composer)
  if not exists then
    return
  end

  local content = vim.fn.readfile(composer)

  M.cmpsr = vim.fn.json_decode(content)
  return M.cmpsr
end

M.scripts = function()
  local composer = M.composer_file_load()
  if composer == nil then
    return
  end
  local tasks = {}
  for key, _ in pairs(composer.scripts) do
    table.insert(tasks, key)
  end

  vim.ui.select(tasks, {
    prompt = "Run Tasks",
  }, function(selection)
    if not selection then
      return
    end
    vim.cmd.term("composer " .. selection)
  end)
end

return M
