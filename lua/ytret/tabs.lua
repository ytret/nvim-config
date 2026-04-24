-- Open/close a tab
vim.keymap.set("n", "<leader>tt", ":tabnew<cr>")
vim.keymap.set("n", "<leader>tq", ":tabclose<cr>")

-- Go to the prev/next/last tab
vim.keymap.set("n", "<leader>tp", ":tabprev<cr>")
vim.keymap.set("n", "<leader>tn", ":tabnext<cr>")
vim.keymap.set("n", "<leader>tl", "g<tab>")

-- Go to tab N
vim.keymap.set("n", "<M-1>", ":tabn 1<cr>")
vim.keymap.set("n", "<M-2>", ":tabn 2<cr>")
vim.keymap.set("n", "<M-3>", ":tabn 3<cr>")
vim.keymap.set("n", "<M-4>", ":tabn 4<cr>")
vim.keymap.set("n", "<M-5>", ":tabn 5<cr>")
vim.keymap.set("n", "<M-6>", ":tabn 6<cr>")
vim.keymap.set("n", "<M-7>", ":tabn 7<cr>")
vim.keymap.set("n", "<M-8>", ":tabn 8<cr>")
vim.keymap.set("n", "<M-9>", ":tabn 9<cr>")
