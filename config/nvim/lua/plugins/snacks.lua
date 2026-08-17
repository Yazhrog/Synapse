return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        bigfile = { enabled = true },
        indent = { enabled = true },
        quickfile = { enabled = true },
        scope = { enabled = true },
        -- scroll = { enabled = true },
        statuscolumn = { enabled = true },
        picker = {
            ui_select = false,
            layout = { preset = "ivy" },
            sources = {
                explorer = {
                    actions = {
                        recursive_toggle = function(picker, item)
                            local Actions = require("snacks.explorer.actions")
                            local Tree = require("snacks.explorer.tree")

                            local get_children = function(node)
                                local children = {}
                                for _, child in pairs(node.children) do
                                    table.insert(children, child)
                                end
                                return children
                            end

                            local refresh = function()
                                Actions.update(picker, { refresh = true })
                            end

                            ---@param node snacks.picker.explorer.Node
                            local function toggle_recursive(node)
                                Tree:toggle(node.path)
                                refresh()
                                vim.schedule(function()
                                    local children = get_children(node)
                                    if #children ~= 1 then
                                        return
                                    end
                                    local child = children[1]
                                    if not child.dir then
                                        return
                                    end
                                    toggle_recursive(child)
                                end)
                            end

                            --

                            local node = Tree:node(item.file)
                            if not node then
                                return
                            end

                            if node.dir then
                                toggle_recursive(node)
                            else
                                picker:action("confirm")
                            end
                        end,
                    },
                    cycle = true,
                    auto_close = true, -- helps floating explorer behave nicely
                    win = {
                        list = {
                            keys = {
                                ["<CR>"] = "recursive_toggle",
                            },
                        },
                    },
                },
            },
        },
        explorer = { enabled = true },
    },
    keys = {
        {
            "<leader>e",
            function()
                Snacks.explorer.open()
            end,
            desc = "Toggle File Explorer",
        },
        {
            "<leader>w",
            function()
                Snacks.explorer.reveal()
            end,
            desc = "Find buffer in File Explorer",
        },
    },
}
