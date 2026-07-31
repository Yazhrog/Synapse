return {
    "neovim/nvim-lspconfig",

    dependencies = {
        "mason-org/mason.nvim",
        "mason-org/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
    },

    config = function()
        local mason_servers = {
            "bashls",
            "clangd",
            "cssls",
            "html",
            "intelephense",
            "jsonls",
            "lua_ls",
            "tailwindcss",
            "ts_ls",
        }

        local mason_tools = {
            "clang-format",
            "eslint_d",
            "prettierd",
            "ruff",
            "shellcheck",
            "shfmt",
            "stylua",
        }

        local servers = {
            lua_ls = {
                settings = {
                    Lua = {
                        completion = { callSnippet = "Replace" },
                        diagnostics = {
                            globals = { "vim" },
                            disable = { "missing-fields" },
                        },
                        runtime = { version = "LuaJIT" },
                        workspace = {
                            checkThirdParty = false,
                            library = {
                                vim.env.VIMRUNTIME,
                                "${3rd}/busted/library",
                                "${3rd}/love2d/library",
                                "${3rd}/luv/library",
                            },
                        },
                    },
                },
            },

            cssls = {
                settings = { css = { validate = false } },
            },
        }

        require("mason").setup({
            ui = {
                width = 0.8,
                height = 0.8,
                icons = {
                    package_installed = "",
                    package_pending = "",
                    package_uninstalled = "",
                },
            },
        })

        require("mason-lspconfig").setup({ ensure_installed = mason_servers })
        require("mason-tool-installer").setup({ ensure_installed = mason_tools })

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = vim.tbl_deep_extend("force", capabilities, require("blink.cmp").get_lsp_capabilities({}, false))

        -- 0.11 fix
        for server, config in pairs(servers) do
            config.capabilities = vim.tbl_deep_extend("force", {}, capabilities, config.capabilities or {})
            vim.lsp.config(server, config)
        end

        vim.diagnostic.config({
            signs = {
                numhl = {
                    [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
                    [vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
                    [vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
                    [vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
                },
                text = {
                    [vim.diagnostic.severity.ERROR] = "X",
                    [vim.diagnostic.severity.HINT] = "?",
                    [vim.diagnostic.severity.INFO] = "I",
                    [vim.diagnostic.severity.WARN] = "!",
                },
            },
            update_in_insert = true,
            virtual_text = false,
            virtual_lines = { current_line = true },
        })

        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("UserLspConfig", {}),
            callback = function(ev)
                local bufopts = { buffer = ev.buf, silent = true }
                local maps = {
                    { "gR", "<cmd>Telescope lsp_references<CR>", "Show LSP references" },
                    { "gD", vim.lsp.buf.declaration, "Go to declaration" },
                    { "gd", "<cmd>Telescope lsp_definitions<CR>", "Show LSP definitions" },
                    { "gi", "<cmd>Telescope lsp_implementations<CR>", "Show LSP implementations" },
                    { "gt", "<cmd>Telescope lsp_type_definitions<CR>", "Show LSP type definitions" },
                    { "<leader>ca", vim.lsp.buf.code_action, "See available code actions" },
                    { "<leader>rn", vim.lsp.buf.rename, "Smart rename" },
                    { "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", "Show buffer diagnostics" },
                    { "K", vim.lsp.buf.hover, "Show documentation under cursor" },
                    { "<leader>rs", ":LspRestart<CR>", "Restart LSP" },
                }
                for _, m in ipairs(maps) do
                    bufopts.desc = m[3]
                    vim.keymap.set("n", m[1], m[2], bufopts)
                end

                local client = vim.lsp.get_client_by_id(ev.data.client_id)
                -- first ensure the method exists as a field, then call it via ':'
                local has_highlight = client
                    and client.supports_method
                    and client:supports_method("textDocument/documentHighlight", ev.buf)

                if has_highlight then
                    local hl_grp = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
                    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                        buffer = ev.buf,
                        group = hl_grp,
                        callback = vim.lsp.buf.document_highlight,
                    })
                    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                        buffer = ev.buf,
                        group = hl_grp,
                        callback = vim.lsp.buf.clear_references,
                    })
                    vim.api.nvim_create_autocmd("LspDetach", {
                        group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
                        callback = function(event2)
                            vim.lsp.buf.clear_references()
                            vim.api.nvim_clear_autocmds({ group = "lsp-highlight", buffer = event2.buf })
                        end,
                    })
                end
            end,
        })
    end,
}
