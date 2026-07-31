return {
    "akinsho/bufferline.nvim",
    dependencies = "kyazdani42/nvim-web-devicons",
    config = function()
        vim.opt.termguicolors = true
        require("bufferline").setup({
            options = {
                separator_style = "slope",
                indicator = {
                    style = "underline",
                },

                -- close_command = function(bufnr)
                --     local api = vim.api
                --
                --     vim.cmd("bdelete! " .. bufnr)
                --
                --     local buffers = vim.fn.getbufinfo({ buflisted = 1 })
                --     if #buffers == 0 then
                --         return
                --     end
                --
                --     local current_buf = api.nvim_get_current_buf()
                --     local current_name = api.nvim_buf_get_name(current_buf)
                --
                --     -- If current is NvimTree or unlisted, switch to first listed buffer
                --     if not api.nvim_buf_is_loaded(current_buf) or current_name:match("NvimTree_") then
                --         vim.cmd("buffer " .. buffers[1].bufnr)
                --     end
                -- end,
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = "Nvim Tree",
                        separator = false,
                        text_align = "center",
                    },
                    {
                        filetype = "snacks_layout_box",
                        text = "",
                        separator = true,
                    },
                },
            },
        })

        local keymap = vim.keymap.set

        -- Navigate between buffers using Alt+Left/Right
        keymap("n", "<A-Left>", "<Cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
        keymap("n", "<A-Right>", "<Cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })

        -- Re-order buffers
        keymap("n", "<A-s>", "<Cmd>BufferLineSortByDirectory<CR>", { desc = "Sort Tabs by directory" })

        -- Close buffer
        keymap("n", "<leader>qp", "<Cmd>BufferLinePickClose<CR>", { desc = "Close picked buffer" })
        keymap("n", "<leader>qa", "<Cmd>BufferLineCloseOthers<CR>", { desc = "Close all except current buffer" })
    end,
}
