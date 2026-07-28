-- Neo-tree toggle keymap (replaces nvim-tree's <leader>pv)
vim.keymap.set("n", "<leader>pv", function()
    vim.cmd("Neotree filesystem toggle float")
end, { desc = "Toggle Neo-tree (float)" })