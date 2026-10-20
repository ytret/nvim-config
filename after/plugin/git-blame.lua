vim.keymap.set("n", "<leader>gbb", vim.cmd.GitBlameToggle, { desc = "Toggle Git blame" })
vim.keymap.set("n", "<leader>gby", vim.cmd.GitBlameCopySHA, { desc = "Copy Git blame commit SHA" })
