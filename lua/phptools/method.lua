local tree = require("phptools.treesitter")
local api = vim.api
local fn = vim.fn
local buf_request_sync = vim.lsp.buf_request_sync
local jump_to_location = vim.lsp.util.jump_to_location
local make_position_params = vim.lsp.util.make_position_params

local Method = {
  templates = {
    default = {
      "    public function %s()",
      "    {",
      "        // TODO: Implement method",
      "    }",
    },
    scoped_call_expression = {
      "    public static function %s()",
      "    {",
      "        // TODO: Implement static method",
      "    }",
    },
    class_constant_access_expression = {
      "    case %s;",
    },
    -- Add more default templates here
  },
}
Method.__index = Method

function Method:init()
  self.template = nil
  self.params = make_position_params()
  self.current_file = self.params.textDocument.uri:gsub("file://", "")
  self.parent, self.method, self.variable_or_scope = self:get_position()
end

function Method:run()
  self:init()
  if not self.parent or not self.method or not self.variable_or_scope then
    return
  end

  local method_position = self:create_position_params(self.method)

  if self:find_and_jump_to_definition(method_position) then
    return
  end

  if self.variable_or_scope.text == "this" then
    self:handle_this_scope()
  else
    self:handle_other_scope()
  end
end

function Method:get_position()
  local cnode = tree.cnode()
  local node = cnode.node:parent()
  local node_type = node:type()
  if node_type == "scoped_call_expression" or node_type == "class_constant_access_expression" then
    self.template = node_type
    return node, cnode, tree.children(node, "name")
  end

  if node_type == "member_call_expression" then
    self.template = "default"
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
          local right_side = tree.children(assignment.node, "object_creation_expression")
          class = tree.children(right_side.node, "name")
        end

        return node, cnode, class
      end
    end
  end
end

function Method:handle_this_scope()
  local bufnr = self:get_buffer(self.current_file)
  self:add_to_buffer(self:generate_method_lines(self.method.text), bufnr)
end

function Method:handle_other_scope()
  local variable_position = self:create_position_params(self.variable_or_scope)
  local location = self:find_and_jump_to_definition(variable_position)
  local uri = location and (location.uri or location.targetUri)
  if uri then
    local file_path = uri:gsub("file://", "")
    local bufnr = self:get_buffer(file_path)
    self:add_to_buffer(self:generate_method_lines(self.method.text), bufnr)
  else
    self:handle_undefined_class()
  end
end

function Method:handle_undefined_class()
  _G.done = false
  vim.fn.cursor({ self.variable_or_scope.range[1] + 1, self.variable_or_scope.range[2] + 2 })
  require("phptools.class"):run()
  self:await_class_creation()
end

local function await(cond, after)
  local timer = vim.loop.new_timer()
  timer:start(
    0,
    250,
    vim.schedule_wrap(function()
      if cond() then
        timer:stop()
        after()
      end
    end)
  )
end

function Method:await_class_creation()
  await(function()
    return _G.done
  end, function()
    local bufnr = self:get_buffer(_G.filepath)
    self:add_to_buffer(self:generate_method_lines(self.method.text), bufnr)
  end)
end

function Method:create_position_params(node)
  return {
    textDocument = make_position_params().textDocument,
    position = {
      character = node.range[2] + 1,
      line = node.range[1],
    },
  }
end

function Method:find_and_jump_to_definition(params, methods)
  methods = methods or { "textDocument/definition", "textDocument/typeDefinition" }
  for _, method in ipairs(methods) do
    local results = buf_request_sync(0, method, params, 1000)
    if results and not vim.tbl_isempty(results) then
      for _, result in pairs(results) do
        if result.result and #result.result > 0 then
          jump_to_location(result.result[1], "utf-8")
          return result.result[1]
        end
      end
    end
  end
  return nil
end

function Method:generate_method_lines(method_name)
  local template = self.templates[self.template]
  local lines = {}
  for _, line in ipairs(template) do
    table.insert(lines, string.format(line, method_name))
  end
  return lines
end

function Method:get_buffer(filename)
  return fn.bufexists(filename) ~= 0 and fn.bufnr(filename) or fn.bufadd(filename)
end

function Method:add_to_buffer(lines, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  fn.bufload(bufnr)
  local lastline = api.nvim_buf_line_count(bufnr)

  api.nvim_buf_set_lines(bufnr, lastline - 1, lastline - 1, true, lines)

  api.nvim_set_current_buf(bufnr)
  api.nvim_buf_call(bufnr, function()
    vim.cmd("silent! write! | edit")
  end)
  fn.cursor({ lastline + #lines, 9 })
end

return Method
