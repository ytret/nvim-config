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
    local space_hl_ctermbg
    local space_hl_guibg
    if theme == "light" then
        vim.o.background = "light"

        space_hl_ctermbg = "red"
        space_hl_guibg = "lightred"
    else
        vim.o.background = "dark"
        theme = "dark"

        space_hl_ctermbg = "red"
        space_hl_guibg = "darkred"
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

    -- Tabline colors: inactive tabs get uniform bg, active tab is brighter
    if vim.o.background == "dark" then
        vim.api.nvim_set_hl(0, "TabLine",     { bg = "#2e2e2e", fg = "#888888" })
        vim.api.nvim_set_hl(0, "TabLineSel",  { bg = "#505050", fg = "#ffffff" })
        vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#1a1a1a", fg = "#444444" })
    else
        vim.api.nvim_set_hl(0, "TabLine",     { bg = "#d0d0d0", fg = "#555555" })
        vim.api.nvim_set_hl(0, "TabLineSel",  { bg = "#ffffff", fg = "#111111" })
        vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#e8e8e8", fg = "#b0b0b0" })
    end

    ---@diagnostic disable-next-line: undefined-global
    if YTRET_HIGHLIGHT == true then
        vim.cmd.highlight(
            string.format(
                "MyTrailingWhitespace ctermbg=%s guibg=%s",
                space_hl_ctermbg,
                space_hl_guibg
            )
        )
        vim.cmd([[ match MyTrailingWhitespace /\s\+$/ ]])
        vim.api.nvim_create_augroup("YtretTrailingWhitespace", { clear = true })
        vim.api.nvim_create_autocmd({ "WinNew", "BufWinEnter" }, {
            group = "YtretTrailingWhitespace",
            callback = function()
                vim.cmd([[ match MyTrailingWhitespace /\s\+$/ ]])
            end,
        })
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
