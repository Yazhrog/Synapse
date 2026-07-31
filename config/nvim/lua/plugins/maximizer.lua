return {
    "szw/vim-maximizer",
    config = function()
        local keymap = vim.keymap.set
        keymap("n", "<leader>m", ":MaximizerToggle<CR>", { desc = "Toggle window maximizer" })
    end,
}
