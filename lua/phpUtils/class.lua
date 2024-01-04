local tree = require("phpUtils.treesitter")
local cmp = require("phpUtils.composer")

local M = {}

local templates = {
    class_interface_clause = "interface",
    base_clause = "class",
    object_creation_expression = "class",
    use_declaration = "trait",
    class_constant_access_expression = "enum",
}

M.class = function()
    -- local cWord = vim.fn.escape(vim.fn.expand("<cword>"), [[\/]])
    local sep = M.sep()
    local parent, parent_type, parent_text = M.get_parent()
    if not parent_type or not parent_text then
        return
    end

    local constructor = false
    if parent_type == "object_creation_expression" then
        local in_bracket = parent_text:match("%((.-)%)")
        if in_bracket ~= "" then
            -- TODO complete __contruct params
            -- local params = M.spliter(in_bracket, ",")
            constructor = true
        end
    end

    parent_text = parent_text:gsub("%b()", "") -- gsub to empty the bracket

    ----------------------

    local name_node, name_name, name_range = tree.children(parent, "name")

    if parent_type == "class_constant_access_expression" then
        name_node = parent:child()
        name_name = tree.get_text(name_node)
        name_range = { name_node:range() }
    end

    local name_pos = {
        character = name_range[2] + 1,
        line = name_range[1],
    }

    local file_location = M._lsp(name_pos)
    if #file_location == 0 then
        file_location = M._lsp(name_pos, "textDocument/definition")
    end

    local loc = vim.lsp.util.make_position_params()

    if #file_location >= 1 then
        if file_location[1].targetUri == loc.textDocument.uri then
            return
        end
        vim.lsp.util.jump_to_location(file_location[1], "utf-8")
        return
    end

    ----------------------
    local fname = name_name

    local prefix, dir = cmp.composer()

    local path = loc.textDocument.uri:gsub("file://", "")

    local root = require("phpUtils.root").root() .. sep

    path = path:gsub(root, "")

    path = vim.fn.fnamemodify(path, ":h")

    if path == "." then
        path = "src/"
    end

    local template = templates[parent_type]

    vim.ui.input({
        prompt = "Directory for " .. fname .. ".php",
        completion = "dir",
        default = path,
    }, function(dr)
        if dr == nil then
            return
        end
        local filename = root .. dr .. fname .. ".php"

        local namespace = require("phpUtils.namespace").gen(root, filename, prefix, dir)

        local current_namespace = require("phpUtils.namespace").gen(root, filename, prefix, dir, true)

        M.add_to_current_buffer({ current_namespace .. fname .. ";" })

        local tmpl = M.template_builder(template, fname, namespace, constructor)

        local bufnr = M.get_bufnr(filename)
        vim.api.nvim_set_option_value("filetype", "php", {
            buf = bufnr,
        })
        M.add_to_buffer(tmpl, bufnr)
        -- vim.cmd.e(filename)
        vim.api.nvim_set_current_buf(bufnr)

        local row = 9
        if constructor then
            row = 11
        end
        vim.api.nvim_buf_call(0, function()
            vim.cmd("silent! write! | edit")
        end)
        vim.fn.cursor({ row, 9 })
    end)
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
        table.insert(tmpl, "    public function __contruct()")
        table.insert(tmpl, "    {")
        table.insert(tmpl, "        //")
        table.insert(tmpl, "    }")
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

M.add_to_current_buffer = function(lines, bufnr)
    bufnr = bufnr or 0
    -- TODO implement insertion point
    vim.api.nvim_buf_set_lines(bufnr, 3, 3, true, lines)
end

M.sep = function()
    local win = vim.loop.os_uname().sysname == "Darwin" or "Linux"
    return win and "/" or "\\"
end

M.get_parent = function()
    local ts_parents = {
        "object_creation_expression", --class
        "base_clause", -- extends
        "class_interface_clause", -- interface
        "use_declaration", -- trait
        "class_constant_access_expression", -- enum
    }

    for i, type in ipairs(ts_parents) do
        local parent = tree.parent(type)
        if parent ~= nil then
            if parent:type() == type then
                return parent, type, tree.get_text(parent)
            end
        end
    end
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

M.get_insertion_point = function(bufnr)
    local lastline = vim.api.nvim_buf_line_count(bufnr)
    -- TODO dont want to read whole file 1/4
    local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    local insertion_point = nil

    for i, line in ipairs(content) do
        if line:find("^declare") or line:find("^namespace") or line:find("^use") then
            insertion_point = insertion_point + 1
        end

        if
            line:find("^class")
            or line:find("^final")
            or line:find("^interface")
            or line:find("^abstract")
            or line:find("^trait")
        then
            break
        end
    end

    return insertion_point or 3
end

return M
