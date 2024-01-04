local M = {}

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
