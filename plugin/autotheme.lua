-- https://github.com/flobilosaurus/theme_reloader.nvim

local theme_file = os.getenv("HOME") .. "/.config/ytret/theme.txt"
local themes = {
    light = "modus_operandi",
    dark = "modus_vivendi",
}

local function read_theme_file()
    local file, err = io.open(theme_file, "r")
    if not file then
        return nil, err
    end
    local theme, read_err = file:read("*l")
    file:close()
    if theme == nil or theme == "" then
        return nil, read_err or "theme file is empty"
    end
    if themes[theme] == nil then
        return nil, "invalid theme " .. string.format("%q", theme), true
    end
    return theme
end

local function apply_theme(theme)
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
        vim.api.nvim_set_hl(0, "TabLine", { bg = "#2e2e2e", fg = "#888888" })
        vim.api.nvim_set_hl(0, "TabLineSel", { bg = "#505050", fg = "#ffffff" })
        vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#1a1a1a", fg = "#444444" })
    else
        vim.api.nvim_set_hl(0, "TabLine", { bg = "#d0d0d0", fg = "#555555" })
        vim.api.nvim_set_hl(0, "TabLineSel", { bg = "#ffffff", fg = "#111111" })
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
        local function apply_trailing_whitespace_match()
            if vim.bo.buftype ~= "terminal" then
                vim.cmd([[ match MyTrailingWhitespace /\s\+$/ ]])
            else
                -- Clear match in terminal buffers (e.g. lazygit)
                vim.cmd([[ match none ]])
            end
        end
        apply_trailing_whitespace_match()
        vim.api.nvim_create_augroup("YtretTrailingWhitespace", { clear = true })
        vim.api.nvim_create_autocmd({ "WinNew", "BufWinEnter" }, {
            group = "YtretTrailingWhitespace",
            callback = apply_trailing_whitespace_match,
        })
        -- TermOpen fires after buftype is set to "terminal", so it reliably
        -- clears the match that BufWinEnter may have applied too early.
        vim.api.nvim_create_autocmd("TermOpen", {
            group = "YtretTrailingWhitespace",
            callback = function() vim.cmd([[ match none ]]) end,
        })
    end
end

-- Sourcing this plugin again must not leave duplicate watchers or pending reads.
if _G.ytret_autotheme_stop then
    _G.ytret_autotheme_stop()
end

local uv = vim.uv or vim.loop
local watcher = uv.new_fs_event()
local timer = assert(uv.new_timer())
local group = vim.api.nvim_create_augroup("YtretAutoTheme", { clear = true })
local stopped = false
local generation = 0
local retries = 0
local last_theme
local last_warning

local function warn_once(message)
    if message ~= last_warning then
        last_warning = message
        vim.notify("autotheme: " .. message, vim.log.levels.WARN)
    end
end

local read_and_apply
local function schedule_read(delay)
    generation = generation + 1
    local current = generation
    timer:start(
        delay,
        0,
        vim.schedule_wrap(function()
            -- A timer callback may already be scheduled when another event resets it.
            if not stopped and current == generation then
                read_and_apply()
            end
        end)
    )
end

read_and_apply = function()
    local theme, err, invalid = read_theme_file()
    if theme then
        last_warning = nil
        if theme ~= last_theme then
            local ok, apply_err = pcall(apply_theme, theme)
            if ok then
                last_theme = theme
            else
                warn_once("could not apply theme: " .. tostring(apply_err))
            end
        end
    elseif invalid then
        -- A typo is not a transient write failure: wait for another file event.
        warn_once(err)
    elseif retries < 5 then
        retries = retries + 1
        schedule_read(200)
    else
        warn_once("could not read " .. theme_file .. ": " .. tostring(err))
    end
end

local function stop()
    if stopped then
        return
    end
    stopped = true
    generation = generation + 1
    timer:stop()
    timer:close()
    if watcher then
        watcher:stop()
        watcher:close()
    end
    vim.api.nvim_del_augroup_by_id(group)
    if _G.ytret_autotheme_stop == stop then
        _G.ytret_autotheme_stop = nil
    end
end

_G.ytret_autotheme_stop = stop
vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = stop })

if watcher then
    -- Watching the directory survives atomic replacement of theme.txt. Keep the
    -- watch running: restarting it can discard a write queued during a read.
    local ok, err = watcher:start(
        vim.fn.fnamemodify(theme_file, ":h"),
        {},
        vim.schedule_wrap(function(watch_err, filename)
            if stopped then
                return
            end
            if watch_err then
                warn_once("watch failed: " .. tostring(watch_err))
            elseif filename == nil or filename == "theme.txt" then
                retries = 0
                schedule_read(50)
            end
        end)
    )
    if not ok then
        warn_once("could not watch theme directory: " .. tostring(err))
    end
else
    warn_once("could not create theme directory watcher")
end

read_and_apply()
