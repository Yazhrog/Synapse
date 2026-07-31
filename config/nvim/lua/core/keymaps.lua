vim.g.mapleader = " "

local keymap = vim.keymap.set -- for conciseness

keymap("n", "<leader><leader>", ":nohl<CR>", { desc = "Clear search highlights" })

keymap("i", "<S-Enter>", "<ESC>$o", { desc = "Newline in Insert mode" })

-- Move between windows
keymap("n", "<C-j>", "<C-W>j", { desc = "Move to lower window" })
keymap("n", "<C-k>", "<C-W>k", { desc = "Move to upper window" })
keymap("n", "<C-h>", "<C-W>h", { desc = "Move to the right window" })
keymap("n", "<C-l>", "<C-W>l", { desc = "Move to the left window" })

-- Map search
keymap("n", "<leader><leader>", ":nohl<CR>", { desc = "Clear search highlights" })
