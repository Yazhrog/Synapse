return {
    "folke/persistence.nvim",
    event = "BufReadPre", -- Only start session saving when an actual file was opened
    opts = {
        -- You can add any custom Persistence options here
    },
    config = function(_, opts)
        -- Set up persistence with your options
        require("persistence").setup(opts)

        -- Close NvimTree before saving the session to avoid "fake" NvimTree buffers
        vim.api.nvim_create_autocmd("User", {
            pattern = "PersistenceSavePre",
            callback = function()
                local ok, nvim_tree_api = pcall(require, "nvim-tree.api")
                if ok then
                    nvim_tree_api.tree.close()
                end
            end,
        })
    end,
}
