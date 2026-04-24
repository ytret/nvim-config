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

local init_width, init_height, init_col, init_row = calc_size_pos()

require("nvim-tree").setup({
    sort = {
        sorter = "case_sensitive",
    },
    view = {
        float = {
            enable = true,
            open_win_config = {
                relative = "editor",
                border = "rounded",
                width = init_width,
                height = init_height,
                col = init_col,
                row = init_row,
            },
        },
    },
    renderer = {
        group_empty = true,
    },
    filters = {
        dotfiles = false,
    },
})

vim.keymap.set("n", "<leader>pv", vim.cmd.NvimTreeFindFileToggle)

vim.api.nvim_create_autocmd({ "VimResized" }, {
    desc = "Resize nvim-tree if nvim window got resized",

    group = vim.api.nvim_create_augroup("NvimTreeResize", { clear = true }),
    callback = function()
        local nvim_tree = require("nvim-tree")
        local width, height, col, row = calc_size_pos()
        local config = nvim_tree.config.view.float.open_win_config
        config.width = width
        config.height = height
        config.col = col
        config.row = row
    end,
})
