return {
    "folke/twilight.nvim",
    config = function()
        require("twilight").setup()
        local keymap = vim.keymap.set

        -- Twilight mapping
        keymap("n", "<leader>tw", ":Twilight<CR>", { desc = "Enable Twilight" })
    end,
}
