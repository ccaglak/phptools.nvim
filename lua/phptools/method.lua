local tree = require("phptools.treesitter")
local ts, api = vim.treesitter, vim.api
local Method = {}

local function await(cond, after)
  if not cond() then
    vim.defer_fn(function()
      await(cond, after)
    end, 250)
    return
  end
  after()
end

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
  _G.cdone = false
  M:get_position()
  if M.parent == nil then
    return
  end
  if M.variable == nil then
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

  --if there is undefined class, create class then the method
  if M.file_path == nil then
    vim.fn.cursor({ M.variable.range[1] + 1, M.variable.range[2] + 2 })
    M:find_file(vim.lsp.util.make_position_params(), "textDocument/definition")
    ---
    vim.fn.cursor({ M.file_location[1].targetRange.start.line + 1, 0 })
    ---
    -- vim.lsp.util.jump_to_location(M.file_location[1], "utf-8")
    M.missing_class = tree.children(tree.cursor():parent(), "object_creation_expression")
    if M.missing_class == nil then
      return
    end

    vim.fn.cursor({ M.missing_class.range[1] + 1, M.missing_class.range[2] + 2 })
    require("phptools.class"):run(true)

    await(function()
      if _G.cdone then
        return true
      end
    end, function()
      vim.fn.cursor({ M.method.range[1] + 2, M.method.range[2] + 2 })
      require("phptools.method"):run()
    end)
    return
  end

  if M.file_path == nil then
    return
  end

  local bufnr = M:get_buffer(M.file_path)

  local lines = {
    "    public function " .. M.method.text .. "()",
    "    {",
    "         //",
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
  params = params or vim.lsp.util.make_position_params()

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
    self.parent = tree.parent("scoped_call_expression")
    if self.parent == nil then
      return
    end
  end

  self.parenthe = tree.child_type(self.parent.node, "parenthesized_expression")
  if self.parenthe ~= nil then
    self.method = tree.child(self.parent.node, "name")
    if self.method.node == nil then
      return
    end
    vim.fn.cursor({ self.parenthe.range[1] + 1, self.parenthe.range[2] + 2 })

    --extract to function
    Method:find_file(Method.method_position(), "textDocument/definition")
    if #Method.file_location >= 1 then
      vim.lsp.util.jump_to_location(Method.file_location[1], "utf-8")
      return
    end

    local bn = vim.api.nvim_get_current_buf()
    require("phptools.class"):run()
    local lines = {
      "    public function " .. self.method.text .. "()",
      "    {",
      "         ",
      "    }",
    }
    await(function()
      if vim.api.nvim_get_current_buf() ~= bn then
        return true
      end
    end, function()
      Method:add_to_buffer(lines, 0)
    end)
    return
  end

  -- undefined static methods
  if self.parent.type == "scoped_call_expression" then
    self.method = tree.child(self.parent.node, "name")
    if self.method.node == nil then
      return
    end
    vim.fn.cursor({ self.scoped.range[1] + 1, self.scoped.range[2] + 2 })

    Method:find_file(Method.method_position(), "textDocument/definition")
    if #Method.file_location >= 1 then
      vim.lsp.util.jump_to_location(Method.file_location[1], "utf-8")
      return
    end

    local bn = vim.api.nvim_get_current_buf()
    require("phptools.class"):run()
    local lines = {
      "    public static function " .. self.method.text .. "()",
      "    {",
      "         ",
      "    }",
    }
    await(function()
      if vim.api.nvim_get_current_buf() ~= bn then
        return true
      end
    end, function()
      Method:add_to_buffer(lines, 0)
    end)
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
