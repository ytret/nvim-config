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

        vim.keymap.set("n", "<C-t>", function()
            local node = api.tree.get_node_under_cursor()
            if node then
                open_in_picked_tab(node)
            end
        end, { buffer = bufnr, desc = "Open file in picked tab" })
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
