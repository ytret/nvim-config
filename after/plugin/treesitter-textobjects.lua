local to_move = require("nvim-treesitter-textobjects.move")
local to_sel = require("nvim-treesitter-textobjects.select")

local function gen_call(func, arg)
    return function() func(arg, "textobjects") end
end

-- Arguments
vim.keymap.set(
    { "n", "x", "o" },
    "]a",
    gen_call(to_move.goto_next_start, "@parameter.inner"),
    { desc = "Next argument" }
)
vim.keymap.set(
    { "n", "x", "o" },
    "[a",
    gen_call(to_move.goto_previous_start, "@parameter.inner"),
    { desc = "Previous argument" }
)
vim.keymap.set(
    { "x", "o" },
    "aa",
    gen_call(to_sel.select_textobject, "@parameter.outer"),
    { desc = "Around argument" }
)
vim.keymap.set(
    { "x", "o" },
    "ia",
    gen_call(to_sel.select_textobject, "@parameter.inner"),
    { desc = "Inside argument" }
)

-- Statements
vim.keymap.set(
    { "n", "x", "o" },
    "]s",
    gen_call(to_move.goto_next_start, "@statement.outer"),
    { desc = "Next statement" }
)
vim.keymap.set(
    { "n", "x", "o" },
    "[s",
    gen_call(to_move.goto_previous_start, "@statement.outer"),
    { desc = "Previous statement" }
)
vim.keymap.set(
    { "x", "o" },
    "as",
    gen_call(to_sel.select_textobject, "@statement.outer"),
    { desc = "Around statement" }
)

-- Blocks
vim.keymap.set(
    { "n", "x", "o" },
    "]b",
    gen_call(to_move.goto_next_start, "@block.outer"),
    { desc = "Next block" }
)
vim.keymap.set(
    { "n", "x", "o" },
    "[b",
    gen_call(to_move.goto_previous_start, "@block.outer"),
    { desc = "Previous block" }
)
vim.keymap.set(
    { "x", "o" },
    "ab",
    gen_call(to_sel.select_textobject, "@block.outer"),
    { desc = "Around block" }
)

-- Functions
vim.keymap.set(
    { "n", "x", "o" },
    "]m",
    gen_call(to_move.goto_next_start, "@function.outer"),
    { desc = "Next function" }
)
vim.keymap.set(
    { "n", "x", "o" },
    "[m",
    gen_call(to_move.goto_previous_start, "@function.outer"),
    { desc = "Previous function" }
)
vim.keymap.set(
    { "x", "o" },
    "am",
    gen_call(to_sel.select_textobject, "@function.outer"),
    { desc = "Around function" }
)
vim.keymap.set(
    { "x", "o" },
    "im",
    gen_call(to_sel.select_textobject, "@function.inner"),
    { desc = "Inside function" }
)
