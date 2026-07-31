return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
            "nvim-tree/nvim-web-devicons",
            "folke/todo-comments.nvim",
            "nvim-telescope/telescope-ui-select.nvim", -- Adds UI select extension
            "nvim-telescope/telescope-project.nvim", -- Adds project management
            "debugloop/telescope-undo.nvim", -- Adds undo history search
        },
        config = function()
            local telescope = require("telescope")

            telescope.setup({
                extensions = {
                    ["ui-select"] = { require("telescope.themes").get_dropdown({}) },
                    project = {
                        hidden_files = true,
                    },
                },
            })

            -- Load extensions
            telescope.load_extension("fzf")
            telescope.load_extension("ui-select")
            telescope.load_extension("project")
            telescope.load_extension("undo")

            -- Keybindings
            local keymap = vim.keymap.set

            keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
            keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
            keymap("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
            keymap("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
            keymap("n", "<leader>fp", "<cmd>Telescope project<cr>", { desc = "Find projects" })
            keymap("n", "<leader>fu", "<cmd>Telescope undo<cr>", { desc = "Undo history" })
        end,
    },
}
