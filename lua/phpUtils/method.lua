local tree = require("phpUtils.treesitter")

local M = {}

local codes = {
    method = "P1013", -- intelephense code method not defined
    class = "P1009", -- intelephense class not defined
}

M.method = function()
    local filename, method_name = M.get_location()
    if filename == nil then
        return
    end

    filename = filename:gsub("file://", "")

    local bufnr = M.get_bufnr(filename)
    local lines = {
        "    public function " .. method_name .. "()",
        "    {",
        "         ",
        "    }",
    }

    vim.fn.bufload(bufnr)
    local lastline = vim.api.nvim_buf_line_count(bufnr)

    M.add_to_buffer(lines, bufnr, lastline)
    vim.cmd.e(filename)
    -- vim.api.nvim_set_current_buf(bufnr)
    vim.fn.cursor({ lastline + 2, 9 })
end

M.get_bufnr = function(filename)
    local buf_exists = vim.fn.bufexists(filename) ~= 0
    if buf_exists then
        return vim.fn.bufnr(filename)
    end

    return vim.fn.bufadd(filename)
end

M.add_to_buffer = function(lines, bufnr, lastline)
    bufnr = bufnr or M.get_bufnr()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        print("not valid")
        return
    end
    vim.api.nvim_buf_set_lines(bufnr, lastline - 1, lastline - 1, true, lines)
end

M.get_location = function()
    local parent = tree.parent("member_call_expression")
    if parent == nil then
        return
    end

    local child, child_name, child_range = tree.child_type(parent, "variable_name")
    if child == nil then
        return
    end

    local child_pos = {
        character = child_range[2] + 1,
        line = child_range[1],
    }

    -------- name node
    local name_node, name_name, name_range = tree.child(parent, "name")
    local name_pos = {
        character = name_range[2] + 1,
        line = name_range[1],
    }

    local file_location = M._lsp(name_pos, "textDocument/definition")

    if #file_location >= 1 then
        local loc = vim.lsp.util.make_position_params()

        if file_location[1].targetUri == loc.textDocument.uri then
            if child_name == "$this" then
                return file_location[1].targetUri, name_name
            end
        end
        vim.lsp.util.jump_to_location(file_location[1], "utf-8")
        return
    end

    local file_location = M._lsp(child_pos)

    if file_location == nil then
        return
    end
    return file_location[1].uri, name_name
end

M._lsp = function(pos, method)
    method = method or "textDocument/typeDefinition"

    local params = vim.lsp.util.make_position_params()
    params.position = pos

    local results, err = vim.lsp.buf_request_sync(0, method, params, 1000)
    if err or results == nil or #results == 0 then
        return
    end

    local rs = {}
    for _, v in pairs(results) do
        return vim.list_extend(rs, v.result)
    end
end

return M
