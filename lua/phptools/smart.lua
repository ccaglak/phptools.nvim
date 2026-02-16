--[[
================================================================================
                            SMART DISPATCHER
================================================================================
Context-aware dispatcher that detects whether the current cursor position
is in a method or class context, then routes to the appropriate module.

Method contexts: member_call_expression, scoped_call_expression with ()
Class contexts: base_clause, class_interface_clause, use_declaration,
                object_creation_expression, simple_parameter
================================================================================
]]

local tree = require("phptools.treesitter")

local Smart = {}

-- Context type mappings: single source of truth
local CONTEXT_TYPE = {
  -- Method-only
  member_call_expression = "method",

  -- Class-only
  base_clause = "class",
  class_interface_clause = "class",
  use_declaration = "class",
  object_creation_expression = "class",
  simple_parameter = "class",

  -- Ambiguous (require heuristics)
  scoped_call_expression = "ambiguous",
  class_constant_access_expression = "ambiguous",
}

--[[
Normalize a raw treesitter node to standard format.
Returns: {node, text, range, type}
]]
local function normalize_node(raw_node)
  local sr, sc, er, ec = raw_node:range()
  return {
    node = raw_node,
    text = vim.treesitter.get_node_text(raw_node, 0, {}),
    range = { sr, sc, er, ec },
    type = raw_node:type(),
  }
end

--[[
Walk up AST from cursor position to find first detectable context node.
Returns: normalized node or nil
]]
function Smart:find_relevant_node()
  local cursor_node = tree.cursor()
  if not cursor_node then
    return nil
  end

  local current = cursor_node.node
  while current do
    if CONTEXT_TYPE[current:type()] then
      return normalize_node(current)
    end
    current = current:parent()
  end

  return nil
end

--[[
Analyze ambiguous context (scoped_call_expression or class_constant_access_expression).
Heuristics:
  - Parentheses () → method call
  - ALL_UPPERCASE name → constant/enum case
  - Otherwise → method
]]
local function analyze_ambiguous(node)
  -- Check for method call parentheses
  if node.text:match("()$") then
    return "method"
  end

  -- Check for uppercase constant name
  local name_node = tree.child(node.node, "name")
  if name_node and name_node.text and name_node.text:match("^[A-Z_][A-Z0-9_]*$") then
    return "class"
  end

  -- Default to method
  return "method"
end

--[[
Detect context type: "method", "class", or nil
]]
function Smart:detect_context(node)
  if not node then
    return "method"
  end

  local context = CONTEXT_TYPE[node.type]

  if context == "ambiguous" then
    return analyze_ambiguous(node)
  end

  return context or "method"
end

--[[
Main entry point: find context, detect type, run appropriate module
]]
function Smart:run()
  local node = self:find_relevant_node()

  if not node then
    vim.notify("Smart: No detectable context at cursor", vim.log.levels.WARN)
    return
  end

  local context_type = self:detect_context(node)

  -- Pass node to avoid redundant tree traversal
  _G._smart_detected_node = node

  if context_type == "class" then
    require("phptools.class"):new():run()
  else
    require("phptools.method"):new():run()
  end

  _G._smart_detected_node = nil
end

return Smart
