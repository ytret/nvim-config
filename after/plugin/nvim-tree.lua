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
