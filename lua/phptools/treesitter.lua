local ts, api = vim.treesitter, vim.api
local M = {}

M.cursor = function()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  local node = ts.get_node({ buffer = 0, pos = { row - 1, col - 1 } })
  return node
end

M.get_text = function(node)
  node = node or M.cursor()
  return ts.get_node_text(node, 0, {}) -- empty brackets are important
end

M.parent = function(type)
  local node = M.cursor()
  while node and node:type() ~= type do
    node = node:parent()
  end
  if node ~= nil then
    return { node = node, text = M.get_text(node), type = node:type() }
  end
end

-- named child
-- node text range
M.child = function(cnode, cname)
  for node, name in cnode:iter_children() do
    if node:named() then
      if name == cname then
        return { node = node, text = M.get_text(node), range = { node:range() } }
      end
    end
  end
end

-- unnamed typed
-- node text range
M.child_type = function(node, type)
  while node do
    if node:type() == type then
      return { node = node, text = M.get_text(node), range = { node:range() } }
    end
    node = node:child()
  end
  -- return node, M.get_text(node), { node:range() }
end

M.children = function(cnode, type)
  cnode = cnode or M.cursor()
  for node, _ in cnode:iter_children() do
    if node:type() == type then
      return { node = node, text = M.get_text(node), range = { node:range() } }
    end
  end
end

return M
