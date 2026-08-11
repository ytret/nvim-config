-- This file is inactive while neo-tree is configured in lazy.lua.
-- To switch back to nvim-tree: replace neo-tree with nvim-tree in lazy.lua.
if not pcall(require, "nvim-tree") then
    return
end

local DirectoryNode = require("nvim-tree.node.directory")
local tabs = require("ytret.tabs")

local function open_in_picked_tab(node)
    local dir = node:as(DirectoryNode)
    if dir then
        dir:expand_or_collapse()
        return
    end

    local path = node.absolute_path
    if not path then
        return
    end

    tabs.open_in_picked_tab(function() vim.cmd.edit(vim.fn.fnameescape(path)) end)
end

local function calc_size_pos()
    local gwidth = vim.api.nvim_list_uis()[1].width
    local gheight = vim.api.nvim_list_uis()[1].height

    local max_width = gwidth
    local max_height = gheight - 3

    local width = math.min(80, max_width)
    local height = math.min(30, max_height)

    local col = width == max_width and 1 or (gwidth - width) * 0.5
    local row = height == max_height and 1 or (gheight - height) * 0.4

    return width, height, col, row
end

require("nvim-tree").setup({
    sort = {
        sorter = "case_sensitive",
    },
    view = {
        float = {
            enable = true,
            open_win_config = function()
                local width, height, col, row = calc_size_pos()
                return {
                    relative = "editor",
                    border = "rounded",
                    width = width,
                    height = height,
                    col = col,
                    row = row,
                }
            end,
        },
    },
    renderer = {
        group_empty = true,
    },
    filters = {
        dotfiles = false,
    },
    on_attach = function(bufnr)
        local api = require("nvim-tree.api")
        api.map.on_attach.default(bufnr)

        local function opts(desc)
            return {
                buffer = bufnr,
                noremap = true,
                silent = true,
                nowait = true,
                desc = "nvim-tree: " .. desc,
            }
        end

        vim.keymap.set("n", "<C-t>", function()
            local node = api.tree.get_node_under_cursor()
            if node then
                open_in_picked_tab(node)
            end
        end, opts("Open file in picked tab"))

        vim.keymap.set("n", "<BS>", api.tree.focus_source_win, opts("Focus Source Window"))

        vim.keymap.set(
            "n",
            "tG",
            function() api.tree.change_root(vim.fn.getcwd(-1, -1)) end,
            opts("Root at global working dir")
        )

        vim.keymap.set(
            "n",
            "tl",
            function() api.tree.change_root(vim.fn.getcwd(-1, 0)) end,
            opts("Root at tab-local working dir")
        )

        local cwd_group_symbols = {
            { key = "A", greek = "α" },
            { key = "B", greek = "β" },
            { key = "G", greek = "γ" },
            { key = "D", greek = "δ" },
            { key = "E", greek = "ε" },
            { key = "Z", greek = "ζ" },
            { key = "H", greek = "η" },
            { key = "T", greek = "θ" },
            { key = "I", greek = "ι" },
            { key = "K", greek = "κ" },
        }

        for _, group in ipairs(cwd_group_symbols) do
            local lhs = "t" .. group.key:lower()
            vim.keymap.set("n", lhs, function()
                local cwd = tabs.cwd_for_group_key(group.key)
                if cwd then
                    api.tree.change_root(cwd)
                else
                    vim.notify("Tab cwd group " .. group.greek .. " does not exist", vim.log.levels.INFO)
                end
            end, opts("Root at tab cwd group " .. group.greek))
        end
    end,
})

vim.keymap.set("n", "<leader>pv", vim.cmd.NvimTreeFindFileToggle)

vim.api.nvim_create_autocmd("VimResized", {
    desc = "Resize nvim-tree when Neovim window is resized",
    group = vim.api.nvim_create_augroup("NvimTreeResize", { clear = true }),

    callback = function()
        local width, height, col, row = calc_size_pos()

        if require("nvim-tree.api").tree.is_visible() then
            local winid = require("nvim-tree.api").tree.winid()
            if winid and vim.api.nvim_win_is_valid(winid) then
                vim.api.nvim_win_set_config(winid, {
                    relative = "editor",
                    width = width,
                    height = height,
                    col = col,
                    row = row,
                })
            end
        end

        vim.cmd("redraw")
    end,
})
