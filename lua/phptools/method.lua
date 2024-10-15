local tree = require("phptools.treesitter")
local lsp = vim.lsp
local api = vim.api
local fn = vim.fn

local function create_position_params(node)
  return {
    textDocument = lsp.util.make_position_params().textDocument,
    position = {
      character = node.range[2] + 1,
      line = node.range[1],
    }
  }
end

local function find_and_jump_to_definition(params, methods)
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

local function generate_method_lines(method_name)
  return {
    string.format("    public function %s()", method_name),
    "    {",
    "        // TODO: Implement method",
    "    }",
  }
end

local function get_buffer(filename)
  return fn.bufexists(filename) ~= 0 and fn.bufnr(filename) or fn.bufadd(filename)
end

local function add_to_buffer(lines, bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(bufnr) then return end

  fn.bufload(bufnr)
  local lastline = api.nvim_buf_line_count(bufnr)
  api.nvim_buf_set_lines(bufnr, lastline - 1, lastline - 1, true, lines)

  api.nvim_set_current_buf(bufnr)
  api.nvim_buf_call(bufnr, function() vim.cmd("silent! write! | edit") end)
  fn.cursor({ lastline + 2, 9 })
end

local function get_position()
  local parent = tree.parent("member_call_expression") or tree.parent("scoped_call_expression")
  if not parent then return end

  local parenthe = tree.child_type(parent.node, "parenthesized_expression")
  local method = tree.child(parent.node, "name")
  local variable, scope

  if parenthe then
    return parent, parenthe, method
  elseif parent.type == "scoped_call_expression" then
    scope = tree.child(parent.node, "scope")
    return parent, method, scope
  else
    variable = tree.child_type(parent.node, "variable_name")
    return parent, method, variable
  end
end

local function run_method()
  local params = lsp.util.make_position_params()
  local current_file = params.textDocument.uri:gsub("file://", "")
  local parent, method, variable_or_scope = get_position()
  if not parent or not method then return end

  local method_position = create_position_params(method)

  if find_and_jump_to_definition(method_position) then return end

  local file_path
  if variable_or_scope.text == "$this" then
    file_path = current_file
  else
    local variable_position = create_position_params(variable_or_scope)
    local location = find_and_jump_to_definition(variable_position)
    if location then
      file_path = location.uri:gsub("file://", "")
    else
      -- Handle missing class creation here if needed
    end
  end

  if file_path then
    local bufnr = get_buffer(file_path)
    add_to_buffer(generate_method_lines(method.text), bufnr)
  end
end

return {
  run = run_method
}
