local function gen_motion(arg)
    return function() vim.cmd.Treewalker(arg) end
end

vim.keymap.set({ "n", "v" }, "<C-k>", gen_motion("Up"))
vim.keymap.set({ "n", "v" }, "<C-j>", gen_motion("Down"))
vim.keymap.set({ "n", "v" }, "<C-h>", gen_motion("Left"))
vim.keymap.set({ "n", "v" }, "<C-l>", gen_motion("Right"))

vim.keymap.set("n", "<C-M-k>", gen_motion("SwapUp"))
vim.keymap.set("n", "<C-M-j>", gen_motion("SwapDown"))
vim.keymap.set("n", "<C-M-h>", gen_motion("SwapLeft"))
vim.keymap.set("n", "<C-M-l>", gen_motion("SwapRight"))
