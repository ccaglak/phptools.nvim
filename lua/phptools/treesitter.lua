local ts, api = vim.treesitter, vim.api
local M = {}

--- Normalize a treesitter node into standard format
-- @param node userdata Treesitter node to normalize
-- @return table|nil Normalized node table {node, text, range, type} or nil if node is invalid
-- @private
local function normalize(node)
  if not node then
    return nil
  end
  local sr, sc, er, ec = node:range()
  return {
    node = node,
    text = ts.get_node_text(node, 0, {}),
    range = { sr, sc, er, ec },
    type = node:type(),
  }
end

--- Get raw node at cursor position with error handling
-- Tries main cursor position, falls back to column 0 if out of bounds
-- @return userdata|nil Raw treesitter node or nil if invalid position
-- @private
local function get_raw_cursor_node()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1 -- Convert from 1-indexed to 0-indexed
  if row < 0 or col < 0 then
    return nil
  end

  local ok, node = pcall(function()
    return ts.get_node({ buffer = 0, pos = { row, col } })
  end)
  if ok and node then
    return node
  end

  -- Fallback: try with col=0 if column is at or beyond line end
  local ok2, node2 = pcall(function()
    return ts.get_node({ buffer = 0, pos = { row, 0 } })
  end)
  return ok2 and node2 or nil
end

--- Helper to ensure node is a raw node (unwrap if normalized)
-- @param node userdata|table Node or normalized node table
-- @return userdata|nil Raw treesitter node or nil
-- @private
local function ensure_raw_node(node)
  if not node then
    return nil
  end
  if node.node then
    return node.node -- It's a normalized table
  end
  return node -- It's already a raw node
end

--- Get normalized node at cursor position
-- @return table|nil Normalized node {node, text, range, type} or nil if invalid
function M.cursor()
  local node = get_raw_cursor_node()
  return normalize(node)
end

--- Get text from a node (raw or normalized)
-- @param node userdata|table Treesitter node (raw or normalized format)
-- @return string|nil Node text or nil if invalid
function M.get_text(node)
  node = ensure_raw_node(node) or get_raw_cursor_node()
  if not node then
    return nil
  end
  return ts.get_node_text(node, 0, {})
end

--- Find parent node of given type, walking up from current node
-- @param node userdata|table Starting node (raw or normalized)
-- @param node_type string Type of parent to find
-- @return table|nil Normalized parent node or nil if not found
function M.find_parent(node, node_type)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  while parent do
    if parent:type() == node_type then
      return normalize(parent)
    end
    parent = parent:parent()
  end
  return nil
end

--- Find nearest ancestor matching any of the given types
-- @param node userdata|table Starting node (raw or normalized)
-- @param node_types table Array of node types to match
-- @return table|nil Normalized ancestor node or nil if not found
function M.find_ancestor_of_types(node, node_types)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  local parent = node:parent()
  while parent do
    for _, node_type in ipairs(node_types) do
      if parent:type() == node_type then
        return normalize(parent)
      end
    end
    parent = parent:parent()
  end
  return nil
end

--- Get normalized node at cursor if it matches given type
-- @param node_type string Type to match against cursor node
-- @return table|nil Normalized node if type matches, nil otherwise
function M.get_cursor_node_if_type(node_type)
  local node = get_raw_cursor_node()
  if node and node:type() == node_type then
    return normalize(node)
  end
  return nil
end

--- Find parent of given type, starting from cursor
-- @param node_type string Type of parent to find
-- @return table|nil Normalized parent node or nil if not found
function M.parent(node_type)
  local node = get_raw_cursor_node()
  return M.find_parent(node, node_type)
end

--- Get child by name (named child only)
-- @param node userdata|table Parent node (raw or normalized)
-- @param child_name string Name of child to find
-- @return table|nil Normalized child node or nil if not found
function M.child(node, child_name)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  for child_node, name in node:iter_children() do
    if child_node:named() and name == child_name then
      return normalize(child_node)
    end
  end
  return nil
end

--- Get first child matching type by walking down AST
-- @param node userdata|table Starting node (raw or normalized)
-- @param child_type string Type of child to find
-- @return table|nil Normalized child node or nil if not found
function M.child_type(node, child_type)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  while node do
    if node:type() == child_type then
      return normalize(node)
    end
    node = node:child()
  end
  return nil
end

--- Get first child of given type (iterates immediate children)
-- Alias for compatibility and clarity: gets first child of type, not all children
-- @param node userdata|table Parent node (raw or normalized)
-- @param child_type string Type of child to find
-- @return table|nil Normalized child node or nil if not found
function M.first_child_of_type(node, child_type)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  for child_node, _ in node:iter_children() do
    if child_node:type() == child_type then
      return normalize(child_node)
    end
  end
  return nil
end

