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
