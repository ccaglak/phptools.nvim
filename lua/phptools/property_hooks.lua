local tree = require("phptools.treesitter")

local PropertyHooks = {}
PropertyHooks.__index = PropertyHooks

-- Hook type options
local HOOK_TYPES = { "Simple", "Validated" }

-- Supported type node kinds
local TYPE_NODE_KINDS = {
  "optional_type",
  "primitive_type",
  "union_type",
  "named_type",
}

function PropertyHooks:new()
  return setmetatable({}, { __index = self })
end

function PropertyHooks:run()
  local M = PropertyHooks:new()
  if not M:get_position() then
    return
  end

  vim.ui.select(HOOK_TYPES, { prompt = "Property Hook Type:" }, function(choice)
    if not choice then
      return
    end

    if choice == "Simple" then
      M:create_simple_hooks()
    elseif choice == "Validated" then
      M:create_validated_hooks()
    end
  end)
end

function PropertyHooks:get_position()
  -- Find property declaration node
  self.parent = tree.parent("property_declaration")
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

  -- Extract variable name
  self.property = tree.children(self.parent.node, "property_element")
  if not self.property then
    return false
  end

  self.variable = tree.children(self.property.node, "variable_name")
  if not self.variable then
    return false
  end

  return true
end

function PropertyHooks:create_simple_hooks()
  if not self.variable or not self.union then
    vim.notify("Unable to create property hooks: missing variable or type", vim.log.levels.ERROR)
    return
  end

  local var_name = self.variable.text
  local property_name = string.dltfirst(var_name) -- Remove $
  local type_hint = self.union.text

  -- Build the property declaration with hooks
  local hook_syntax = string.format(
    "public %s $%s {\n        get => $this->_%s,\n        set($value) => $this->_%s = $value,\n    }",
    type_hint,
    property_name,
    property_name,
    property_name
  )

  -- Replace current property with hook-based property
  self:replace_property_with_hooks(hook_syntax)
end

function PropertyHooks:create_validated_hooks()
  if not self.variable or not self.union then
    vim.notify("Unable to create property hooks: missing variable or type", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({
    prompt = "Enter validation logic (or leave empty for basic validation): ",
    completion = "expression",
  }, function(validation_expr)
    if validation_expr == nil then
      return
    end

    local var_name = self.variable.text
    local property_name = string.dltfirst(var_name) -- Remove $
    local type_hint = self.union.text

    -- Build hook syntax with validation
    local hook_syntax
    if validation_expr == "" then
      -- Basic type validation
      hook_syntax = string.format(
        "public %s $%s {\n        get => $this->_%s,\n        set($value) {\n            if (!is_a($value, %s::class)) throw new \\TypeError('Expected %s');\n            $this->_%s = $value;\n        }\n    }",
        type_hint,
        property_name,
        property_name,
        type_hint,
        type_hint,
        property_name
      )
    else
      -- Custom validation logic
      hook_syntax = string.format(
        "public %s $%s {\n        get => $this->_%s,\n        set($value) {\n            %s\n            $this->_%s = $value;\n        }\n    }",
        type_hint,
        property_name,
        property_name,
        validation_expr,
        property_name
      )
    end

    self:replace_property_with_hooks(hook_syntax)
  end)
end

function PropertyHooks:replace_property_with_hooks(hook_syntax)
  -- Get current buffer content
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local property_start_line = nil
  local property_end_line = nil

  -- Find the property declaration in the buffer
  for i, line in ipairs(content) do
    if line:match(self.variable.text) and line:match("public") then
      property_start_line = i - 1 -- Convert to 0-indexed
      -- Find the end of the property (semicolon or end of declaration)
      for j = i, #content do
        if content[j]:match(";$") then
          property_end_line = j - 1
          break
        end
      end
      break
    end
  end

  if not property_start_line or not property_end_line then
    vim.notify("Could not find property declaration in buffer", vim.log.levels.ERROR)
    return
  end

  -- Replace the property with hook syntax
  vim.api.nvim_buf_set_lines(0, property_start_line, property_end_line + 1, false, { hook_syntax })

  -- Also create backing field
  local property_name = string.dltfirst(self.variable.text)
  local backing_field = string.format("    private %s $_%s;", self.union.text, property_name)

  -- Insert backing field before the property
  vim.api.nvim_buf_set_lines(0, property_start_line, property_start_line, false, { backing_field })

  -- Save the file
  vim.api.nvim_buf_call(0, function()
    vim.cmd("silent! write! | edit")
  end)

  vim.notify("Property hooks created successfully", vim.log.levels.INFO)
end

return PropertyHooks
