return {
    "karb94/neoscroll.nvim",
    opts = {},
    config = function()
        require("neoscroll").setup({
            cursor_scrolls_alone = false,
        })
    end,
}
