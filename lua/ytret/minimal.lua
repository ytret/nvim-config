-- Minimal, fast-starting config for quick edits/screenshares.
--
-- Loads only the pure-Lua parts of the config (options, keymaps, statusline/
-- tabline) and skips lazy.nvim and every plugin (no LSP, treesitter, fzf,
-- colorscheme plugins, ...). Startup is ~10x faster than the full config.
--
-- Usage:
--     nvim --noplugin -u ~/.config/nvim/lua/ytret/minimal.lua [files...]
--
-- Suggested shell alias (zsh/bash):
--     alias nvq="nvim --noplugin -u ~/.config/nvim/lua/ytret/minimal.lua"

local config_dir = vim.fn.stdpath("config")

-- Resolve shared modules even if the config dir is not on 'runtimepath'.
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

-- Core options and keymaps (pure vim.opt / vim.keymap, no plugin deps).
require("ytret.set")
require("ytret.remap")

-- Custom statusline + tabline (depends only on ytret.tabprompt).
require("ytret.tabs")

-- Restore last cursor position, same as plugin/lastpos.lua.
dofile(config_dir .. "/plugin/lastpos.lua")

-- Colorscheme: the real config uses lazy-installed themes, so fall back to
-- built-in ones here, mirroring the light/dark choice in ~/.config/ytret/theme.txt.
local function pick_colorscheme()
    local theme_file = vim.fn.expand("~/.config/ytret/theme.txt")
    local f = io.open(theme_file, "r")
    local theme = f and f:read("*l") or nil
    if f then
        f:close()
    end

    if theme == "light" then
        vim.o.background = "light"
        pcall(vim.cmd.colorscheme, "retrobox")
    else
        vim.o.background = "dark"
        pcall(vim.cmd.colorscheme, "habamax")
    end
end

pick_colorscheme()
