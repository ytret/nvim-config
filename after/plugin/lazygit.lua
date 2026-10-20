vim.keymap.set("n", "<leader>gg", vim.cmd.LazyGit, { desc = "Open LazyGit" })
vim.keymap.set("n", "<leader>gc", vim.cmd.LazyGitConfig, { desc = "Open LazyGit config" })

vim.g.lazygit_floating_window_scaling_factor = 1
