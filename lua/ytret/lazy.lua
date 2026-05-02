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
    -- Темы
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

    -- База
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
    {
        "ibhagwan/fzf-lua",
        dependencies = { "fzf-window-picker" },
        opts = function(_, opts)
            local fzf_actions = require("fzf-lua.actions")
            local fzf_path = require("fzf-lua.path")
            local fzf_utils = require("fzf-lua.utils")
            local window_picker = require("fzf-window-picker")
            local uv = vim.uv or vim.loop

            local function has_real_target(selected, action_opts)
                if not selected or not selected[1] or selected[1] == "" then
                    return false
                end

                local ok, entry =
                    pcall(fzf_path.entry_to_file, selected[1], action_opts, action_opts._uri)
                if not ok or not entry then
                    return false
                end

                if entry.uri then
                    return true
                end

                if entry.bufnr and vim.api.nvim_buf_is_valid(entry.bufnr) then
                    return true
                end

                local fullpath = entry.bufname or entry.path
                if not fullpath or fullpath == "" then
                    return false
                end

                if not fzf_path.is_absolute(fullpath) then
                    fullpath = fzf_path.join({
                        action_opts.cwd or action_opts._cwd or fzf_utils.cwd(),
                        fullpath,
                    })
                end

                return uv.fs_stat(fullpath) ~= nil
            end

            local function with_picked_window(open_action)
                return function(selected, action_opts)
                    if not has_real_target(selected, action_opts) then
                        return
                    end

                    local target = window_picker.pick_window()
                    if not target then
                        return
                    end

                    vim.api.nvim_set_current_win(target)
                    open_action(selected, action_opts)
                end
            end

            opts = opts or {}
            opts.fzf_colors = true
            opts.files = vim.tbl_deep_extend("force", opts.files or {}, {
                fzf_opts = {
                    ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-files-history",
                },
                actions = {
                    ["default"] = with_picked_window(fzf_actions.file_edit),
                },
            })
            opts.buffers = vim.tbl_deep_extend("force", opts.buffers or {}, {
                actions = {
                    ["default"] = with_picked_window(fzf_actions.buf_edit),
                },
            })
            opts.grep = vim.tbl_deep_extend("force", opts.grep or {}, {
                fzf_opts = {
                    ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-grep-history",
                },
                actions = {
                    ["default"] = with_picked_window(fzf_actions.file_edit),
                },
            })

            return opts
        end,
    },
    {
        dir = vim.fn.stdpath("config") .. "/plugins/fzf-window-picker",
        name = "fzf-window-picker",
        lazy = false,
    },
    { "HiPhish/info.vim" },

    -- LSP + autocomplete
    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },
    { "neovim/nvim-lspconfig" },
    { "hrsh7th/nvim-cmp" },
    { "hrsh7th/cmp-nvim-lsp" },
    { "hrsh7th/cmp-nvim-lua" },
    { "L3MON4D3/LuaSnip" },

    -- Проекты
    {
        "nvim-tree/nvim-tree.lua",
        name = "nvim-tree",
        version = "*",
        lazy = false,
        config = function() require("nvim-tree").setup({}) end,
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

    -- Редактирование
    { "theprimeagen/harpoon" },
    { "mbbill/undotree" },
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
})
