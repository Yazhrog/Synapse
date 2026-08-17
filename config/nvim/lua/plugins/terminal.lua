return {
    "nvzone/floaterm",
    dependencies = "nvzone/volt",
    opts = {},
    event = "VeryLazy",
    config = function()
        vim.keymap.set({ "n", "t" }, "``", "<Esc><C-\\><C-n>:FloatermToggle<CR>", { desc = "Toggle Terminal" })
        vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit Terminal Mode" })
    end,
}
