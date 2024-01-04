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
    return node
end

M.child_type = function(node, type)
    local cnod = node:child()
    while cnod do
        if cnod:type() == type then
            break
        end
        cnod = cnod:child()
    end
    return cnod
end

M.children = function(cnode, type)
    cnode = cnode or M.cursor()
    for node, _ in cnode:iter_children() do
        if node:type() == type then
            return M.get_text(node), node --  perhaps returning node could be better idea
        end
    end
end

return M
