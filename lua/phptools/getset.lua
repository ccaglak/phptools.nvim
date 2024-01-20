local tree = require("phptools.treesitter")
local Etter = {}
function Etter:new()
  local t = setmetatable({}, { __index = Etter })
  return t
end

--
--
function Etter:run()
  local M = Etter:new()
  M:get_position()
  if M.parent == nil then
    return
  end

  vim.ui.select({ "Set", "Get", "Get/Set" }, { prompt = "Select a file:" }, function(choice)
    if choice == nil then
      return
    end
    local tmpl = M:template_builder(choice)
    M:add_to_buffer(tmpl)
  end)
end

--
--
--
function Etter:template_builder(choice)
  local var = self.variable.text
  local type = self.union.text
  local name = string.ucfirst(self.variable.text:sub(2))
  local vname = self.variable.text:sub(2)
  local tmpl = {}
  if choice == "Set" or choice == "Get/Set" then
    table.insert(tmpl, "public function set" .. name .. "(" .. type .. " " .. var .. "):void{")
    table.insert(tmpl, "   $this->" .. vname .. " = " .. var .. ";")
    table.insert(tmpl, "}")
  end
  if choice == "Get" or choice == "Get/Set" then
    table.insert(tmpl, "public function get" .. name .. "():" .. type .. "{")
    table.insert(tmpl, "   return $this->" .. vname .. ";")
    table.insert(tmpl, "}")
  end
  return tmpl
end

--
--
--
function Etter:add_to_buffer(lines)
  local lastline = vim.api.nvim_buf_line_count(0)
  vim.api.nvim_buf_set_lines(0, lastline - 1, lastline - 1, true, lines)
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)
end

--
--
--
function Etter:get_position()
  self.parent = tree.parent("property_declaration")
  if self.parent == nil then
    return
  end

  -- self.visibility = tree.child_type(self.parent.node, "visibility_modifier")
  -- if self.visibility.node == nil then
  --   return
  -- end

  self.union = tree.children(self.parent.node, "union_type")
  if self.union.node == nil then
    return
  end

  self.property = tree.children(self.parent.node, "property_element")
  if self.property.node == nil then
    return
  end

  self.variable = tree.children(self.property.node, "variable_name")
  if self.variable.node == nil then
    return
  end
end

return Etter
