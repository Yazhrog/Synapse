return {
    "folke/noice.nvim",
    event = "VeryLazy", -- loads the plugin when Neovim is less busy
    opts = {
        lsp = {
            -- Override some default LSP markdown rendering functions so that
            -- plugins like cmp and others can leverage Treesitter for better formatting.
            override = {
                ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                ["vim.lsp.util.stylize_markdown"] = true,
                ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
            },
        },
        presets = {
            bottom_search = true, -- Use a classic bottom command-line for search
            command_palette = true, -- Position the command-line and popupmenu together
            long_message_to_split = true, -- Send long messages to a split window
            inc_rename = false, -- Disable the input dialog for inc-rename.nvim
            lsp_doc_border = false, -- Do not add a border to LSP hover docs and signature help
        },
    },
    config = function(_, opts)
        require("noice").setup(opts)
    end,
    dependencies = {
        "MunifTanjim/nui.nvim",
        "rcarriga/nvim-notify",
    },
}
