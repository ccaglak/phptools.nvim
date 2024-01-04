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

-- named child
-- node text range
M.child = function(cnode, cname)
    cnode = cnode or M.cursor()
    for node, name in cnode:iter_children() do
        if node:named() then
            if name == cname then
                return node, M.get_text(node), { node:range() }
            end
        end
    end
end

-- unnamed typed
-- node text range
M.child_type = function(cnod, type)
    while cnod do
        if cnod:type() == type then
            return cnod, M.get_text(cnod), { cnod:range() }
        end
        cnod = cnod:child()
    end
    -- return cnod, M.get_text(cnod), { cnod:range() }
end

M.children = function(cnode, type)
    cnode = cnode or M.cursor()
    for node, _ in cnode:iter_children() do
        if node:type() == type then
            return node, M.get_text(node), { node:range() }
        end
    end
end

function M.node_to_lsp_range(node)
    local start_line, start_col, end_line, end_col = ts.get_node_range(node)
    local rtn = {}
    rtn.start = { line = start_line, character = start_col }
    rtn["end"] = { line = end_line, character = end_col }
    return rtn
end

return M
