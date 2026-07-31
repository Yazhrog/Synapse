return {
    -- {
    --     "simrat39/rust-tools.nvim",
    --     config = function()
    --         local capabilities = require("blink.cmp").get_lsp_capabilities()
    --         require("rust-tools").setup({
    --             server = {
    --                 capabilities = capabilities,
    --             },
    --         })
    --     end,
    -- },

    {
        "github/copilot.vim",
        config = function()
            vim.g.copilot_no_tab_map = true
            vim.api.nvim_set_keymap("i", "<C-Tab>", 'copilot#Accept("\\<CR>")', {
                expr = true,
                replace_keycodes = false,
            })
        end,
    },

    -- {
    --     "j-hui/fidget.nvim",
    --     event = "LspAttach",
    --     config = true,
    -- },
    --
    {
        "toppair/peek.nvim",
        event = { "VeryLazy" },
        build = "deno task --quiet build:fast",
        config = function()
            require("peek").setup({
                auto_load = false,
                app = "browser",
            })
            vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
            vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
        end,
    },

    -- {
    --     "luckasRanarison/tailwind-tools.nvim",
    --     name = "tailwind-tools",
    --     build = ":UpdateRemotePlugins",
    --     dependencies = {
    --         "nvim-treesitter/nvim-treesitter",
    --         "nvim-telescope/telescope.nvim",
    --         "neovim/nvim-lspconfig",
    --     },
    --     opts = {}, -- your configuration
    -- },
}
