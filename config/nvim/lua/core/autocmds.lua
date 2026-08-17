vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        if vim.fn.argc() == 1 then
            local arg = vim.fn.argv(0)
            if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
                vim.cmd.tcd(vim.fn.fnamemodify(arg, ":p"))
            end
        end
    end,
})
