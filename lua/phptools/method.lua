local tree = require("phptools.treesitter")

local Method = {}

function Method:new()
  local t = setmetatable({}, { __index = Method })
  --
  t.params = vim.lsp.util.make_position_params()
  t.current_file = t.params.textDocument.uri:gsub("file://", "")

  self.variable_position = function()
    t.params.position = {
      character = t.variable.range[2] + 1,
      line = t.variable.range[1],
    }
    return t.params
  end

  self.method_position = function()
    t.params.position = {
      character = t.method.range[2] + 1,
      line = t.method.range[1],
    }
    return t.params
  end
  return t
end

function Method:run()
  local M = Method:new()
  M:get_position()
  if M.parent == nil then
    return
  end
  M:find_file(M.method_position(), "textDocument/definition")
  if #M.file_location >= 1 then
    vim.lsp.util.jump_to_location(M.file_location[1], "utf-8")
    return
  end

  M:find_file(M.variable_position())
  if #M.file_location ~= 0 then -- something fishy here
    M.file_path = M.file_location[1].uri:gsub("file://", "")
  end

  if M.variable.text == "$this" then
    M.file_path = M.current_file
  end

  local bufnr = M:get_buffer(M.file_path)

  local lines = {
    "    public function " .. M.method.text .. "()",
    "    {",
    "         ",
    "    }",
  }

  M:add_to_buffer(lines, bufnr)
end

--
--
--
function Method:add_to_buffer(lines, bufnr)
  bufnr = bufnr or vim.fn.bufnr(vim.api.nvim_buf_get_name(0))
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.fn.bufload(bufnr)
  local lastline = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, lastline - 1, lastline - 1, true, lines)

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
  vim.fn.cursor({ lastline + 2, 9 })
end

--
--
--
function Method:get_buffer(filename)
  local buf_exists = vim.fn.bufexists(filename) ~= 0
  if buf_exists then
    return vim.fn.bufnr(filename)
  end

  return vim.fn.bufadd(filename)
end

--
--
--
function Method:find_file(params, method)
  method = method or "textDocument/typeDefinition"

  local results, err = vim.lsp.buf_request_sync(0, method, params, 1000)
  if err or results == nil or #results == 0 then
    return
  end

  for _, v in pairs(results) do
    self.file_location = v.result
    return
  end
end

--
--
--
function Method:get_position()
  self.parent = tree.parent("member_call_expression")
  if self.parent == nil then
    return
  end

  self.variable = tree.child_type(self.parent.node, "variable_name")
  if self.variable.node == nil then
    return
  end

  self.method = tree.child(self.parent.node, "name")
  if self.method.node == nil then
    return
  end
end

return Method
