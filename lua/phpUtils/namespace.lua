local M = {}

M.nspace = function()
    local sep = M.sep()
    local prefix, dir = require("phpUtils.composer").composer()

    local loc = vim.lsp.util.make_position_params()
    local path = loc.textDocument.uri:gsub("file://", "")

    local root = require("phpUtils.root").root() .. sep

    local ns = M.gen(root, path, prefix, dir)

    vim.api.nvim_buf_set_lines(0, 3, 3, true, { ns })
end

M.sep = function()
    local win = vim.loop.os_uname().sysname == "Darwin" or "Linux"
    return win and "/" or "\\"
end

M.gen = function(root, path, prefix, src, current)
    current = current or false
    path = path:gsub(root, "")

    local filename = vim.fn.fnamemodify(path, ":t")

    local bpath = path:gsub(filename, ""):sub(1, -2):gsub("/", "\\")

    local prefx = M.pascalCase(prefix, "\\\\")

    src = src:sub(1, -2)
    path = bpath:gsub(src, prefx)

    path = M.pascalCase(path)

    if current then
        return "use " .. path .. "\\"
    end

    path = "namespace " .. path .. ";"
    return path
end

M.pascalCase = function(path, split)
    if not path then
        return
    end
    local split_path = M.spliter(path, split)
    local custom_path = ""
    for _, value in pairs(split_path) do
        custom_path = custom_path .. (value:gsub("^%l", string.upper)) .. "\\"
    end
    return custom_path:sub(1, -2)
end

M.spliter = function(path, sep)
    sep = sep or "\\"
    local format = string.format("([^%s]+)", sep)
    local t = {}
    for str in string.gmatch(path, format) do
        table.insert(t, str)
    end
    return t
end

return M