--- Get all children of given type
-- @param node userdata|table Parent node (raw or normalized)
-- @param child_type string Type of children to find
-- @return table Array of normalized child nodes matching type
function M.all_children_of_type(node, child_type)
  node = ensure_raw_node(node)
  if not node then
    return {}
  end

  local results = {}
  for child_node, _ in node:iter_children() do
    if child_node:type() == child_type then
      table.insert(results, normalize(child_node))
    end
  end
  return results
end

--- Legacy aliases for backward compatibility
M.cnode = M.cursor
M.ctnode = M.get_cursor_node_if_type
M.children = M.first_child_of_type

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ BLADE-SPECIFIC AST HELPERS                                                  │
-- │                                                                              │
-- │ Specialized utilities for tree-sitter-blade sibling node structures.        │
-- │ Key insight: blade directives and parameters are siblings, not nested.      │
-- │                                                                              │
-- │ Pattern:                                                                    │
-- │   element (or root)                                                         │
-- │     ├─ directive (@include)  [sibling]                                      │
-- │     └─ parameter ('file')    [sibling]                                      │
-- └─────────────────────────────────────────────────────────────────────────────┘

--- Find first next sibling with matching node type
-- Blade-specific: handles sibling node navigation for directive/parameter pairs
-- @param node userdata|table The starting node (raw or normalized)
-- @param node_type string The type to match
-- @return userdata|nil The matching sibling node (raw) or nil
function M.find_next_sibling(node, node_type)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  local sibling = node:next_sibling()
  while sibling do
    if sibling:type() == node_type then
      return sibling
    end
    sibling = sibling:next_sibling()
  end

  return nil
end

--- Find first previous sibling with matching node type
-- Blade-specific: for finding directive before parameter
-- @param node userdata|table The starting node (raw or normalized)
-- @param node_type string The type to match
-- @return userdata|nil The matching sibling node (raw) or nil
function M.find_prev_sibling(node, node_type)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  local sibling = node:prev_sibling()
  while sibling do
    if sibling:type() == node_type then
      return sibling
    end
    sibling = sibling:prev_sibling()
  end

  return nil
end

--- Alias for find_next_sibling (clarity for directive parsing)
function M.find_next_matching_sibling(node, node_type)
  return M.find_next_sibling(node, node_type)
end

--- Alias for find_prev_sibling (clarity for directive parsing)
function M.find_prev_matching_sibling(node, node_type)
  return M.find_prev_sibling(node, node_type)
end

--- Iterate over all next siblings of a node
-- Blade-specific: walk through sibling chain
-- @param node userdata|table The starting node (raw or normalized)
-- @param node_type string|nil Optional type to filter by
-- @return function Iterator that yields raw sibling nodes
function M.iter_next_siblings(node, node_type)
  node = ensure_raw_node(node)
  if not node then
    return function()
      return nil
    end
  end

  local current = node:next_sibling()
  return function()
    while current do
      local sibling = current
      current = current:next_sibling()

      if not node_type or sibling:type() == node_type then
        return sibling
      end
    end
    return nil
  end
end

--- Safely get text from node with fallback value
-- Blade-specific: handles extraction failures gracefully
-- @param node userdata|table The node to extract text from
-- @param default string|nil Default value if extraction fails
-- @return string|nil The text content or default
function M.get_text_safe(node, default)
  node = ensure_raw_node(node)
  if not node then
    return default or nil
  end

  local ok, text = pcall(function()
    return ts.get_node_text(node, 0, {})
  end)

  return ok and text or (default or nil)
end

--- Get text of a node, trying multiple extraction methods
-- Blade-specific: robust extraction for edge cases
-- @param node userdata|table The node to extract text from
-- @return string|nil The text content or nil
function M.get_text_robust(node)
  node = ensure_raw_node(node)
  if not node then
    return nil
  end

  -- Try primary method
  local ok, text = pcall(function()
    return ts.get_node_text(node, 0, {})
  end)

  if ok and text then
    return text
  end

  -- Try alternative: combine children
  local children = M.all_children_of_type(node, "")
  if #children > 0 then
    local parts = {}
    for _, child_norm in ipairs(children) do
      local child_text = M.get_text_safe(child_norm.node)
      if child_text then
        table.insert(parts, child_text)
      end
    end
    if #parts > 0 then
      return table.concat(parts, "")
    end
  end

  return nil
end

--- Check if node is of a specific type
-- Blade-specific: type checking with nil safety
-- @param node userdata|table The node to check
-- @param node_type string The type to match
-- @return boolean True if node type matches
function M.is_type(node, node_type)
  node = ensure_raw_node(node)
  return node and node:type() == node_type or false
end

--- Find all ancestors of a node up to root
-- Blade-specific: useful for context detection
-- @param node userdata|table The starting node (raw or normalized)
-- @return table Array of normalized ancestor nodes
function M.get_ancestors(node)
  node = ensure_raw_node(node)
  local ancestors = {}

  local current = node
  while current do
    table.insert(ancestors, normalize(current))
    current = current:parent()
  end

  return ancestors
end

return M
