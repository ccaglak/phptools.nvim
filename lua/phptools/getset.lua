local tree = require("phptools.treesitter")
local utils = require("phptools.utils")

local Etter = {}
Etter.__index = Etter

-- Method choice options
local METHOD_CHOICES = { "Set", "Get", "Get/Set" }

-- Supported type node kinds
local TYPE_NODE_KINDS = {
  "optional_type",
  "primitive_type",
  "union_type",
  "named_type",
}

-- Property node types to check
local PROPERTY_NODE_TYPES = {
  "property_declaration",
  "property_promotion_parameter",
}

function Etter:new()
  local instance = setmetatable({
    config = {
      indentation = 4,
    },
  }, { __index = self })
  return instance
end


function Etter:run()
  local M = Etter:new()
  if not M:get_position() then
    return
  end

  vim.ui.select(METHOD_CHOICES, { prompt = "Select Method:" }, function(choice)
    if not choice then
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
  local params = utils.make_position_params()
  if not params then
    return self:_fallback_parse_methods()
  end

  local symbols = utils.get_symbols(params, 5000)
  if not symbols then
    -- LSP didn't return results, use fallback buffer parsing
    return self:_fallback_parse_methods()
  end

  -- Flatten and filter symbols to find methods
  local flat_symbols = utils.flatten_symbols(symbols)
  local existing_methods = {}

  for _, symbol in ipairs(flat_symbols) do
    if symbol and symbol.kind == vim.lsp.protocol.SymbolKind.Method and symbol.name then
      existing_methods[symbol.name] = true
    end
  end

  -- If LSP returned no methods but we're in a class, use fallback
  if vim.tbl_isempty(existing_methods) then
    return self:_fallback_parse_methods()
  end

  return existing_methods
end

function Etter:_fallback_parse_methods()
  -- Fallback: parse current buffer to find existing methods
  -- Uses regex pattern matching when LSP is unavailable
  local existing_methods = {}
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, line in ipairs(lines) do
    -- Match: public/protected/private function methodName(
    local method_name = line:match("function%s+([a-zA-Z_][a-zA-Z0-9_]*)%s*%(")
    if method_name then
      existing_methods[method_name] = true
    end
  end

  return existing_methods
end

function Etter:template_builder(method_type)
  -- Validate inputs
  if not method_type or not self.variable or not self.union then
    vim.notify("Unable to generate getter/setter: missing variable or type", vim.log.levels.ERROR)
    return {}
  end

  local var = self.variable.text
  local type = self.union.text
  local property_name = string.dltfirst(var) -- Remove $ from variable name
  local method_name = string.ucfirst(property_name) -- Capitalize for method name
  local indent = string.rep(" ", self.config.indentation)
  local tmpl = {}

  if method_type == "Set" then
    table.insert(tmpl, indent .. "public function set" .. method_name .. "(" .. type .. " " .. var .. "):void {")
    table.insert(tmpl, indent .. indent .. "$this->" .. property_name .. " = " .. var .. ";")
    table.insert(tmpl, indent .. "}")
  elseif method_type == "Get" then
    table.insert(tmpl, indent .. "public function get" .. method_name .. "():" .. type .. " {")
    table.insert(tmpl, indent .. indent .. "return $this->" .. property_name .. ";")
    table.insert(tmpl, indent .. "}")
  end

  return tmpl
end

function Etter:add_to_buffer(lines)
  -- Use unified buffer operation utility with save
  utils.add_lines_to_buffer(0, lines, true, true)
end

function Etter:get_position()
  -- Find property declaration or promotion parameter node
  self.parent = tree.parent("property_declaration") or tree.parent("property_promotion_parameter")
  if not self.parent then
    return false
  end

  -- Find type node
  for _, type_node in ipairs(TYPE_NODE_KINDS) do
    local node = tree.children(self.parent.node, type_node)
    if node then
      self.union = node
      break
    end
  end

  if not self.union then
    return false
  end

  -- Extract variable name based on parent type
  if self.parent.type == "property_promotion_parameter" then
    self.variable = tree.children(self.parent.node, "variable_name")
  else
    self.property = tree.children(self.parent.node, "property_element")
    if not self.property then
      return false
    end
    self.variable = tree.children(self.property.node, "variable_name")
  end

  if not self.variable then
    return false
  end

  return true
end

return Etter
