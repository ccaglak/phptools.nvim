local tree = require("phptools.treesitter")
local namespace = require("phptools.namespace")
local composer = require("phptools.composer")
local Class = {}

function Class:new()
    local t = setmetatable({}, { __index = Class })

    t.params = vim.lsp.util.make_position_params()
    t.constructor = false
    --
    self.class_position = function()
        t.params.position = {
            character = t.class_name.range[2] + 1,
            line = t.class_name.range[1],
        }
        return t.params
    end
    return t
end

Class.templates = {
    class_interface_clause = "interface",
    base_clause = "class",
    object_creation_expression = "class",
    scoped_call_expression = "class",
    use_declaration = "trait",
    class_constant_access_expression = "enum",
}

--
--
function Class:run()
    local M = Class:new()
    M.parent = M:get_parent()
    if M.parent == nil then
        return
    end
    -- constructor
    if M.parent.type == "object_creation_expression" then
        local in_bracket = M.parent.text:match("%((.-)%)")
        if in_bracket ~= "" then
            -- TODO complete __contruct params
            -- local params = M.spliter(in_bracket, ",")
            M.constructor = true
        end
    end
    M.parent.text = M.parent.text:gsub("%b()", "")
    M.class_name = tree.children(M.parent.node, "name")

    --enums TODO bug -> HomeController::class
    if M.parent.type == "class_constant_access_expression" then
        ---@diagnostic disable-next-line: missing-parameter
        local enum_node = M.parent.node:child()
        if enum_node == nil then
            return
        end
        M.class_name = {
            node = enum_node,
            text = tree.get_text(enum_node),
            range = { enum_node:range() },
        }
    end

    M:get_location(M.class_position())
    if #M.file_location == 0 or M.file_location == nil then
        M.file_location = M:get_location(M.class_position(), "textDocument/definition")
    end

    if M.file_location ~= nil then
        vim.lsp.util.jump_to_location(M.file_location[1], "utf-8")
        return
    end

    local prefix, src = composer.composer()
    --
    --
    vim.ui.input({
        prompt = "Directory for " .. M.class_name.text .. ".php",
        completion = "dir",
        default = src,
    }, function(dir)
        if dir == nil then
            return
        end

        if string.starts(dir, sep) then
            dir = dir:sub(2)
        end

        if not string.ends(dir, sep) then
            dir = dir .. sep
        end

        if not string.ends(root, sep) then
            root = root .. sep
        end

        if vim.fn.isdirectory(dir) == 0 then
            vim.fn.mkdir(root .. dir, "p") -- create directory
        end

        M.file_ns = namespace:gen(dir, prefix, src)
        local current_ns = namespace:gen(dir, prefix, src, M.class_name.text)

        M:add_to_current_buffer({ current_ns })
        --
        local tmpl = M:template_builder()
        --
        local bufnr = M:get_bufnr(root .. sep .. dir .. M.class_name.text .. ".php")
        vim.api.nvim_set_option_value("filetype", "php", {
            buf = bufnr,
        })
        M:add_template_to_buffer(tmpl, bufnr)
        vim.api.nvim_set_current_buf(bufnr)

        local row = 9
        if M.constructor then
            row = 11
        end
        vim.api.nvim_buf_call(0, function()
            vim.cmd("silent! wall! | edit")
        end)
        vim.fn.cursor({ row, 9 })
    end)
    --
end

--
--
--
function Class:get_bufnr(filename)
    local buf_exists = vim.fn.bufexists(filename) ~= 0
    if buf_exists then
        return vim.fn.bufnr(filename)
    end

    return vim.fn.bufadd(filename)
end

--
--
--
function Class:add_template_to_buffer(lines, bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.fn.bufload(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end

--
--
--
function Class:add_to_current_buffer(lines)
    local insertion_line = Class:get_insertion_point()
    vim.api.nvim_buf_set_lines(0, insertion_line, insertion_line, true, lines)
end

--
--
--
function Class:get_parent()
    local ts_parents = {
        "object_creation_expression",       --class
        "base_clause",                      -- extends
        "class_interface_clause",           -- interface
        "use_declaration",                  -- trait
        "class_constant_access_expression", -- enum
        "scoped_call_expression",           --class
    }

    for _, type in ipairs(ts_parents) do
        local parent = tree.parent(type)
        if parent ~= nil then
            if parent.type == type then
                return parent
            end
        end
    end
end

--
--
--
function Class:template_builder()
    local template = self.templates[self.parent.type]
    local tmpl = {
        "<?php",
        "",
        "declare(strict_types=1);",
        "",
    }
    table.insert(tmpl, self.file_ns)
    table.insert(tmpl, "")
    table.insert(tmpl, template .. " " .. self.class_name.text)
    table.insert(tmpl, "{")
    if self.constructor then
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

--
--
--
function Class:get_location(params, method)
    method = method or "textDocument/typeDefinition"

    local results, err = vim.lsp.buf_request_sync(0, method, params, 1000)
    if err or results == nil or #results == 0 then
        return
    end

    for _, v in pairs(results) do
        self.file_location = v.result
        return
    end
end

--
--
--
function Class:get_insertion_point()
    -- local lastline = vim.api.nvim_buf_line_count(bufnr)
    -- TODO dont want to read whole file 1/4
    local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local insertion_point = nil

    for i, line in ipairs(content) do
        if line:find("^declare") or line:find("^namespace") or line:find("^use") then
            insertion_point = i
        end

        if
            line:find("^class")
            or line:find("^final")
            or line:find("^interface")
            or line:find("^abstract")
            or line:find("^trait")
            or line:find("^enum")
        then
            break
        end
    end

    return insertion_point or 3
end

return Class
