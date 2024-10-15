local tree = require("phptools.treesitter")
local lsp = vim.lsp
local api = vim.api
local fn = vim.fn

local Method = {}
Method.__index = Method

function Method.new()
  local self = setmetatable({}, Method)
  return self
end

function Method:create_position_params(node)
  return {
    textDocument = lsp.util.make_position_params().textDocument,
    position = {
      character = node.range[2] + 1,
      line = node.range[1],
    }
  }
end

function Method:find_and_jump_to_definition(params, methods)
  methods = methods or { "textDocument/definition", "textDocument/typeDefinition" }
  for _, method in ipairs(methods) do
    local results = lsp.buf_request_sync(0, method, params, 1000)
    if results and not vim.tbl_isempty(results) then
      for _, result in pairs(results) do
        if result.result and #result.result > 0 then
          lsp.util.jump_to_location(result.result[1], "utf-8")
          return result.result[1]
        end
      end
    end
  end
  return nil
end

function Method:generate_method_lines(method_name)
  return {
    string.format("    public function %s()", method_name),
    "    {",
    "        // TODO: Implement method",
    "    }",
  }
end

function Method:get_buffer(filename)
  return fn.bufexists(filename) ~= 0 and fn.bufnr(filename) or fn.bufadd(filename)
end

function Method:add_to_buffer(lines, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then return end

  fn.bufload(bufnr)
  local lastline = api.nvim_buf_line_count(bufnr)
  api.nvim_buf_set_lines(bufnr, lastline - 1, lastline - 1, true, lines)

  api.nvim_set_current_buf(bufnr)
  api.nvim_buf_call(bufnr, function() vim.cmd("silent! write! | edit") end)
  fn.cursor({ lastline + 2, 9 })
end

local function await(cond, after)
  if not cond() then
    vim.defer_fn(function()
      await(cond, after)
    end, 250)
    return
  end
  after()
end

function Method:run()
  local params = lsp.util.make_position_params()
  local current_file = params.textDocument.uri:gsub("file://", "")
  local parent, method, variable_or_scope = self:get_position()
  if not parent or not method or not variable_or_scope then return end

  local method_position = self:create_position_params(method)

  if self:find_and_jump_to_definition(method_position) then return end
  local file_path
  if variable_or_scope.text == "this" then
    file_path = current_file
  else
    local variable_position = self:create_position_params(variable_or_scope)
    local location = self:find_and_jump_to_definition(variable_position)
    local uri = location and (location.uri or location.targetUri)
    if uri ~= nil then
      file_path = uri:gsub("file://", "")
    else
      _G.done = false

      require("phptools.class"):run()
      await(function()
        if _G.done then
          return true
        end
      end, function()
        local bufnr = self:get_buffer(_G.filepath)
        self:add_to_buffer(self:generate_method_lines(method.text), bufnr)
      end)
      return
    end
  end

  if file_path then
    local bufnr = self:get_buffer(file_path)
    self:add_to_buffer(self:generate_method_lines(method.text), bufnr)
  end
end

function Method:get_position()
  local cnode = tree.cnode()
  local node = cnode.node:parent()
  local node_type = node:type()
  if node_type == "scoped_call_expression" or node_type == "class_constant_access_expression" then
    return node, cnode, tree.children(node, "name")
  end

  if node_type == "member_call_expression" then
    local object = tree.child(node, "object")
    if object then
      if object.node:type() == "parenthesized_expression" then
        local object_creation = tree.children(object.node, "object_creation_expression")
        return object.node, cnode, tree.children(object_creation.node, "name")
      end

      if object.node:type() == "variable_name" and tree.get_text(object.node) == "$this" then
        return object.node, cnode, tree.children(object.node, "name")
      end
      if object.node:type() == "variable_name" then
        local variable_position = self:create_position_params(object)
        self:find_and_jump_to_definition(variable_position)
        local class
        local assignment = tree.find_parent(tree.cursor(), "assignment_expression")
        if assignment then
          local right_side = tree.children(assignment.node, 'object_creation_expression')
          class = tree.children(right_side.node, "name")
        end
        vim.fn.cursor({ class.range[1] + 1, class.range[2] + 2 })
        return node, cnode, class
      end
    end
  end

  return nil
end

return Method
