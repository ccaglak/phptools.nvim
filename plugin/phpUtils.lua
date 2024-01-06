vim.api.nvim_create_user_command("PhpMethod", require("phpUtils").method, {})
vim.api.nvim_create_user_command("PhpClass", require("phpUtils").class, {})
vim.api.nvim_create_user_command("PhpScripts", require("phpUtils").commands, {})
vim.api.nvim_create_user_command("PhpNamespace", require("phpUtils").name_space, {})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    callback = function(event)
        if event.match:match("^%w%w+://") then
            return
        end
        local file = vim.loop.fs_realpath(event.match) or event.match
        vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
})
