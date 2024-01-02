local tree = require("phpUtils.treesitter")
local cmp = require("phpUtils.composer")

local M = {}

local templates = {
    class_interface_clause = "interface",
    base_clause = "class",
    object_creation_expression = "class",
    use_declaration = "trait",
}

M.class = function()
    -- local cWord = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]])
    local sep = M.sep()
    local parent, type = M.get_parent()
    if not type then
        return
    end

    local diag = M.diagnostics()
    if diag == nil then
        return
    end

    local parent_text = tree.get_text(parent)
    local constructor = false
    if type == "object_creation_expression" then
        local in_bracket = parent_text:match("%((.-)%)")
        if in_bracket ~= "" then
            -- TODO complete __contruct params
            -- local params = M.spliter(in_bracket, ",")
            constructor = true
        end
    end

    parent_text = parent_text:gsub("%b()", "") -- gsub to empty the bracket

    local split = M.spliter(parent_text)
    local fname = split[2]

    local prefix, dir = cmp.composer()

    local root = vim.fn.expand("%:p:h") .. sep

    local template = templates[type]

    vim.ui.input({
        prompt = "Directory for " .. split[2] .. ".php :",
        completion = "dir",
        default = dir,
    }, function(dr)
        if dr == nil then
            return
        end
        local filename = root .. dr .. split[2] .. ".php"
        local namespace = require("phpUtils.namespace").gen(root, filename, prefix, dir)
        local tmpl = M.template_builder(template, fname, namespace, constructor)

        if vim.fn.filereadable(filename) ~= 0 then
            vim.cmd.e(filename) -- this could also return
            return
        end

        local bufnr = M.get_bufnr(filename)
        vim.api.nvim_set_option_value("filetype", "php", {
            buf = bufnr,
        })
        M.add_to_buffer(tmpl, bufnr)
        vim.cmd.e(filename)
        -- -- vim.api.nvim_set_current_buf(bufnr)

        local row = 9
        if constructor then
            row = 11
        end
        vim.fn.cursor({ row, 9 })
    end)
end

M.template_builder = function(template, filename, namespace, constructor)
    local tmpl = {
        "<?php",
        "",
        "declare(strict_types=1);",
        "",
    }
    table.insert(tmpl, namespace)
    table.insert(tmpl, "")
    table.insert(tmpl, template .. " " .. filename)
    table.insert(tmpl, "{")
    if constructor then
        table.insert(tmpl, "     public function __contruct() :void {")
        table.insert(tmpl, "        //")
        table.insert(tmpl, "     }")
    else
        table.insert(tmpl, "        //")
    end
    table.insert(tmpl, "}")
    return tmpl
end

M.get_bufnr = function(filename)
    local buf_exists = vim.fn.bufexists(filename) ~= 0
    if buf_exists then
        return vim.fn.bufnr(filename)
    end

    return vim.fn.bufadd(filename)
end

M.add_to_buffer = function(lines, bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end

M.sep = function()
    local win = vim.loop.os_uname().sysname == "Darwin" or "Linux"
    return win and "/" or "\\"
end

M.get_parent = function()
    local ts_parents = {
        "class_interface_clause", -- interface
        "base_clause", -- extends
        "object_creation_expression",
        "use_declaration", -- trait
    }
    local parent
    for i, p in ipairs(ts_parents) do
        parent = tree.parent(p)
        if parent ~= nil then
            if parent:type() == p then
                return parent, p
            end
        end
    end
    return nil
end

M.spliter = function(path, sep)
    sep = sep or " "
    local format = string.format("([^%s]+)", sep)
    local t = {}
    for str in string.gmatch(path, format) do
        table.insert(t, str)
    end
    return t
end

M.diagnostics = function()
    local bufnr, lnum = unpack(vim.fn.getcurpos())
    local diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr, lnum - 1, {})
    if vim.tbl_isempty(diagnostics) then
        return
    end

    for _, diagnostic in ipairs(diagnostics) do
        if diagnostic.source == "intelephense" or diagnostic.source == "phpstan" then
            if diagnostic.code == "P1009" then
                return diagnostic, diagnostic.source
            end

            if diagnostic.message:match("Instantiated class") == "Instantiated class" then
                return diagnostic, diagnostic.source -- phpstan
            end
        end
    end
end

return M
