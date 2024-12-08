local tree = require("phptools.treesitter")

local Etter = {}

function Etter:new()
  local instance = setmetatable({}, { __index = Etter })
  instance.config = {
    indentation = 4,
  }
  return instance
end

local function flatten_symbols(symbols, result)
  result = result or {}
  for _, symbol in ipairs(symbols) do
    table.insert(result, symbol)
    if symbol.children then
      flatten_symbols(symbol.children, result)
    end
  end
  return result
end

function Etter:run()
  local M = Etter:new()
  M:get_position()
  if M.parent == nil then
    return
  end

  vim.ui.select({ "Set", "Get", "Get/Set" }, { prompt = "Select Method:" }, function(choice)
    if choice == nil then
      return
    end

    local methods_to_generate = M:get_methods_to_generate(choice)
    local existing_methods = M:get_existing_methods()

    for method_type, method_name in pairs(methods_to_generate) do
      if not existing_methods[method_name] then
        local tmpl = M:template_builder(method_type)
        M:add_to_buffer(tmpl)
      end
    end
  end)
end

function Etter:get_methods_to_generate(choice)
  local base_name = string.ucfirst(string.dltfirst(self.variable.text))
  local methods = {}

  if choice == "Get" or choice == "Get/Set" then
    methods.Get = "get" .. base_name
  end
  if choice == "Set" or choice == "Get/Set" then
    methods.Set = "set" .. base_name
  end

  return methods
end

function Etter:get_existing_methods()
  local params = vim.lsp.util.make_position_params(nil, "utf-16")
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, 5000)
  local existing_methods = {}

  if results_lsp and not vim.tbl_isempty(results_lsp) then
    for _, response in ipairs(results_lsp) do
      if response.result then
        for _, symbol in ipairs(flatten_symbols(response.result)) do
          if symbol.kind == vim.lsp.protocol.SymbolKind.Method then
            existing_methods[symbol.name] = true
          end
        end
      end
    end
  end

  return existing_methods
end

function Etter:template_builder(method_type)
  local var = self.variable.text
  local type = self.union.text
  local name = string.ucfirst(self.variable.text:sub(2))
  local vname = self.variable.text:sub(2)
  local indent = string.rep(" ", self.config.indentation)
  local tmpl = {}

  if method_type == "Set" then
    table.insert(tmpl, indent .. "public function set" .. name .. "(" .. type .. " " .. var .. "):void {")
    table.insert(tmpl, indent .. indent .. "$this->" .. vname .. " = " .. var .. ";")
    table.insert(tmpl, indent .. "}")
  elseif method_type == "Get" then
    table.insert(tmpl, indent .. "public function get" .. name .. "():" .. type .. " {")
    table.insert(tmpl, indent .. indent .. "return $this->" .. vname .. ";")
    table.insert(tmpl, indent .. "}")
  end

  return tmpl
end

function Etter:add_to_buffer(lines)
  local lastline = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_buf_set_lines(0, lastline - 1, lastline - 1, true, lines)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
end

function Etter:get_position()
  local function find_node(node_type)
    local node = tree.parent(node_type)
    if node then
      return node
    end
    return nil
  end

  self.parent = find_node("property_declaration") or find_node("property_promotion_parameter")
  if not self.parent then
    return false
  end

  local function find_type()
    local type_nodes = {
      "optional_type",
      "primitive_type",
      "union_type",
      "named_type",
    }
    for _, type_node in ipairs(type_nodes) do
      local node = tree.children(self.parent.node, type_node)
      if node then
        return node
      end
    end
    return nil
  end

  self.union = find_type()
  if not self.union then
    return false
  end

  if self.parent.type ~= "property_promotion_parameter" then
    self.property = tree.children(self.parent.node, "property_element")
    if not self.property then
      return false
    end
    self.variable = tree.children(self.property.node, "variable_name")
  else
    self.variable = tree.children(self.parent.node, "variable_name")
  end

  if not self.variable then
    return false
  end

  return true
end

return Etter
