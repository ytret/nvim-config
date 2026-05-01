vim.g.mapleader = " "

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")
vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<leader>bd", ":b# | bd #<cr>")

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
vim.keymap.set("c", "<Esc>f", "<S-Right>")
vim.keymap.set("c", "<Esc>b", "<S-Left>")
