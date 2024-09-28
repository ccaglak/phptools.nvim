local M = {}

local default_word_arrays = {
    { "public",    "protected",    "private" },
    { "self",      "static" },
    { "true",      "false" },
    { "require",   "include" },
    { "abstract",  "final" },
    { "class",     "interface",    "trait",       "enum" },
    { "string",    "int",          "float",       "bool", "array" },
    { "array_map", "array_filter", "array_reduce" },
}

local fn = vim.fn

local operator_toggles = {
    ["=="] = "===",
    ["==="] = "==",
    ["!="] = "!==",
    ["!=="] = "!=",
    [">"] = ">=",
    [">="] = ">",
    ["<"] = "<=",
    ["<="] = "<",
    ["&&"] = "||",
    ["||"] = "&&",
    ["++"] = "--",
    ["--"] = "++",
    ['->'] = "=>",
    ["=>"] = "->",
}

local function toggle_operator()
    local line = fn.getline(".")
    local col = fn.col(".")
    local operator = line:sub(col - 1, col + 1)

    local toggle = operator_toggles[operator]
    if toggle then
        fn.setline(".", line:sub(1, col - 2) .. toggle .. line:sub(col + 2))
        return true
    end
    return false
end

local word_lookup = setmetatable({}, {
    __index = function(t, k)
        for _, array in ipairs(default_word_arrays) do
            local index = vim.tbl_contains(array, k) and vim.tbl_indexof(array, k) or nil
            if index then
                local value = {
                    next = array[index % #array + 1],
                    prev = array[(index - 2) % #array + 1]
                }
                rawset(t, k, value)
                return value
            end
        end
    end
})

local ctrl_a = vim.api.nvim_replace_termcodes("<C-a>", true, false, true)
local ctrl_x = vim.api.nvim_replace_termcodes("<C-x>", true, false, true)

local function toggle_words(direction)
    if toggle_operator() then
        return
    end

    local word = fn.expand("<cword>")
    local next_word = word_lookup[word] and word_lookup[word][direction]

    if next_word then
        fn.setline(".", fn.substitute(fn.getline("."), "\\<" .. word .. "\\>", next_word, ""))
        return
    end
    local key = direction == "next" and ctrl_a or ctrl_x
    vim.api.nvim_feedkeys(key, "n", false)
end

function M.setup(config)
    config = config or {}
    local custom_toggles = config.custom_toggles or {}
    default_word_arrays = vim.tbl_deep_extend("force", default_word_arrays, custom_toggles)

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "php",
        callback = function()
            local buf = vim.api.nvim_get_current_buf()
            vim.keymap.set(
                "n",
                "<C-a>",
                function() vim.schedule(function() toggle_words("next") end) end,
                { buffer = buf, noremap = true, silent = true, desc = "Toggle PHP words forward or increment" }
            )
            vim.keymap.set(
                "n",
                "<C-x>",
                function() vim.schedule(function() toggle_words("prev") end) end,
                { buffer = buf, noremap = true, silent = true, desc = "Toggle PHP words backward or decrement" }
            )
        end,
    })
end

return M
