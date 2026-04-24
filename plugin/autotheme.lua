-- https://github.com/flobilosaurus/theme_reloader.nvim

local theme_file = os.getenv("HOME") .. "/.config/ytret/theme.txt"
local themes = {
    light = "modus_operandi",
    dark = "modus_vivendi",
}

local function read_theme_file()
    local line_reader = io.lines(theme_file)
    return line_reader()
end

local function apply_theme_file()
    local theme = read_theme_file()
    if theme == "light" then
        vim.o.background = "light"
    else
        vim.o.background = "dark"
    end

    local vim_theme = nil
    if themes[theme] == nil then
        error("autotheme: theme '" .. tostring(theme) .. "' not found in 'themes'")
    end
    vim_theme = themes[theme]
    vim.cmd.colorscheme(vim_theme)

    if string.sub(vim_theme, 1, 5) ~= "modus" then
        vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
        vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })

        if vim_theme == "rose-pine" and theme == "dark" then
            vim.cmd.highlight("ColorColumn guibg=#2d2a42")
        elseif vim_theme == "rose-pine" and theme == "light" then
            vim.cmd.highlight("ColorColumn guibg=#d9dce1")
        elseif vim_theme == "tokyonight" then
            vim.cmd.highlight("ColorColumn guibg=#303030")
        elseif vim_theme == "catppuccin-mocha" then
            vim.cmd.highlight("ColorColumn guibg=#262626")
        end
    end
end

local function watch_theme_file()
    local watcher = vim.loop.new_fs_event()

    local on_change

    local function watch_file(path)
        if watcher ~= nil then
            watcher:start(path, {}, vim.schedule_wrap(on_change))
        end
    end

    on_change = function()
        apply_theme_file()

        if watcher ~= nil then
            watcher:stop()
        end

        watch_file(theme_file)
    end

    watch_file(theme_file)
    apply_theme_file()
end

watch_theme_file()
