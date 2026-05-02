-- Open/close a tab
vim.keymap.set("n", "<leader>tt", function()
    local bufname = vim.api.nvim_buf_get_name(0)
    local has_file = bufname ~= ""
    if has_file then
        vim.cmd.tabnew("%")
    else
        vim.cmd.tabnew()
    end
end)
vim.keymap.set("n", "<leader>tq", vim.cmd.tabclose)
vim.keymap.set("n", "<leader>tc", vim.cmd.tabclose)

-- Go to the prev/next/last tab
vim.keymap.set("n", "<leader>tp", vim.cmd.tabprev)
vim.keymap.set("n", "<leader>tn", vim.cmd.tabnext)
vim.keymap.set("n", "<M-[>", vim.cmd.tabprev)
vim.keymap.set("n", "<M-]>", vim.cmd.tabnext)
vim.keymap.set("n", "<leader>tl", "g<tab>")

-- Go to tab N
local function gen_tabn(num)
    return function() vim.cmd.tabn(string.format("%d", num)) end
end
vim.keymap.set("n", "<M-1>", gen_tabn(1))
vim.keymap.set("n", "<M-2>", gen_tabn(2))
vim.keymap.set("n", "<M-3>", gen_tabn(3))
vim.keymap.set("n", "<M-4>", gen_tabn(4))
vim.keymap.set("n", "<M-5>", gen_tabn(5))
vim.keymap.set("n", "<M-6>", gen_tabn(6))
vim.keymap.set("n", "<M-7>", gen_tabn(7))
vim.keymap.set("n", "<M-8>", gen_tabn(8))
vim.keymap.set("n", "<M-9>", gen_tabn(9))
