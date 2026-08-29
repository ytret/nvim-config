vim.g.mapleader = " "

vim.keymap.set("n", "<Space>", "<Nop>", { silent = true })

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<leader>bd", ":b# | bd #<cr>")

vim.keymap.set("n", "<leader>wq", vim.cmd.quit)
vim.keymap.set("n", "<leader>wv", vim.cmd.vsplit)
vim.keymap.set("n", "<leader>wn", vim.cmd.vsplit)
vim.keymap.set("n", "<leader>ws", vim.cmd.split)
vim.keymap.set("n", "<leader>wo", vim.cmd.only)
vim.keymap.set("n", "<leader>wh", ":vert help ")

vim.keymap.set("", "<leader>y", '"+y')
vim.keymap.set("", "<leader>Y", '"+Y')
vim.keymap.set("", "<leader>qy", '"+y')
vim.keymap.set("", "<leader>qY", '"+Y')
vim.keymap.set("", "<leader>qd", '"+d')
vim.keymap.set("", "<leader>qD", '"+D')
vim.keymap.set("", "<leader>qp", '"+p')
vim.keymap.set("", "<leader>qP", '"+P')

vim.keymap.set("c", "<C-A>", "<Home>")
vim.keymap.set("c", "<C-F>", "<Right>")
vim.keymap.set("c", "<C-B>", "<Left>")
vim.keymap.set("c", "<C-D>", "<Delete>")
vim.keymap.set("c", "<Esc>f", "<S-Right>")
vim.keymap.set("c", "<Esc>b", "<S-Left>")

-- Delete a single char, not a whole indent level. By default <BS> eats a full
-- 'softtabstop'/'shiftwidth' worth of indentation (see 'smarttab' + 'softtabstop').
local function delete_char_before_cursor()
    local row, byte_col = unpack(vim.api.nvim_win_get_cursor(0))
    if byte_col > 0 then
        local line = vim.api.nvim_get_current_line()
        local prefix = line:sub(1, byte_col)
        local nchar = vim.str_utfindex(prefix)
        local start = vim.str_byteindex(prefix, nchar - 1)
        vim.api.nvim_set_current_line(line:sub(1, start) .. line:sub(byte_col + 1))
        vim.api.nvim_win_set_cursor(0, { row, start })
    elseif row > 1 then
        -- At the start of a line: join with the previous line, like <BS> with 'eol'.
        local prev = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
        local cur = vim.api.nvim_get_current_line()
        vim.api.nvim_buf_set_lines(0, row - 2, row, false, { prev .. cur })
        vim.api.nvim_win_set_cursor(0, { row - 1, #prev })
    end
end
vim.keymap.set("i", "<BS>", delete_char_before_cursor)
vim.keymap.set("i", "<C-h>", delete_char_before_cursor)

-- Remove whitespace (preserves cursor position, no jumplist/mark pollution)
vim.keymap.set("n", "<leader>rw", function()
    local save = vim.fn.winsaveview()
    local s = vim.fn.getreg("/")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setreg("/", s)
    vim.fn.winrestview(save)
end, { desc = "Remove trailing whitespace" })

vim.keymap.set(
    "n",
    "<leader>hl",
    function() vim.o.hlsearch = not vim.o.hlsearch end,
    { desc = "Toggle hlsearch" }
)
