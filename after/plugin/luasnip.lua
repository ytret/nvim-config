local ls = require("luasnip")

vim.keymap.set(
    { "i", "s" },
    "<c-l>",
    function() ls.jump(1) end,
    { silent = true, desc = "Next snippet placeholder" }
)
vim.keymap.set(
    { "i", "s" },
    "<c-j>",
    function() ls.jump(-1) end,
    { silent = true, desc = "Previous snippet placeholder" }
)
vim.keymap.set({ "i", "s" }, "<c-e>", function()
    if ls.choice_active() then
        ls.change_choice(1)
    end
end, { silent = true, desc = "Next snippet choice" })
