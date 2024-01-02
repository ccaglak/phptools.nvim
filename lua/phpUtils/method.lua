local tree = require("phpUtils.treesitter")

local M = {}

local codes = {
    method = "P1013", -- intelephense code method not defined
    class = "P1009", -- intelephense class not defined
}

M.method = function()
    local cWord = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]])
    local filename, method_name = M.get_location()
    if filename == nil or filename == "" then
        return
    end

    filename = filename:gsub("file://", "")

    -- this should be optional
    local diag, source = M.diagnostics()
    if diag == nil then
        return
    end
    if diag.source ~= "intelephense" then
        -- TODO match needs to checked
        local source = diag.source
        if diag.message:match("method") == "method" then
            diag.code = codes.method
        end
    end

    if not method_name then
        method_name = cWord
    end

    -- if diag.source == "intelephense" then
    --     local message = diag.message
    --     local diag_method_name = string.match(message, [['([^']+)]])
    -- end

    local bufnr = M.get_bufnr(filename)
    local lines = {
        "    public function " .. method_name .. "()",
        "    {",
        "         ",
        "    }",
    }

    vim.fn.bufload(bufnr)
    local lastline = vim.api.nvim_buf_line_count(bufnr)

    vim.cmd.e(filename)
    M.add_to_buffer(lines, bufnr, lastline)
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

    local child = tree.child_type(parent, "variable_name")
    if child == nil then
        return
    end

    local name_node = tree.child_type(parent, "name")
    local name = tree.get_text(name_node)

    -- if name_node == nil then
    --     return
    -- end

    local child_name = tree.get_text(child)
    if child_name == "$this" then
        return vim.fn.expand("%:p"), name
    end
    local child_pos = { child:range() } -- { 10, 0, 10, 7 }

    local positions = {
        character = child_pos[2] + 1,
        line = child_pos[1],
    }
    local file_location = M._lsp(positions)
    if file_location == nil then
        return
    end
    return file_location[1].uri, name
end

M._lsp = function(positions)
    local params = vim.lsp.util.make_position_params()
    params.position = positions

    results, err = vim.lsp.buf_request_sync(0, "textDocument/typeDefinition", params, 1000)
    if err or results == nil or #results == 0 then
        return
    end

    local rs = {}
    for _, v in pairs(results) do
        -- if v.result[1].uri:match("vendor") == "vendor" then
        --     return
        -- end
        return vim.list_extend(rs, v.result)
    end
end

M.diagnostics = function()
    local bufnr, lnum = unpack(vim.fn.getcurpos())
    local diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr, lnum - 1, {})
    if vim.tbl_isempty(diagnostics) then
        return
    end

    for _, diagnostic in ipairs(diagnostics) do
        if diagnostic.source == "intelephense" or diagnostic.source == "phpstan" then
            if diagnostic.code == "P1013" then
                return diagnostic, diagnostic.source
            end

            if diagnostic.message:match("undefined method") == "undefined method" then
                return diagnostic, diagnostic.source -- phpstan
            end
        end
    end
end

return M
