local conform = require("conform")

conform.setup({
    formatters_by_ft = {
        lua = { "stylua" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        python = { "black" },
        fennel = { "fnlfmt" },
        rust = { "rustfmt" },
        nix = { "nixfmt" },
    },
})

conform.formatters.black = {
    prepend_args = { "--line-length", "100" },
}
conform.formatters.stylua = {
    prepend_args = { "--column-width", "100" },
}

vim.keymap.set("", "<leader>f", function() conform.format() end)
