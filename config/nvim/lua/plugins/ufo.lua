return {
    "kevinhwang91/nvim-ufo",
    event = "BufRead", -- or whatever autocommand you prefer
    dependencies = "kevinhwang91/promise-async",
    config = function()
        vim.o.foldcolumn = "1" -- show a one-character fold column
        vim.o.foldlevel = 99 -- start with all folds open (ufo needs a large foldlevel)
        vim.o.foldlevelstart = 99
        vim.o.foldenable = true

        vim.keymap.set("n", "zr", require("ufo").openAllFolds, { desc = "open all folds" })
        vim.keymap.set("n", "zm", require("ufo").closeAllFolds, { desc = "close all folds" })
        vim.keymap.set("n", "zk", function()
            local winid = require("ufo").peekFoldedLinesUnderCursor()
            if not winid then
                vim.lsp.buf.hover()
            end
        end, { desc = "peek fold" })

        require("ufo").setup({
            provider_selector = function(bufnr)
                for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
                    if client.server_capabilities.foldingRangeProvider then
                        return { "lsp", "indent" }
                    end
                end
                return { "indent" }
            end,
        })
    end,
}
