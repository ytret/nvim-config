local to_move = require("nvim-treesitter-textobjects.move")
local to_sel = require("nvim-treesitter-textobjects.select")

local function gen_call(func, arg)
    return function() func(arg, "textobjects") end
end

-- Arguments
vim.keymap.set({ "n", "x", "o" }, "]a", gen_call(to_move.goto_next_start, "@parameter.inner"))
vim.keymap.set({ "n", "x", "o" }, "[a", gen_call(to_move.goto_previous_start, "@parameter.inner"))
vim.keymap.set({ "x", "o" }, "aa", gen_call(to_sel.select_textobject, "@parameter.outer"))
vim.keymap.set({ "x", "o" }, "ia", gen_call(to_sel.select_textobject, "@parameter.inner"))

-- Statements
vim.keymap.set({ "n", "x", "o" }, "]s", gen_call(to_move.goto_next_start, "@statement.outer"))
vim.keymap.set({ "n", "x", "o" }, "[s", gen_call(to_move.goto_previous_start, "@statement.outer"))
vim.keymap.set({ "x", "o" }, "as", gen_call(to_sel.select_textobject, "@statement.outer"))

-- Blocks
vim.keymap.set({ "n", "x", "o" }, "]b", gen_call(to_move.goto_next_start, "@block.outer"))
vim.keymap.set({ "n", "x", "o" }, "[b", gen_call(to_move.goto_previous_start, "@block.outer"))
vim.keymap.set({ "x", "o" }, "ab", gen_call(to_sel.select_textobject, "@block.outer"))

-- Functions
vim.keymap.set({ "n", "x", "o" }, "]m", gen_call(to_move.goto_next_start, "@function.outer"))
vim.keymap.set({ "n", "x", "o" }, "[m", gen_call(to_move.goto_previous_start, "@function.outer"))
vim.keymap.set({ "x", "o" }, "am", gen_call(to_sel.select_textobject, "@function.outer"))
vim.keymap.set({ "x", "o" }, "im", gen_call(to_sel.select_textobject, "@function.inner"))
