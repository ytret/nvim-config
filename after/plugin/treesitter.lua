require("nvim-treesitter").setup({
    ensure_installed = {
        "bash",
        "c",
        "cpp",
        "go",
        "lua",
        "python",
        "rust",
    },
    auto_install = true,
    highlight = {
        enable = true,
    },
})

vim.api.nvim_create_autocmd("FileType", {
    callback = function(args) pcall(vim.treesitter.start, args.buf) end,
})
vim.api.nvim_create_autocmd("FileType", {
    pattern = {
        "c",
        "lua",
    },
    callback = function(_)
        -- vim.wo[0][0] ???
        vim.opt.foldmethod = "expr"
        vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.opt.foldlevel = 99
        vim.opt.foldlevelstart = 99
    end,
})
