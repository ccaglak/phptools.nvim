local composer = require("phptools.composer")
local M = {}

function M:run()
  local filename = vim.api.nvim_buf_get_name(0)
  local pathinfo = io.pathinfo(filename)
  pathinfo.dirname = pathinfo.dirname:gsub("-", "!")
  local dir = pathinfo.dirname:gsub(root:gsub("-", "!"), "")
  if dir == "" then
    return
  end
  local prefix, src = composer.composer()
  local ns = M:gen(dir, prefix, src) -- Todo just in case src is dirty
  M:add_to_current_buffer({ ns })
end

function M:gen(dir, prefix, src, filename)
  --
  dir = dir:gsub(src, prefix)
  local ns = string.pascalcase(dir)

  if filename ~= nil then
    return "use " .. ns .. "\\" .. filename .. ";"
  end

  return "namespace " .. ns .. ";"
end

function M:add_to_current_buffer(lines)
  local insertion_line = M:get_insertion_point() - 1
  vim.api.nvim_buf_set_lines(0, insertion_line, insertion_line, true, lines)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
end

function M:get_insertion_point()
  -- local lastline = vim.api.nvim_buf_line_count(bufnr)
  -- TODO dont want to read whole file 1/4
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local insertion_point = nil

  for i, line in ipairs(content) do
    if line:find("^declare") or line:find("^namespace") or line:find("^use") then
      insertion_point = i
    end

    if
      line:find("^class")
      or line:find("^final")
      or line:find("^interface")
      or line:find("^abstract")
      or line:find("^trait")
      or line:find("^enum")
    then
      break
    end
  end

  return insertion_point or 3
end

return M
