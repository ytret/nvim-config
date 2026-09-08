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
--
-- To upgrade to the full config without restarting, run `:MyFullConfig`
-- (or `<leader>fc`); lazy.nvim + every plugin is loaded on demand.

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

--- Load the full config (lazy.nvim + all plugins) into this session without
--- restarting nvim. Useful when a quick screen-share turns into real work.
local function load_full_config()
    -- Guard via a global so the loaded state is observable from anywhere
    -- (health checks, `:echo g:my_full_config_loaded`, etc.).
    if vim.g.my_full_config_loaded then
        vim.notify("Full config already loaded", vim.log.levels.INFO)
        return
    end
    vim.g.my_full_config_loaded = true

    -- Mirror the parts of lua/ytret/init.lua that minimal.lua skipped. The
    -- set/remap/tabs modules were already required above, so re-requiring them
    -- here would be a cached no-op; only lazy is genuinely new.
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    pcall(require, "ytret.local-pre")

    -- lazy.nvim's setup() bails out when 'loadplugins' is off, which is what
    -- --noplugin set. Re-enable it so lazy actually loads the plugin specs.
    vim.go.loadplugins = true

    -- Bootstrap lazy.nvim and load all plugin specs (the slow part).
    require("ytret.lazy")

    pcall(require, "ytret.local-post")

    -- Source the plugin scripts that --noplugin skipped at startup. Only the
    -- user's own plugin/ and after/plugin/ dirs — not every plugin repo on
    -- 'runtimepath' (those are sourced by lazy.nvim as it loads each plugin).
    local cfg = vim.fn.stdpath("config")
    local files = vim.fn.glob(cfg .. "/plugin/**/*.lua", false, true)
    vim.list_extend(files, vim.fn.glob(cfg .. "/after/plugin/**/*.lua", false, true))
    for _, file in ipairs(files) do
        vim.cmd("source " .. vim.fn.fnameescape(file))
    end

    vim.notify("Full config loaded", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("MyFullConfig", load_full_config, {
    desc = "Load the full config (lazy.nvim + plugins) into this session",
})

vim.keymap.set("n", "<leader>fc", load_full_config, { desc = "Load full config" })
