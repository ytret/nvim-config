local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(lazypath)

if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

require("lazy").setup({
    -- Colorschemes
    {
        "rose-pine/neovim",
        name = "rose-pine",
        opts = { styles = { italic = false } },
    },
    {
        "folke/tokyonight.nvim",
        name = "tokyonight",
        opts = {
            styles = {
                comments = { italic = false },
                keywords = { italic = false },
            },
        },
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        opts = { no_italic = true },
    },
    {
        "miikanissi/modus-themes.nvim",
        name = "modus-themes",
        priority = 1000,
        opts = {
            styles = {
                comments = { italic = false },
                keywords = { italic = false },
            },
        },
    },

    -- Must-have
    {
        "nvim-treesitter/nvim-treesitter",
        name = "treesitter",
        branch = "main",
        lazy = false,
        build = ":TSUpdate",
    },
    {
        "nvim-treesitter/nvim-treesitter-context",
        name = "treesitter-context",
        opts = {
            enable = false,
        },
    },

    -- LSP + autocomplete
    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },
    { "neovim/nvim-lspconfig" },
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-nvim-lua" },
    { "L3MON4D3/LuaSnip" },

    -- File tree
    {
        "nvim-tree/nvim-tree.lua",
        name = "nvim-tree",
        version = "*",
        lazy = false,
        config = function() require("nvim-tree").setup({}) end,
    },
    {
        "ibhagwan/fzf-lua",
        dependencies = { "yt-window-picker" },
        opts = function(_, opts) return require("ytret.fzf-setup").setup(opts) end,
    },
    {
        dir = vim.fn.stdpath("config") .. "/plugins/yt-window-picker",
        name = "yt-window-picker",
        lazy = false,
    },
    {
        "kdheepak/lazygit.nvim",
        name = "lazygit",
        cmd = {
            "LazyGit",
            "LazyGitConfig",
            "LazyGitCurrentFile",
            "LazyGitFilter",
            "LazyGitFilterCurrentFile",
        },
        dependencies = {
            "nvim-lua/plenary.nvim", -- optional
        },
    },
    {
        "f-person/git-blame.nvim",
        name = "git-blame",
        event = "VeryLazy",
        opts = {
            enabled = false,
            message_template = " <sha> <date> <author>: <summary>",
            date_format = "%Y-%m-%d",
        },
    },

    -- Code editing
    { "mbbill/undotree" },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        init = function() vim.g.no_plugin_maps = true end,
        config = function() end,
    },
    { "stevearc/conform.nvim", opts = {} },
    {
        "hankertrix/nerd_column.nvim",
        name = "nerd-column.nvim",
        event = { "BufEnter" },
        opts = {
            always_show = true,
            custom_colour_column = function(_, _, ft)
                if ft == "python" or ft == "lua" or ft == "rust" or ft == "asciidoc" then
                    return 100
                else
                    return 80
                end
            end,
        },
    },
    {
        "ytret/flash.nvim",
        event = "VeryLazy",
        opts = {
            modes = {
                char = { keys = {} },
            },
            label = { rainbow = { enabled = true, shade = 4 } },
        },
        keys = {
            { "<c-s>", mode = { "n", "x", "o" }, function() require("flash").jump() end },
            { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end },
            { "r", mode = "o", function() require("flash").remote() end },
            { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end },
        },
    },

    -- nvim config
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {},
        },
    },

    -- Other
    { "HiPhish/info.vim" },
})
